import Foundation

/// Builds positive and negative prompts for a panel given style settings.
struct PromptBuilder {

    private static let mangaStyleTokens  = "manga, ink, black and white, hatching, panel art"
    private static let colorStyleTokens  = "comic book, cel shading, vibrant colors, panel art"

    /// Quality terms plus a safety baseline. The safety terms are always present and cannot be
    /// removed from the UI; they steer the image model away from explicit output even when a
    /// LoRA or prompt pushes toward it. (The hard block lives in `ContentPolicy`.)
    static let qualityNegative   = "blurry, low quality, deformed, text, watermark"
    static let safetyNegative    = "nsfw, nudity, nude, naked, explicit, sexual content, suggestive, cleavage, underwear"
    private static let sharedNegative = qualityNegative + ", " + safetyNegative
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
