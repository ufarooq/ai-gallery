import Foundation

// Corresponds to AllowedModel in Kotlin
struct AllowedModel: Codable, Hashable, Identifiable {
    let id: String // name can serve as id
    let name: String
    let overview: String
    let description: String
    let publisher: String
    let license: String
    let link: String
    let defaultAccelerator: Accelerator
    let defaultModelPath: String
    let modelPaths: [String: String] // Accelerator.name to path
    let modelDataFiles: [ModelDataFile]? // Nullable in Kotlin
    let config: [String: ConfigValue] // ConfigKey.name to ConfigValue

    // Corresponds to toModel() in Kotlin
    func toModel() -> Model {
        // Convert modelPaths from [String: String] to [Accelerator: String]
        var swiftModelPaths: [Accelerator: String] = [:]
        for (key, value) in modelPaths {
            if let accelerator = Accelerator(rawValue: key) {
                swiftModelPaths[accelerator] = value
            }
        }

        // Convert config from [String: ConfigValue] to [Config]
        // This is more complex as ConfigValue alone doesn't define the Config structure (title, editorType etc.)
        // The original `Model.config` expects an array of `Config` protocol conformers.
        // The `AllowedModel.config` is a simplified [String: ConfigValue].
        // This implies that the full config structure (sliders, labels etc.) must be predefined
        // for each model type, and this `config` map only overrides the *values*.

        // For now, we'll create an empty `swiftConfigs` array.
        // A more complete implementation would require looking up the base Config structure
        // for the model type and applying these stored ConfigValues.
        // This might involve having a template/default Config array for each model type.
        let swiftConfigs: [Config] = [] // Placeholder

        // A more robust approach would be to have predefined Config structures for each model
        // and then apply the values from `self.config`.
        // For example, if MODEL_TEXT_CLASSIFICATION_MOBILEBERT has a known set of Config objects,
        // we would load them and then update their `value` property using `self.config`.
        // This part is non-trivial and depends on how full Config definitions are managed.

        // Let's assume for now that this conversion might happen at a higher level,
        // or that the `Model` struct itself might need an initializer that can take this simplified config.
        // Or, the `Model` struct's `config` property would be populated post-initialization.

        return Model(
            id: self.id,
            name: self.name,
            overview: self.overview,
            description: self.description,
            publisher: self.publisher,
            license: self.license,
            link: self.link,
            defaultAccelerator: self.defaultAccelerator,
            defaultModelPath: self.defaultModelPath,
            modelPaths: swiftModelPaths,
            modelDataFiles: self.modelDataFiles ?? [],
            config: swiftConfigs, // This is a simplification
            downloadStatus: ModelDownloadStatus(type: .NOT_DOWNLOADED) // Default status
        )
    }
}

// Corresponds to ModelAllowlist in Kotlin
struct ModelAllowlist: Codable, Hashable {
    let version: Int
    let models: [AllowedModel]
}
