import Foundation

// Corresponds to ConfigValue in Kotlin
enum ConfigValue: Codable, Hashable {
    case integer(Int)
    case float(Float)
    case boolean(Bool)
    case string(String)

    // Initializers to make creation easier
    init(_ value: Int) { self = .integer(value) }
    init(_ value: Float) { self = .float(value) }
    init(_ value: Bool) { self = .boolean(value) }
    init(_ value: String) { self = .string(value) }

    // Codable conformance: Swift can synthesize this for enums with associated values
    // if the associated values are Codable. Int, Float, Bool, String are all Codable.
}

// Helper functions (can be global or extensions on a relevant type, e.g., Array<Config>)

// Global helper functions (alternative to methods on Model)
func getIntConfigValue(from configs: [Config], forKey key: ConfigKey, defaultValue: Int? = nil) -> Int? {
    if let configItem = configs.first(where: { $0.key == key }) {
        if case .integer(let value) = configItem.value {
            return value
        }
    }
    return defaultValue
}

func getFloatConfigValue(from configs: [Config], forKey key: ConfigKey, defaultValue: Float? = nil) -> Float? {
    if let configItem = configs.first(where: { $0.key == key }) {
        if case .float(let value) = configItem.value {
            return value
        }
    }
    return defaultValue
}

func getStringConfigValue(from configs: [Config], forKey key: ConfigKey, defaultValue: String? = nil) -> String? {
    if let configItem = configs.first(where: { $0.key == key }) {
        if case .string(let value) = configItem.value {
            return value
        }
    }
    return defaultValue
}

func getBooleanConfigValue(from configs: [Config], forKey key: ConfigKey, defaultValue: Bool? = nil) -> Bool? {
    if let configItem = configs.first(where: { $0.key == key }) {
        if case .boolean(let value) = configItem.value {
            return value
        }
    }
    return defaultValue
}
