import Foundation
import SwiftUI // For Color, UIImage (though UIImage is UIKit)
import UIKit // For UIImage

// Assume TASK_IMAGE_CLASSIFICATION is defined in Task.swift
// Assume Model, ChatMessage types, etc., are available.

class ImageClassificationViewModel: ChatViewModelBase {

    private var modelHelper = ImageClassificationModelHelper()
    private let inferenceActor = InferenceActor() // Actor to ensure serial execution of inference

    // Initializer
    init() {
        // Ensure TASK_IMAGE_CLASSIFICATION is defined and available
        // If it's not, this will cause a crash.
        // It should have been added in a previous step.
        super.init(task: TASK_IMAGE_CLASSIFICATION)
    }

    // Actor to serialize inference requests
    private actor InferenceActor {
        var isInferring: Bool = false

        func run<T>(_ operation: @escaping () async throws -> T) async throws -> T {
            guard !isInferring else {
                throw NSError(domain: "InferenceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Inference already in progress."])
            }
            isInferring = true
            defer { isInferring = false }
            return try await operation()
        }
    }

    // Model Initialization State: Can be checked via model.instance != nil

    func initializeModelIfNeeded(model: inout Model) async throws {
        if model.instance == nil {
            print("Initializing model: \(model.name)")
            try await modelHelper.initialize(model: &model)
            // Update the model in the task's models array as well, since it's a struct
            if let taskModelIndex = self.task.models.firstIndex(where: { $0.id == model.id }) {
                var updatedTask = self.task
                updatedTask.models[taskModelIndex].instance = model.instance
                // Note: self.task is a 'let', so we can't directly mutate it here.
                // This highlights a potential issue with struct-based Models array in Task
                // if instances need to be updated globally.
                // For now, the 'model' parameter passed in will be updated.
                // Consider making Task.models modifiable or using a class for Model if global instance state is critical.
            }
        }
    }

    func generateResponse(model: Model, inputImage: UIImage, primaryColor: Color) async {
        var mutableModel = model // Make a mutable copy to update instance
        do {
            try await initializeModelIfNeeded(model: &mutableModel)

            setPreparing(true)
            defer { setPreparing(false) }

            let result = try await modelHelper.runInference(model: mutableModel, inputImage: inputImage, primaryColor: primaryColor)
            let chatMessage = generateClassificationMessage(result: result, model: mutableModel)

            await MainActor.run { // Ensure UI updates are on main thread
                super.addMessage(model: mutableModel, message: chatMessage)
            }
        } catch {
            await MainActor.run {
                let errorMessage = ChatMessageWarning(side: .SYSTEM, content: "Error during image classification: \(error.localizedDescription)")
                super.addMessage(model: mutableModel, message: errorMessage)
                setPreparing(false) // Ensure this is reset on error
            }
        }
    }

    // generateStreamingResponse is not typical for single-shot image classification.
    // It's more for LLMs. Here, it will behave like generateResponse but update the streaming slot.
    func generateStreamingResponse(model: Model, inputImage: UIImage, primaryColor: Color) async {
         var mutableModel = model
         do {
            try await inferenceActor.run { // Ensure serial execution
                try await initializeModelIfNeeded(model: &mutableModel)

                await MainActor.run { setPreparing(true) }
                defer { await MainActor.run { setPreparing(false) } }

                let result = try await modelHelper.runInference(model: mutableModel, inputImage: inputImage, primaryColor: primaryColor)
                let chatMessage = generateClassificationMessage(result: result, model: mutableModel)

                await MainActor.run {
                    super.updateStreamingMessage(model: mutableModel, message: chatMessage)
                }
            }
        } catch {
            await MainActor.run {
                let errorMessage = ChatMessageWarning(side: .SYSTEM, content: "Error: \(error.localizedDescription)")
                super.updateStreamingMessage(model: mutableModel, message: errorMessage)
                setPreparing(false)
            }
        }
    }

    func benchmark(model: Model, message: ChatMessageImage, warmupCount: Int, iterations: Int, primaryColor: Color) async {
        var mutableModel = model
        var benchmarkMessageId: UUID? = nil

        await MainActor.run {
            setInProgress(true)
            // Initial benchmark message
            let initialBenchMsg = ChatMessageBenchmarkResult(
                side: .SYSTEM, latencyMs: 0, accelerator: mutableModel.defaultAccelerator.rawValue,
                orderedStats: [], statValues: [:], values: [], histogram: Histogram(buckets: [], maxCount: 0, highlightBucketIndex: -1),
                warmupCurrent: 0, warmupTotal: warmupCount, iterationCurrent: 0, iterationTotal: iterations, highlightStat: ""
            )
            benchmarkMessageId = initialBenchMsg.id
            super.addMessage(model: mutableModel, message: initialBenchMsg)
        }

        guard let currentBenchmarkMessageId = benchmarkMessageId else {
            await MainActor.run { setInProgress(false) }
            return
        }

        do {
            try await initializeModelIfNeeded(model: &mutableModel)
            var latencies: [Float] = []

            // Warm-up loop
            for i in 0..<warmupCount {
                _ = try await modelHelper.runInference(model: mutableModel, inputImage: message.uiImage ?? UIImage(), primaryColor: primaryColor)
                let progressMsg = ChatMessageBenchmarkResult(
                    id: currentBenchmarkMessageId, // Keep same ID to update
                    side: .SYSTEM, latencyMs: 0, accelerator: mutableModel.defaultAccelerator.rawValue,
                    orderedStats: [], statValues: [:], values: [], histogram: Histogram(buckets: [], maxCount: 0, highlightBucketIndex: -1),
                    warmupCurrent: i + 1, warmupTotal: warmupCount, iterationCurrent: 0, iterationTotal: iterations, highlightStat: ""
                )
                await MainActor.run {
                    if let index = getMessageIndex(model: mutableModel, messageId: currentBenchmarkMessageId) {
                        super.replaceMessage(model: mutableModel, index: index, message: progressMsg)
                    }
                }
            }

            // Iteration loop
            for i in 0..<iterations {
                let result = try await modelHelper.runInference(model: mutableModel, inputImage: message.uiImage ?? UIImage(), primaryColor: primaryColor)
                latencies.append(result.latencyMs)
                let progressMsg = ChatMessageBenchmarkResult(
                    id: currentBenchmarkMessageId,
                    side: .SYSTEM, latencyMs: 0, accelerator: mutableModel.defaultAccelerator.rawValue,
                    orderedStats: [], statValues: [:], values: latencies, histogram: Histogram(buckets: [], maxCount: 0, highlightBucketIndex: -1), // Update histogram later
                    warmupCurrent: warmupCount, warmupTotal: warmupCount, iterationCurrent: i + 1, iterationTotal: iterations, highlightStat: ""
                )
                await MainActor.run {
                     if let index = getMessageIndex(model: mutableModel, messageId: currentBenchmarkMessageId) {
                        super.replaceMessage(model: mutableModel, index: index, message: progressMsg)
                    }
                }
            }

            // Post-process latencies to create final benchmark result
            let avgLatency = latencies.reduce(0, +) / Float(latencies.count)
            let stats = [Stat(id: "avg_latency", label: "Avg. Latency", unit: "ms")]
            let statValues = ["avg_latency": avgLatency]
            // Dummy histogram for now
            let histogram = Histogram(buckets: [Int(avgLatency)], maxCount: Int(avgLatency) + 10, highlightBucketIndex: 0)

            let finalResultMsg = ChatMessageBenchmarkResult(
                id: currentBenchmarkMessageId,
                side: .SYSTEM, latencyMs: avgLatency, accelerator: mutableModel.defaultAccelerator.rawValue,
                orderedStats: stats, statValues: statValues, values: latencies, histogram: histogram,
                warmupCurrent: warmupCount, warmupTotal: warmupCount, iterationCurrent: iterations, iterationTotal: iterations,
                highlightStat: "avg_latency"
            )
            await MainActor.run {
                if let index = getMessageIndex(model: mutableModel, messageId: currentBenchmarkMessageId) {
                    super.replaceMessage(model: mutableModel, index: index, message: finalResultMsg)
                }
            }

        } catch {
            await MainActor.run {
                let errorMessage = ChatMessageWarning(side: .SYSTEM, content: "Error during benchmark: \(error.localizedDescription)")
                super.addMessage(model: mutableModel, message: errorMessage)
            }
        }
        await MainActor.run { setInProgress(false) }
    }

    func runAgain(model: Model, message: ChatMessageImage, primaryColor: Color) async {
        var mutableModel = model
        guard let inputImage = message.uiImage else {
            await MainActor.run {
                let errorMessage = ChatMessageWarning(side: .SYSTEM, content: "Input image not found for run again.")
                super.addMessage(model: mutableModel, message: errorMessage)
            }
            return
        }

        await MainActor.run {
            // Add the original user message back to start a new interaction turn
            super.addMessage(model: mutableModel, message: message)
        }

        // Then generate the response as if it's a new query
        await generateResponse(model: mutableModel, inputImage: inputImage, primaryColor: primaryColor)
    }

    private func generateClassificationMessage(result: ImageClassificationInferenceResult, model: Model) -> ChatMessageClassification {
        return ChatMessageClassification(
            side: .MODEL,
            latencyMs: result.latencyMs,
            accelerator: model.defaultAccelerator.rawValue, // Or get from actual interpreter if it varies
            classifications: result.classifications,
            maxBarWidth: 200 // Example max bar width, adjust as needed for UI
        )
    }
}
