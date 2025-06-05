import Foundation

// Corresponds to ModelDataFile in Kotlin
struct ModelDataFile: Codable, Hashable {
    let label: String
    let path: String
    let size: Int
}

// Corresponds to Accelerator in Kotlin
enum Accelerator: String, Codable, CaseIterable, Hashable {
    case CPU, GPU, NNAPI // NNAPI might be Android-specific, consider if needed for iOS
}

// Corresponds to ModelDownloadStatusType in Kotlin
enum ModelDownloadStatusType: Codable, Hashable {
    case NOT_DOWNLOADED, DOWNLOADING, DOWNLOADED, ERROR
}

// Corresponds to ModelDownloadStatus in Kotlin
struct ModelDownloadStatus: Codable, Hashable {
    var type: ModelDownloadStatusType
    var progress: Float = 0.0
    var error: String? = nil
}

// Corresponds to ConfigKey in Kotlin
enum ConfigKey: String, Codable, CaseIterable, Hashable {
    // Common
    case MAX_RESULTS, THRESHOLD, DELEGATE // DELEGATE might be NNAPI specific

    // Text Classification
    // No specific keys mentioned for Text Classification in the provided snippet

    // Text Generation (LLM Inference)
    case TOP_K, TEMPERATURE, MAX_TOKENS, RANDOM_SEED

    // Image Generation
    case NUMBER_OF_IMAGES, IMAGE_GENERATION_STEPS, POSITIVE_PROMPT, NEGATIVE_PROMPT, GUIDANCE, SEED

    // Placeholder for other model types if needed
}

// Corresponds to Model in Kotlin
struct Model: Codable, Identifiable, Hashable {
    let id: String // Equivalent to `name` used as ID
    let name: String
    let overview: String
    let description: String
    let publisher: String
    let license: String
    let link: String
    let defaultAccelerator: Accelerator
    let defaultModelPath: String
    let modelPaths: [Accelerator: String]
    let modelDataFiles: [ModelDataFile]
    let config: [Config] // Assuming Config protocol/struct is defined elsewhere
    var downloadStatus: ModelDownloadStatus
    var instance: Any? = nil // For holding TFLite Interpreter or other runtime instances

    // Codable conformance will be manual to exclude 'instance'
    enum CodingKeys: String, CodingKey {
        case id, name, overview, description, publisher, license, link
        case defaultAccelerator, defaultModelPath, modelPaths, modelDataFiles, config, downloadStatus
    }

    // Custom Initializer from Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decode(String.self, forKey: .overview)
        description = try container.decode(String.self, forKey: .description)
        publisher = try container.decode(String.self, forKey: .publisher)
        license = try container.decode(String.self, forKey: .license)
        link = try container.decode(String.self, forKey: .link)
        defaultAccelerator = try container.decode(Accelerator.self, forKey: .defaultAccelerator)
        defaultModelPath = try container.decode(String.self, forKey: .defaultModelPath)
        modelPaths = try container.decode([Accelerator: String].self, forKey: .modelPaths)
        modelDataFiles = try container.decode([ModelDataFile].self, forKey: .modelDataFiles)

        // Handling [Config] decoding is complex. Assuming AnyConfig wrapper or specific types for now.
        // This part needs to be robust based on how Config is actually structured and serialized.
        // For this example, assuming it's an array of a concrete Codable type or AnyConfig.
        // If it's truly [any Config], custom decoding logic for heterogeneous arrays is needed.
        // Let's assume for now it's being handled by a mechanism that makes [Config] decodable.
        // This might involve an enum wrapper like AnyConfig as discussed in Config.swift.
        // If direct decoding of `[any Config]` fails, this is the spot to fix.
        // As a placeholder that will likely fail if not using AnyConfig or similar:
        do {
            config = try container.decode([AnyConfigPlaceholder].self, forKey: .config)
        } catch {
            // Fallback or error handling if direct decoding fails.
            // This is a known challenge with protocols and Codable.
            print("Warning: Could not decode [Config]. Defaulting to empty. Error: \(error)")
            config = []
        }

        downloadStatus = try container.decode(ModelDownloadStatus.self, forKey: .downloadStatus)
        instance = nil // Initialize instance as nil, it's not persisted
    }

    // Custom Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(overview, forKey: .overview)
        try container.encode(description, forKey: .description)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(license, forKey: .license)
        try container.encode(link, forKey: .link)
        try container.encode(defaultAccelerator, forKey: .defaultAccelerator)
        try container.encode(defaultModelPath, forKey: .defaultModelPath)
        try container.encode(modelPaths, forKey: .modelPaths)
        try container.encode(modelDataFiles, forKey: .modelDataFiles)
        // Similar to decoding, encoding [Config] needs care.
        // Assuming AnyConfigPlaceholder or similar wrapper that is Encodable.
        // If config stores `[AnyConfigPlaceholder]`, this would work:
        if let encodableConfig = config as? [AnyConfigPlaceholder] {
             try container.encode(encodableConfig, forKey: .config)
        } else {
            // Handle cases where config is not directly encodable or needs transformation.
            print("Warning: Could not encode [Config] directly. Encoding as empty array.")
            try container.encode([AnyConfigPlaceholder](), forKey: .config)
        }
        try container.encode(downloadStatus, forKey: .downloadStatus)
        // 'instance' is not encoded
    }

    // Original init for non-Codable creation
    init(id: String, name: String, overview: String, description: String, publisher: String, license: String, link: String, defaultAccelerator: Accelerator, defaultModelPath: String, modelPaths: [Accelerator : String], modelDataFiles: [ModelDataFile], config: [Config], downloadStatus: ModelDownloadStatus, instance: Any? = nil) {
        self.id = id
        self.name = name
        self.overview = overview
        self.description = description
        self.publisher = publisher
        self.license = license
        self.link = link
        self.defaultAccelerator = defaultAccelerator
        self.defaultModelPath = defaultModelPath
        self.modelPaths = modelPaths
        self.modelDataFiles = modelDataFiles
        self.config = config
        self.downloadStatus = downloadStatus
        self.instance = instance
    }


    // Simplified getPath - needs actual file system logic for iOS
    func getPath(accelerator: Accelerator? = nil) -> String {
        return modelPaths[accelerator ?? defaultAccelerator] ?? defaultModelPath
    }

    // Config value getters
    func getConfigValue(key: ConfigKey) -> ConfigValue? {
        if let configItem = config.first(where: { $0.key == key }) {
            return configItem.value
        }
        return nil
    }

    func getIntConfigValue(key: ConfigKey) -> Int? {
        guard let configValue = getConfigValue(key: key) else { return nil }
        if case .integer(let value) = configValue {
            return value
        }
        return nil // Or a default value
    }

    func getFloatConfigValue(key: ConfigKey) -> Float? {
        guard let configValue = getConfigValue(key: key) else { return nil }
        if case .float(let value) = configValue {
            return value
        }
        return nil // Or a default value
    }

    func getStringConfigValue(key: ConfigKey) -> String? {
        guard let configValue = getConfigValue(key: key) else { return nil }
        if case .string(let value) = configValue {
            return value
        }
        return nil // Or a default value
    }

    func getBooleanConfigValue(key: ConfigKey) -> Bool? {
        guard let configValue = getConfigValue(key: key) else { return nil }
        if case .boolean(let value) = configValue {
            return value
        }
        return nil // Or a default value
    }

    // Conformance to Identifiable
    var identifier: String { id }

    // Hashable conformance: Manually implement if 'instance' makes auto-synthesis impossible or unwanted.
    // For now, relying on other properties for Hashable, excluding 'instance'.
    static func == (lhs: Model, rhs: Model) -> Bool {
        lhs.id == rhs.id // Instance is not part of equality
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Instance is not part of hashability
    }
}

// Placeholder for AnyConfig to make Model Codable with [Config]
// This would be the enum wrapper discussed in Config.swift
struct AnyConfigPlaceholder: Config, Codable, Hashable {
    var id: String { key.rawValue }
    var key: ConfigKey
    var title: String
    var valueType: ValueType
    var editorType: ConfigEditorType
    var value: ConfigValue
    // This is a minimal stub. A real AnyConfig would have cases for each Config type.
}


// Corresponds to ImportedModelInfo in Kotlin
struct ImportedModelInfo: Codable, Hashable {
    let name: String
    let path: String
    // Add other relevant properties if any
}

// Pre-defined model instances (example)
// These will require Config, ConfigValue, etc. to be defined first.
// For now, define with empty configs or placeholder values.

let MODEL_TEXT_CLASSIFICATION_MOBILEBERT = Model(
    id: "text_classification_mobilebert",
    name: "MobileBERT Sentiment Analysis",
    overview: "A lightweight model for text sentiment classification.",
    description: "MobileBERT is a compressed version of BERT, optimized for mobile and edge devices. This model is fine-tuned for sentiment analysis.",
    publisher: "Google",
    license: "Apache-2.0",
    link: "https://www.tensorflow.org/lite/examples/text_classification/overview",
    defaultAccelerator: .CPU,
    defaultModelPath: "text_classification/mobilebert_float.tflite", // Placeholder path
    modelPaths: [.CPU: "text_classification/mobilebert_float.tflite"], // Placeholder path
    modelDataFiles: [],
    config: [], // Placeholder
    downloadStatus: ModelDownloadStatus(type: .NOT_DOWNLOADED)
)

let MODELS_TEXT_CLASSIFICATION = [MODEL_TEXT_CLASSIFICATION_MOBILEBERT]

// Add other models and model lists here once their configs are defined
// e.g., MODEL_TEXT_GENERATION_LLAMA2, MODELS_TEXT_GENERATION etc.
// e.g., MODEL_IMAGE_GENERATION_SD_QUANTIZED, MODELS_IMAGE_GENERATION etc.

let ALL_MODELS = MODELS_TEXT_CLASSIFICATION + MODELS_IMAGE_CLASSIFICATION // Concatenate all model lists here
    // + MODELS_TEXT_GENERATION
    // + MODELS_IMAGE_GENERATION
    // ... and so on
