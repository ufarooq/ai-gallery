import Foundation
import SwiftUI // For Color - Note: Consider if Color should be part of the pure model layer.

struct Classification: Identifiable, Hashable, Codable {
    let id: UUID = UUID()
    let label: String
    let score: Float
    let colorHex: String // Storing color as a hex string or name to keep model UI-agnostic

    // If SwiftUI Color is truly needed in the model, it makes it less portable.
    // For now, providing a computed property for SwiftUI Color.
    // Note: This will make the struct not directly Codable if Color itself is not made Codable.
    // For simplicity of Codable, colorHex is better. Let's assume color is for display only.
    var displayColor: Color {
        // Basic hex color parsing, can be expanded
        let hex = colorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Default to black
        }
        return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    // Codable conformance will use id, label, score, colorHex
    // displayColor is not encoded/decoded.
}

struct PromptTemplate: Identifiable, Hashable, Codable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let prompt: String
}

struct Stat: Identifiable, Hashable, Codable {
    let id: String // Using the string itself as id for simplicity, matches Kotlin
    let label: String
    let unit: String
}

struct Histogram: Hashable, Codable {
    let buckets: [Int]
    let maxCount: Int
    let highlightBucketIndex: Int
}
