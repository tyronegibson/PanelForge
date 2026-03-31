import Foundation

enum StyleMode: String, CaseIterable, Codable {
    case manga = "B&W Manga"
    case color = "Color Comic"

    var displayName: String { rawValue }
}

enum LayoutTemplate: String, CaseIterable, Codable {
    case two   = "2 Panel"
    case three = "3 Panel Strip"
    case four  = "2×2 Grid"
    case six   = "3×2 Manga Page"

    var panelCount: Int {
        switch self {
        case .two:   return 2
        case .three: return 3
        case .four:  return 4
        case .six:   return 6
        }
    }

    var displayName: String { rawValue }

    /// Canonical grid columns for the layout.
    var columns: Int {
        switch self {
        case .two:   return 1
        case .three: return 3
        case .four:  return 2
        case .six:   return 3
        }
    }
}

enum ShotType: String, CaseIterable, Codable {
    case wide           = "wide"
    case medium         = "medium"
    case closeUp        = "close_up"
    case extremeCloseUp = "extreme_close_up"

    var displayName: String {
        switch self {
        case .wide:           return "Wide"
        case .medium:         return "Medium"
        case .closeUp:        return "Close Up"
        case .extremeCloseUp: return "Extreme Close Up"
        }
    }

    /// Prompt token used when building image prompts.
    var promptToken: String {
        switch self {
        case .wide:           return "wide shot"
        case .medium:         return "medium shot"
        case .closeUp:        return "close-up shot"
        case .extremeCloseUp: return "extreme close-up"
        }
    }
}
