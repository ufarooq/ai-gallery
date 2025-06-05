import Foundation
// import SwiftUI // For @ViewBuilder content if icon was a view

// Corresponds to AppBarActionType in Kotlin
enum AppBarActionType: String, CaseIterable, Identifiable {
    case INFO, SETTINGS, MODEL_DOWNLOAD, MODEL_DELETE, BENCHMARK_INFO, ADD_TO_ALLOWLIST, SHARE_RESULT

    var id: String { self.rawValue }

    // SF Symbol names for icons (examples)
    var iconName: String {
        switch self {
        case .INFO:
            return "info.circle"
        case .SETTINGS:
            return "gear"
        case .MODEL_DOWNLOAD:
            return "arrow.down.circle"
        case .MODEL_DELETE:
            return "trash"
        case .BENCHMARK_INFO:
            return "timer" // Or "chart.bar"
        case .ADD_TO_ALLOWLIST:
            return "plus.circle.fill" // Or "list.star"
        case .SHARE_RESULT:
            return "square.and.arrow.up"
        }
    }
}

// Corresponds to AppBarAction in Kotlin
struct AppBarAction: Identifiable {
    let id: AppBarActionType // Use the type itself as ID if actions are unique per type
    let type: AppBarActionType
    let title: String // For accessibility or labels if needed
    // let icon: @Composable () -> Unit, // In Kotlin, this is a Composable. In SwiftUI, could be `Image` or `AnyView`
    // For simplicity, we can use the iconName from AppBarActionType and construct the Image in the View.
    let actionFn: () -> Void

    init(type: AppBarActionType, title: String, actionFn: @escaping () -> Void) {
        self.id = type
        self.type = type
        self.title = title
        self.actionFn = actionFn
    }
}
