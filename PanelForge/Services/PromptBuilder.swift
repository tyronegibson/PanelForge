import Foundation

/// Builds positive and negative prompts for a panel given style settings.
struct PromptBuilder {

    private static let mangaStyleTokens  = "manga, ink, black and white, hatching, panel art"
    private static let colorStyleTokens  = "comic book, cel shading, vibrant colors, panel art"

    private static let sharedNegative    = "blurry, low quality, deformed, text, watermark"
    private static let mangaNegativeExtra = "color, colorized"

    // MARK: - Public API

    /// Returns a `(positive, negative)` prompt pair for a panel.
    func build(panel: Panel, style: StyleMode, loras: [LoRAModel]) -> (positive: String, negative: String) {
        let styleTokens: String
        let negativeExtra: String

        switch style {
        case .manga:
            styleTokens   = Self.mangaStyleTokens
            negativeExtra = Self.mangaNegativeExtra
        case .color:
            styleTokens   = Self.colorStyleTokens
            negativeExtra = ""
        }

        let loraTokens = loras.map(\.triggerWord).filter { !$0.isEmpty }.joined(separator: ", ")
        let shotToken  = panel.shotType.promptToken

        var parts: [String] = [styleTokens]
        if !loraTokens.isEmpty { parts.append(loraTokens) }
        parts.append(contentsOf: [shotToken, panel.action, panel.mood])

        let positive = parts.joined(separator: ", ")

        var negativeParts = [Self.sharedNegative]
        if !negativeExtra.isEmpty { negativeParts.append(negativeExtra) }
        let negative = negativeParts.joined(separator: ", ")

        return (positive, negative)
    }
}
