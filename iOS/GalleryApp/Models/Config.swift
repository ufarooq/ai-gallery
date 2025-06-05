import Foundation

// Corresponds to ConfigEditorType in Kotlin
enum ConfigEditorType: String, Codable, CaseIterable, Hashable {
    case NONE, LABEL, NUMBER_SLIDER, BOOLEAN_SWITCH, SEGMENTED_BUTTON
}

// Corresponds to ValueType in Kotlin
enum ValueType: String, Codable, CaseIterable, Hashable {
    case UNKNOWN, INT, FLOAT, BOOLEAN, STRING
}

// Corresponds to Config in Kotlin (protocol for open class behavior)
protocol Config: Codable, Hashable, Identifiable {
    var id: String { get } // Unique identifier for the config item
    var key: ConfigKey { get }
    var title: String { get }
    var valueType: ValueType { get }
    var editorType: ConfigEditorType { get }
    var value: ConfigValue { get set } // Use ConfigValue enum defined elsewhere
}

// Default implementation for id to use the key's rawValue
extension Config {
    var id: String { key.rawValue }
}

// Corresponds to LabelConfig in Kotlin
struct LabelConfig: Config {
    let key: ConfigKey
    let title: String
    // `value` is a String, but represented by ConfigValue
    var value: ConfigValue

    let valueType: ValueType = .STRING
    let editorType: ConfigEditorType = .LABEL

    init(key: ConfigKey, title: String, value: String) {
        self.key = key
        self.title = title
        self.value = .string(value)
    }
}

// Corresponds to NumberSliderConfig in Kotlin
struct NumberSliderConfig: Config {
    let key: ConfigKey
    let title: String
    var value: ConfigValue // Can be .integer or .float
    let minValue: Float
    let maxValue: Float
    let step: Float

    let valueType: ValueType // .INT or .FLOAT
    let editorType: ConfigEditorType = .NUMBER_SLIDER

    // Initializer for Integer slider
    init(key: ConfigKey, title: String, value: Int, minValue: Int, maxValue: Int, step: Int) {
        self.key = key
        self.title = title
        self.value = .integer(value)
        self.minValue = Float(minValue)
        self.maxValue = Float(maxValue)
        self.step = Float(step)
        self.valueType = .INT
    }

    // Initializer for Float slider
    init(key: ConfigKey, title: String, value: Float, minValue: Float, maxValue: Float, step: Float) {
        self.key = key
        self.title = title
        self.value = .float(value)
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.valueType = .FLOAT
    }
}

// Corresponds to BooleanSwitchConfig in Kotlin
struct BooleanSwitchConfig: Config {
    let key: ConfigKey
    let title: String
    var value: ConfigValue // Should be .boolean

    let valueType: ValueType = .BOOLEAN
    let editorType: ConfigEditorType = .BOOLEAN_SWITCH

    init(key: ConfigKey, title: String, value: Bool) {
        self.key = key
        self.title = title
        self.value = .boolean(value)
    }
}

// Corresponds to SegmentedButtonConfig.Option in Kotlin
struct SegmentedButtonOption: Codable, Hashable, Identifiable {
    let id: String // Typically the same as title or a unique key
    let title: String
    let value: ConfigValue // The actual value this option represents

    init(title: String, value: ConfigValue) {
        self.id = title // Or generate a unique ID if title isn't guaranteed unique
        self.title = title
        self.value = value
    }
}

// Corresponds to SegmentedButtonConfig in Kotlin
struct SegmentedButtonConfig: Config {
    let key: ConfigKey
    let title: String
    var value: ConfigValue // The selected option's value
    let options: [SegmentedButtonOption]
    let multiSelect: Bool // Though typical segmented controls are single-select

    let valueType: ValueType // Depends on the options' values, could be INT, STRING, etc.
    let editorType: ConfigEditorType = .SEGMENTED_BUTTON

    init(key: ConfigKey, title: String, initialValue: ConfigValue, options: [SegmentedButtonOption], multiSelect: Bool = false) {
        self.key = key
        self.title = title
        self.value = initialValue
        self.options = options
        self.multiSelect = multiSelect
        // Determine valueType from the first option, assuming all options have the same type
        if let firstOptionValue = options.first?.value {
            switch firstOptionValue {
            case .integer: self.valueType = .INT
            case .float: self.valueType = .FLOAT
            case .boolean: self.valueType = .BOOLEAN
            case .string: self.valueType = .STRING
            }
        } else {
            self.valueType = .UNKNOWN // Should ideally not happen if options are present
        }
    }
}

// Helper to allow direct encoding/decoding of [Config]
// This requires each concrete type to be distinguishable or to use a wrapper.
// For simplicity with Codable, we might need to encode the type or use a wrapper struct
// if dealing with heterogeneous arrays of Config directly.
// However, if `Model.config` is always homogeneous or if we handle serialization carefully,
// direct Codable on the protocol might work with some caveats or by using specific types in Model.

// For now, ensuring each struct is Codable.
// When decoding an array of `Config`, one would typically need to know the concrete type,
// or use a more advanced Codable strategy (e.g., an enum wrapper for different config types).
// The `Model` struct currently has `config: [Config]`. This will be challenging for direct Codable.
// A common solution is to use an enum wrapper for `AnyConfig` that holds different types.
// For now, I'll leave it as is, but this is a point for future refinement for robust Codable support.
// Alternatively, specific model structs could define their config array with concrete types.
// Example: `let config: [NumberSliderConfig]` if a model only uses number sliders.
// If a model uses mixed types, an enum wrapper is the standard Swift Codable approach.
// For example:
/*
enum AnyConfig: Codable, Hashable, Identifiable {
    case label(LabelConfig)
    case numberSlider(NumberSliderConfig)
    case booleanSwitch(BooleanSwitchConfig)
    case segmentedButton(SegmentedButtonConfig)

    var id: String {
        switch self {
        case .label(let c): return c.id
        case .numberSlider(let c): return c.id
        case .booleanSwitch(let c): return c.id
        case .segmentedButton(let c): return c.id
        }
    }

    var key: ConfigKey { /* ... */ }
    // ... other shared properties or forward them ...
    var value: ConfigValue {
        get {
            switch self {
            case .label(let c): return c.value
            // ... other cases
            default: fatalError("Not implemented")
            }
        }
        set {
            switch self {
            case .label(var c): c.value = newValue // This doesn't work directly as c is a copy
            // This part needs careful implementation if mutable access through enum is needed
            default: fatalError("Not implemented")
            }
        }
    }
}
*/
// Then Model would have `config: [AnyConfig]`.
// I will proceed without this AnyConfig wrapper for now to keep the translation direct,
// but acknowledge this Codable challenge.
