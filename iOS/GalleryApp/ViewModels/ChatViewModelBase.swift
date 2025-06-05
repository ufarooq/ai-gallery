import Foundation
import SwiftUI // For @Published, ObservableObject

// Assuming ChatMessage and related types are defined in Models/Chat/
// and Task, Model are defined in Models/

struct ChatUiState: Equatable {
    var inProgress: Bool = false
    var isResettingSession: Bool = false
    var preparing: Bool = false
    var messagesByModel: [String: [any ChatMessage]] = [:] // Model.id to messages
    var streamingMessagesByModel: [String: (any ChatMessage)?] = [:] // Model.id to optional streaming message
    var showingStatsByModel: [String: Set<UUID>] = [:] // Model.id to Set of message IDs

    static func == (lhs: ChatUiState, rhs: ChatUiState) -> Bool {
        lhs.inProgress == rhs.inProgress &&
        lhs.isResettingSession == rhs.isResettingSession &&
        lhs.preparing == rhs.preparing &&
        lhs.messagesByModel.keys == rhs.messagesByModel.keys && // Check keys first
        lhs.messagesByModel.allSatisfy { key, lhsMessages in
            guard let rhsMessages = rhs.messagesByModel[key] else { return false }
            if lhsMessages.count != rhsMessages.count { return false }
            // Compare messages by their IDs since `any ChatMessage` itself isn't directly Equatable for array comparison
            return zip(lhsMessages, rhsMessages).allSatisfy { $0.id == $1.id && $0.type == $1.type } // Basic check
        } &&
        lhs.streamingMessagesByModel.keys == rhs.streamingMessagesByModel.keys &&
        lhs.streamingMessagesByModel.allSatisfy { key, lhsMessage in
            let rhsMessage = rhs.streamingMessagesByModel[key]
            return lhsMessage??.id == rhsMessage??.id // Compare IDs of optional messages
        } &&
        lhs.showingStatsByModel == rhs.showingStatsByModel
    }
}


class ChatViewModelBase: ObservableObject {
    @Published var uiState: ChatUiState
    let task: Task

    init(task: Task) {
        self.task = task
        self.uiState = Self.createUiState(task: task)
    }

    private static func createUiState(task: Task) -> ChatUiState {
        var messagesByModel: [String: [any ChatMessage]] = [:]
        var streamingMessagesByModel: [String: (any ChatMessage)?] = [:]
        var showingStatsByModel: [String: Set<UUID>] = [:]

        for model in task.models {
            var initialMessages: [any ChatMessage] = []
            // In Kotlin, this checks for llmPromptTemplates from ModelType, which isn't directly translated yet.
            // Assuming a placeholder check or that this logic will be added to Model/Task later.
            // For now, let's add a generic info message or leave it empty.
            // Example: if model.supportsPromptTemplates (add this property to Model if needed)
            // For now, let's add a simple prompt template message if the task is text generation
            if task.type == .TEXT_GENERATION { // This is a guess, replace with actual logic
                 let templates = [ // Example templates
                    PromptTemplate(title: "Summarize", description: "Summarize the following text:", prompt: "Summarize: {{text_input}}"),
                    PromptTemplate(title: "Translate", description: "Translate to French:", prompt: "Translate to French: {{text_input}}")
                 ]
                 initialMessages.append(ChatMessagePromptTemplates(side: .SYSTEM, templates: templates, showMakeYourOwn: true))
            }

            messagesByModel[model.id] = initialMessages
            streamingMessagesByModel[model.id] = nil
            showingStatsByModel[model.id] = Set<UUID>()
        }
        return ChatUiState(messagesByModel: messagesByModel, streamingMessagesByModel: streamingMessagesByModel, showingStatsByModel: showingStatsByModel)
    }

    // MARK: - Message Manipulation Methods
    func addMessage(model: Model, message: any ChatMessage) {
        var newUiState = self.uiState
        newUiState.messagesByModel[model.id, default: []].append(message)
        self.uiState = newUiState
    }

    func insertMessageAfter(model: Model, anchorMessageId: UUID, messageToAdd: any ChatMessage) {
        var newUiState = self.uiState
        if var messages = newUiState.messagesByModel[model.id],
           let anchorIndex = messages.firstIndex(where: { $0.id == anchorMessageId }) {
            messages.insert(messageToAdd, at: messages.index(after: anchorIndex))
            newUiState.messagesByModel[model.id] = messages
            self.uiState = newUiState
        }
    }

    func removeMessageAt(model: Model, index: Int) {
        var newUiState = self.uiState
        if var messages = newUiState.messagesByModel[model.id], messages.indices.contains(index) {
            messages.remove(at: index)
            newUiState.messagesByModel[model.id] = messages
            self.uiState = newUiState
        }
    }

    func removeLastMessage(model: Model) {
        var newUiState = self.uiState
        if var messages = newUiState.messagesByModel[model.id], !messages.isEmpty {
            messages.removeLast()
            newUiState.messagesByModel[model.id] = messages
            self.uiState = newUiState
        }
    }

    func clearAllMessages(model: Model) {
        var newUiState = self.uiState
        newUiState.messagesByModel[model.id] = []
        // Potentially re-add initial messages like prompt templates
        if task.type == .TEXT_GENERATION { // Example, mirror createUiState logic
             let templates = [
                PromptTemplate(title: "Summarize", description: "Summarize the following text:", prompt: "Summarize: {{text_input}}"),
                PromptTemplate(title: "Translate", description: "Translate to French:", prompt: "Translate to French: {{text_input}}")
             ]
             newUiState.messagesByModel[model.id]?.append(ChatMessagePromptTemplates(side: .SYSTEM, templates: templates, showMakeYourOwn: true))
        }
        self.uiState = newUiState
    }

    func getLastMessage(model: Model) -> (any ChatMessage)? {
        return self.uiState.messagesByModel[model.id]?.last
    }

    func updateLastTextMessageContentIncrementally(model: Model, partialContent: String, latencyMs: Float) {
        var newUiState = self.uiState
        guard var messages = newUiState.messagesByModel[model.id],
              let lastMessageIndex = messages.lastIndex(where: { $0.type == .TEXT_MESSAGE && $0.side == .MODEL }),
              var lastTextMessage = messages[lastMessageIndex] as? ChatMessageText else {
            // If no such message, create one (or handle error)
            let newMessage = ChatMessageText(side: .MODEL, latencyMs: latencyMs, accelerator: model.defaultAccelerator.rawValue, content: partialContent, isMarkdown: true)
            newUiState.messagesByModel[model.id, default: []].append(newMessage)
            self.uiState = newUiState
            return
        }

        let updatedContent = lastTextMessage.content + partialContent
        // The Kotlin code has a processLlmResponse which might do more (e.g. markdown processing, cleanup).
        // For now, direct concatenation.
        messages[lastMessageIndex] = ChatMessageText(
            id: lastTextMessage.id,
            type: lastTextMessage.type,
            side: lastTextMessage.side,
            latencyMs: latencyMs, // Update latency with the latest packet
            accelerator: lastTextMessage.accelerator,
            content: updatedContent,
            isMarkdown: lastTextMessage.isMarkdown,
            llmBenchmarkResultId: lastTextMessage.llmBenchmarkResultId
        )
        newUiState.messagesByModel[model.id] = messages
        self.uiState = newUiState
    }

    func updateLastTextMessageLlmBenchmarkResult(model: Model, llmBenchmarkResult: ChatMessageBenchmarkLlmResult) {
        var newUiState = self.uiState
        guard var messages = newUiState.messagesByModel[model.id],
              let lastMessageIndex = messages.lastIndex(where: { $0.type == .TEXT_MESSAGE && $0.side == .MODEL }),
              var lastTextMessage = messages[lastMessageIndex] as? ChatMessageText else {
            return
        }

        messages[lastMessageIndex] = ChatMessageText(
            id: lastTextMessage.id,
            type: .BENCHMARK_LLM_RESULT_MESSAGE, // Change type
            side: lastTextMessage.side,
            latencyMs: llmBenchmarkResult.latencyMs, // Use latency from benchmark result
            accelerator: llmBenchmarkResult.accelerator,
            content: lastTextMessage.content, // Keep original content
            isMarkdown: lastTextMessage.isMarkdown,
            llmBenchmarkResultId: llmBenchmarkResult.id // Link to the benchmark result
        )
        // Optionally, add the llmBenchmarkResult as a separate message if that's the design
        // addMessage(model: model, message: llmBenchmarkResult)
        newUiState.messagesByModel[model.id] = messages
        self.uiState = newUiState
    }

    func replaceLastMessage(model: Model, message: any ChatMessage, type: ChatMessageType) {
        var newUiState = self.uiState
        if var messages = newUiState.messagesByModel[model.id],
           let lastIndexMatchingType = messages.lastIndex(where: { $0.type == type }) {
            messages[lastIndexMatchingType] = message
            newUiState.messagesByModel[model.id] = messages
            self.uiState = newUiState
        } else { // If no message of that type, append the new one
            addMessage(model: model, message: message)
        }
    }

    func replaceMessage(model: Model, index: Int, message: any ChatMessage) {
        var newUiState = self.uiState
        if var messages = newUiState.messagesByModel[model.id], messages.indices.contains(index) {
            messages[index] = message
            newUiState.messagesByModel[model.id] = messages
            self.uiState = newUiState
        }
    }

    func updateStreamingMessage(model: Model, message: (any ChatMessage)?) {
        var newUiState = self.uiState
        newUiState.streamingMessagesByModel[model.id] = message
        self.uiState = newUiState
    }

    // MARK: - State Update Methods
    func setInProgress(_ inProgress: Bool) {
        var newUiState = self.uiState
        newUiState.inProgress = inProgress
        self.uiState = newUiState
    }

    func setIsResettingSession(_ isResettingSession: Bool) {
        var newUiState = self.uiState
        newUiState.isResettingSession = isResettingSession
        self.uiState = newUiState
    }

    func setPreparing(_ preparing: Bool) {
        var newUiState = self.uiState
        newUiState.preparing = preparing
        self.uiState = newUiState
    }

    // MARK: - Other Methods
    func addConfigChangedMessage(oldConfigValues: [String: AnyHashable], newConfigValues: [String: AnyHashable], model: Model) {
        let configChangeMessage = ChatMessageConfigValuesChange(
            modelId: model.id,
            oldValues: oldConfigValues,
            newValues: newConfigValues
        )
        addMessage(model: model, message: configChangeMessage)
    }

    func getMessageIndex(model: Model, messageId: UUID) -> Int? {
        return self.uiState.messagesByModel[model.id]?.firstIndex(where: { $0.id == messageId })
    }

    func isShowingStats(model: Model, messageId: UUID) -> Bool {
        return self.uiState.showingStatsByModel[model.id]?.contains(messageId) ?? false
    }

    func toggleShowingStats(model: Model, messageId: UUID) {
        var newUiState = self.uiState
        if var statsSet = newUiState.showingStatsByModel[model.id] {
            if statsSet.contains(messageId) {
                statsSet.remove(messageId)
            } else {
                statsSet.insert(messageId)
            }
            newUiState.showingStatsByModel[model.id] = statsSet
        } else {
            newUiState.showingStatsByModel[model.id] = [messageId]
        }
        self.uiState = newUiState
    }
}
