import Foundation

/// Why a request was blocked. Shown to the user instead of generating.
enum PolicyViolation: Equatable, CustomStringConvertible {
    /// Sexual or explicit content in the scene, a panel, or a LoRA trigger.
    case explicitContent(source: String, term: String)
    /// A minor appears together with sexualized or suggestive wording.
    case minorInSexualContext(source: String, minorTerm: String, term: String)
    /// Claude declined to break the scene into panels.
    case refusedByModel(reason: String)

    var description: String {
        switch self {
        case .explicitContent(let source, let term):
            return "Blocked: explicit content (\"\(term)\") in \(source)."
        case .minorInSexualContext(let source, let minorTerm, let term):
            return "Blocked: \"\(minorTerm)\" appears with suggestive wording (\"\(term)\") in \(source)."
        case .refusedByModel(let reason):
            return "Blocked by the scene director: \(reason)"
        }
    }
}

/// Result of a policy check.
enum PolicyDecision: Equatable {
    case allow
    case block([PolicyViolation])

    var isAllowed: Bool { self == .allow }
}

/// A deterministic, offline content policy for PanelForge.
///
/// It runs twice per generation:
/// 1. **Before Claude**, on the user's scene description and the selected LoRA trigger words.
/// 2. **Before ComfyUI**, on every panel Claude returns, plus the LoRA trigger words again.
///
/// Matching is case-insensitive and whole-word, so "class" never matches "ass"
/// and "Sussex" never matches "sex". The lists are deliberately short and
/// conservative: this layer catches clear cases cheaply and predictably, and the
/// model-side instructions in `ClaudeService` handle nuance. Neither replaces
/// the other.
struct ContentPolicy {

    /// Terms that block generation on their own.
    static let explicitTerms: [String] = [
        "nsfw", "nude", "nudes", "nudity", "naked", "topless", "bottomless",
        "porn", "porno", "pornographic", "hentai", "ecchi", "explicit",
        "sex", "sexual", "sexy", "erotic", "erotica", "fetish", "bdsm",
        "orgasm", "genitals", "genitalia", "nipples", "lingerie", "undress", "undresses",
        "undressed", "undressing", "striptease", "stripper", "xxx", "lewd", "r18", "r-18"
    ]

    /// Words that refer to children or minors. Allowed on their own (comics have kids in them),
    /// but blocked when they appear with any explicit or suggestive term.
    static let minorTerms: [String] = [
        "child", "children", "kid", "kids", "minor", "minors", "underage",
        "teen", "teens", "teenager", "teenage", "preteen", "schoolgirl", "schoolboy",
        "loli", "lolicon", "shota", "shotacon", "toddler", "baby", "infant",
        "boy", "girl", "little girl", "little boy", "young girl", "young boy",
        "middle school", "elementary school", "high school student"
    ]

    /// Wording that is acceptable in general but not alongside a minor.
    /// Deliberately conservative: "kids in swimsuits at the beach" is blocked too,
    /// because swimwear plus minors is a known misuse pattern for image models.
    /// Everyday words like "kiss", "bed" and "date" are left out so that
    /// "a mother kisses her baby" or "the kid is asleep in bed" still work.
    static let suggestiveTerms: [String] = [
        "seductive", "seductively", "sensual", "provocative", "suggestive",
        "bikini", "bikinis", "swimsuit", "swimsuits", "swimwear", "underwear", "panties", "bra", "cleavage",
        "intimate", "flirting", "flirty", "romantic", "romance", "dating",
        "lover", "lovers", "makeout", "make out"
    ]

    // MARK: - Public API

    /// Checks the user's scene description and LoRA trigger words before anything is sent to Claude.
    static func checkInput(sceneDescription: String, loras: [LoRAModel]) -> PolicyDecision {
        var violations = violations(in: sceneDescription, source: "the scene description")
        for lora in loras {
            violations += Self.violations(in: lora.triggerWord, source: "LoRA \"\(lora.name)\" trigger words")
        }
        return violations.isEmpty ? .allow : .block(violations)
    }

    /// Checks Claude's panels and the LoRA trigger words before anything is sent to ComfyUI.
    static func checkPanels(_ panels: [Panel], loras: [LoRAModel]) -> PolicyDecision {
        var violations: [PolicyViolation] = []
        for (index, panel) in panels.enumerated() {
            let text = ([panel.action, panel.mood] + panel.charactersPresent).joined(separator: " ")
            violations += Self.violations(in: text, source: "panel \(index + 1)")
        }
        for lora in loras {
            violations += Self.violations(in: lora.triggerWord, source: "LoRA \"\(lora.name)\" trigger words")
        }
        return violations.isEmpty ? .allow : .block(violations)
    }

    /// All violations found in a piece of text.
    static func violations(in text: String, source: String) -> [PolicyViolation] {
        let normalized = normalize(text)
        var found: [PolicyViolation] = []

        let explicitHits = explicitTerms.filter { contains(normalized, phrase: $0) }
        for term in explicitHits {
            found.append(.explicitContent(source: source, term: term))
        }

        if let minor = minorTerms.first(where: { contains(normalized, phrase: $0) }) {
            let sexualizing = explicitHits + suggestiveTerms.filter { contains(normalized, phrase: $0) }
            if let term = sexualizing.first {
                found.append(.minorInSexualContext(source: source, minorTerm: minor, term: term))
            }
        }
        return found
    }

    // MARK: - Matching

    /// Lowercases, folds accents, and turns every non-alphanumeric run into a single space,
    /// so "N.S.F.W", "nude!" and "Nude" all normalize predictably.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .init(identifier: "en_US"))
        var out = ""
        var lastWasSpace = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(" ")
                lastWasSpace = true
            }
        }
        return " " + out.trimmingCharacters(in: .whitespaces) + " "
    }

    /// Whole-word (or whole-phrase) match against normalized text.
    static func contains(_ normalizedText: String, phrase: String) -> Bool {
        let needle = normalize(phrase)   // already padded with spaces on both sides
        return normalizedText.contains(needle)
    }
}
