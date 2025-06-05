import Foundation
// import SwiftUI // Would be needed if 'Image' below was the actual SwiftUI Image

// Placeholder for SwiftUI Image type if not importing SwiftUI directly in model files.
// If this file were part of the UI layer, SwiftUI import would be natural.
// For pure data models, it's better to use a more abstract representation (e.g., String for image name/URL)
// or define a simple struct/protocol if specific image properties are needed in the model.
// For now, let's assume 'Image' is a conceptual placeholder or a simple custom type.
struct ImagePlaceholder: Hashable, Codable { // Codable if Task is Codable
    let name: String // Represents systemName for SF Symbols or asset name
}


// Corresponds to TaskType in Kotlin
enum TaskType: String, Codable, CaseIterable, Hashable, Identifiable {
    case TEXT_CLASSIFICATION, TEXT_GENERATION, IMAGE_GENERATION, IMAGE_CLASSIFICATION // Add others as they appear in Kotlin
    // case AUDIO_CLASSIFICATION, OBJECT_DETECTION, IMAGE_SEGMENTATION, INTERACTIVE_SEGMENTATION

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .TEXT_CLASSIFICATION: return "Text Classification"
        case .TEXT_GENERATION: return "Text Generation"
        case .IMAGE_GENERATION: return "Image Generation"
        case .IMAGE_CLASSIFICATION: return "Image Classification"
        // Add other cases
        }
    }
}

// Corresponds to Task in Kotlin
struct Task: Identifiable, Hashable, Codable { // Added Codable
    let id: String // Using id for Identifiable, maps from task.name in some Kotlin contexts
    let type: TaskType
    let name: String // @StringRes in Kotlin, maps to a descriptive name
    let description: String // @StringRes in Kotlin
    let iconName: String // Placeholder for ImageVector, using SF Symbol name or asset name
    let models: [Model]
    // val updateTrigger: StateFlow<Long?> = MutableStateFlow(null) // Omitted for now

    // Initializer
    init(type: TaskType, name: String, description: String, iconName: String, models: [Model]) {
        self.id = type.rawValue // Or a more unique ID if needed
        self.type = type
        self.name = name
        self.description = description
        self.iconName = iconName
        self.models = models
    }
}

// Pre-defined Task instances
// These require Model instances (MODEL_TEXT_CLASSIFICATION_MOBILEBERT, etc.) to be defined.
// Assuming Model.swift contains these definitions.

let TASK_TEXT_CLASSIFICATION = Task(
    type: .TEXT_CLASSIFICATION,
    name: "Sentiment Analysis", // Example, replace with actual @StringRes value
    description: "Classify text into predefined categories like positive/negative sentiment.", // Example
    iconName: "text.bubble", // Example SF Symbol name
    models: MODELS_TEXT_CLASSIFICATION // Assumes MODELS_TEXT_CLASSIFICATION is defined in Model.swift
)

let MODEL_IMAGE_CLASSIFICATION_MOBILENET = Model(
    id: "image_classification_mobilenet_v1",
    name: "MobileNetV1 Image Classification",
    overview: "A lightweight, general-purpose model for image classification.",
    description: "MobileNetV1 is optimized for mobile and edge devices, providing a good balance between accuracy and speed for classifying images into 1000 categories.",
    publisher: "Google",
    license: "Apache-2.0",
    link: "https://www.tensorflow.org/lite/examples/image_classification/overview",
    defaultAccelerator: .CPU,
    defaultModelPath: "image_classification/mobilenet_v1_1.0_224.tflite", // Placeholder path
    modelPaths: [.CPU: "image_classification/mobilenet_v1_1.0_224.tflite"], // Placeholder path
    modelDataFiles: [
        ModelDataFile(label: "labels", path: "image_classification/labels.txt", size: 20000) // Example size
    ],
    config: [ // Example config, replace with actual if any
        // E.g., NumberSliderConfig(key: .THRESHOLD, title: "Threshold", value: 0.5, minValue: 0.1, maxValue: 0.9, step: 0.1)
    ],
    downloadStatus: ModelDownloadStatus(type: .NOT_DOWNLOADED)
)

let MODELS_IMAGE_CLASSIFICATION = [MODEL_IMAGE_CLASSIFICATION_MOBILENET]

let TASK_IMAGE_CLASSIFICATION = Task(
    type: .IMAGE_CLASSIFICATION,
    name: "Image Classification",
    description: "Identify objects and scenes within images.",
    iconName: "photo.on.rectangle.angled", // Example SF Symbol
    models: MODELS_IMAGE_CLASSIFICATION
)

// Example for Text Generation (assuming relevant models are defined in Model.swift)
/*
let TASK_TEXT_GENERATION = Task(
    type: .TEXT_GENERATION,
    name: "Generate Text",
    description: "Create new text based on a prompt or input.",
    iconName: "square.and.pencil",
    models: MODELS_TEXT_GENERATION // Assumes this list is defined
)
*/

// Example for Image Generation (assuming relevant models are defined in Model.swift)
/*
let TASK_IMAGE_GENERATION = Task(
    type: .IMAGE_GENERATION,
    name: "Generate Images",
    description: "Create images from text prompts.",
    iconName: "photo",
    models: MODELS_IMAGE_GENERATION // Assumes this list is defined
)
*/

// The main list of tasks
let TASKS = [
    TASK_TEXT_CLASSIFICATION,
    TASK_IMAGE_CLASSIFICATION, // Added new task
    // TASK_TEXT_GENERATION, // Uncomment when defined
    // TASK_IMAGE_GENERATION, // Uncomment when defined
].filter { !$0.models.isEmpty } // Ensure tasks with no models are not included

// Corresponds to getModelByName in Kotlin
func getModelByName(modelName: String) -> Model? {
    for task in TASKS {
        if let model = task.models.first(where: { $0.name == modelName }) {
            return model
        }
    }
    // Fallback to checking ALL_MODELS if not found in TASKS context (though ALL_MODELS might be very large)
    // This depends on how models are organized and accessed.
    // If ALL_MODELS is comprehensive and TASKS might not cover all, this is a useful fallback.
    // Also update ALL_MODELS to include the new image classification models
    // This should be done where ALL_MODELS is defined, likely in Model.swift or here if appropriate.
    // For now, assuming ALL_MODELS is updated elsewhere or this function primarily relies on TASKS.
    return ALL_MODELS.first(where: { $0.name == modelName }) // Make sure ALL_MODELS includes MODELS_IMAGE_CLASSIFICATION
}

// Update ALL_MODELS to include new models (if defined in this file, or ensure Model.swift is updated)
// This is a bit tricky as ALL_MODELS was defined in Model.swift.
// For consistency, ALL_MODELS should be updated in Model.swift.
// The following is a conceptual update; actual update should be in Model.swift.
/*
 let ALL_MODELS_UPDATED = MODELS_TEXT_CLASSIFICATION + MODELS_IMAGE_CLASSIFICATION
*/
