import Foundation
import UIKit // For UIImage
import CoreGraphics // For CGFloat

// Protocol Definition
protocol ChatMessage: Identifiable, Hashable, Codable {
    var id: UUID { get }
    var type: ChatMessageType { get }
    var side: ChatSide { get }
    var latencyMs: Float { get }
    var accelerator: String { get } // Name of the accelerator e.g. "CPU", "GPU"
}

// MARK: - ChatMessage Implementations

struct ChatMessageLoading: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .LOADING_MESSAGE
    var side: ChatSide
    var latencyMs: Float = 0
    var accelerator: String = ""
}

struct ChatMessageInfo: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .INFO_MESSAGE
    var side: ChatSide = .SYSTEM // Typically system messages
    var latencyMs: Float = 0
    var accelerator: String = ""
    let content: String
}

struct ChatMessageWarning: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .WARNING_MESSAGE
    var side: ChatSide = .SYSTEM // Typically system messages
    var latencyMs: Float = 0
    var accelerator: String = ""
    let content: String
}

struct ChatMessageConfigValuesChange: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .CONFIG_VALUES_CHANGE_MESSAGE
    var side: ChatSide = .SYSTEM
    var latencyMs: Float = 0
    var accelerator: String = "" // Not typically relevant for this type
    let modelId: String
    let oldValues: [String: AnyHashable]
    let newValues: [String: AnyHashable]
}

struct ChatMessageText: ChatMessage {
    let id: UUID = UUID()
    var type: ChatMessageType = .TEXT_MESSAGE // Can be changed by LlmBenchmarkResult
    var side: ChatSide
    var latencyMs: Float
    var accelerator: String
    let content: String
    let isMarkdown: Bool
    var llmBenchmarkResultId: UUID? = nil // Optional link
}

struct ChatMessageImage: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .IMAGE_MESSAGE
    var side: ChatSide
    var latencyMs: Float
    var accelerator: String

    // UIImage is not directly Codable. We'd need to convert to/from Data.
    // For simplicity in this step, we'll make it non-Codable or handle it manually.
    // Let's make it transient for Codable for now.
    let imageData: Data? // Store image as Data for Codable

    var uiImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    init(id: UUID = UUID(), type: ChatMessageType = .IMAGE_MESSAGE, side: ChatSide, latencyMs: Float, accelerator: String, uiImage: UIImage?) {
        self.id = id
        self.type = type
        self.side = side
        self.latencyMs = latencyMs
        self.accelerator = accelerator
        self.imageData = uiImage?.pngData() // Or jpegData with compression
    }

    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, type, side, latencyMs, accelerator, imageData
    }

    // Hashable conformance (id is sufficient for uniqueness)
    static func == (lhs: ChatMessageImage, rhs: ChatMessageImage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ChatMessageImageWithHistory: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .IMAGE_WITH_HISTORY_MESSAGE
    var side: ChatSide
    var latencyMs: Float
    var accelerator: String

    let imagesData: [Data] // Store images as Data for Codable
    var uiImages: [UIImage] {
        imagesData.compactMap { UIImage(data: $0) }
    }

    let totalIterations: Int
    let currentIteration: Int

    func isRunning() -> Bool {
        return currentIteration < totalIterations && currentIteration > 0
    }

    init(id: UUID = UUID(), type: ChatMessageType = .IMAGE_WITH_HISTORY_MESSAGE, side: ChatSide, latencyMs: Float, accelerator: String, uiImages: [UIImage], totalIterations: Int, currentIteration: Int) {
        self.id = id
        self.type = type
        self.side = side
        self.latencyMs = latencyMs
        self.accelerator = accelerator
        self.imagesData = uiImages.compactMap { $0.pngData() }
        self.totalIterations = totalIterations
        self.currentIteration = currentIteration
    }

    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, type, side, latencyMs, accelerator, imagesData, totalIterations, currentIteration
    }

    // Hashable conformance
    static func == (lhs: ChatMessageImageWithHistory, rhs: ChatMessageImageWithHistory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ChatMessageClassification: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .CLASSIFICATION_MESSAGE
    var side: ChatSide
    var latencyMs: Float
    var accelerator: String
    let classifications: [Classification]
    let maxBarWidth: CGFloat? // CGFloat is not directly Codable, consider Double or skip for pure model

    // For Codable, maxBarWidth might need to be Double or excluded if it's purely for UI.
    // Let's make it Double for Codable.
    let codableMaxBarWidth: Double?

    init(id: UUID = UUID(), type: ChatMessageType = .CLASSIFICATION_MESSAGE, side: ChatSide, latencyMs: Float, accelerator: String, classifications: [Classification], maxBarWidth: CGFloat?) {
        self.id = id
        self.type = type
        self.side = side
        self.latencyMs = latencyMs
        self.accelerator = accelerator
        self.classifications = classifications
        self.maxBarWidth = maxBarWidth
        self.codableMaxBarWidth = maxBarWidth != nil ? Double(maxBarWidth!) : nil
    }

    enum CodingKeys: String, CodingKey {
        case id, type, side, latencyMs, accelerator, classifications, codableMaxBarWidth
    }
}


struct ChatMessageBenchmarkResult: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .BENCHMARK_RESULT_MESSAGE
    var side: ChatSide = .SYSTEM
    var latencyMs: Float // Often this is one of the stats
    var accelerator: String
    let orderedStats: [Stat]
    let statValues: [String: Float] // Stat.id to value
    let values: [Float] // Raw values for histogram perhaps
    let histogram: Histogram
    let warmupCurrent: Int
    let warmupTotal: Int
    let iterationCurrent: Int
    let iterationTotal: Int
    let highlightStat: String

    func isWarmingUp() -> Bool {
        return warmupCurrent < warmupTotal && warmupCurrent > 0
    }

    func isRunning() -> Bool {
        return iterationCurrent < iterationTotal && iterationCurrent > 0
    }
}

struct ChatMessageBenchmarkLlmResult: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .BENCHMARK_LLM_RESULT_MESSAGE
    var side: ChatSide = .SYSTEM
    var latencyMs: Float // Often this is one of the stats
    var accelerator: String
    let orderedStats: [Stat]
    let statValues: [String: Float] // Stat.id to value
    let running: Bool
}

struct ChatMessagePromptTemplates: ChatMessage {
    let id: UUID = UUID()
    let type: ChatMessageType = .PROMPT_TEMPLATES_MESSAGE
    var side: ChatSide = .SYSTEM
    var latencyMs: Float = 0
    var accelerator: String = ""
    let templates: [PromptTemplate]
    let showMakeYourOwn: Bool
}

// Note on Codable for protocol ChatMessage:
// If you need to decode an array of `ChatMessage` (i.e., `[ChatMessage]`),
// you'll need a strategy for decoding heterogeneous arrays. This usually involves
// an outer enum that acts as a wrapper, decoding the `type` first and then
// decoding into the specific struct.
// For example:
/*
enum AnyChatMessage: Codable {
    case loading(ChatMessageLoading)
    // ... other cases ...

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self) // A common key like 'type'
        let type = try container.decode(ChatMessageType.self, forKey: .type)
        // Switch on type to decode the specific message
    }
    // encode(to encoder: Encoder) throws { ... }
}
*/
// For now, each struct is Codable on its own.
