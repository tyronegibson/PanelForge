import XCTest
@testable import PanelForge_macOS

final class ContentPolicyTests: XCTestCase {

    private func panel(_ action: String, mood: String = "calm", characters: [String] = []) -> Panel {
        Panel(prompt: "", negativePrompt: "", shotType: .medium,
              action: action, mood: mood, charactersPresent: characters)
    }

    private func lora(_ trigger: String, name: String = "test") -> LoRAModel {
        LoRAModel(name: name, triggerWord: trigger, filePath: "/tmp/\(name).safetensors")
    }

    // MARK: - Allowed

    func testOrdinaryScenesAreAllowed() {
        let scenes = [
            "Two detectives argue in a rainy alley at night.",
            "A mother kisses her baby goodnight and turns off the lamp.",
            "The kid is asleep in bed while a dragon peeks through the window.",
            "A class of children visits the museum; the teacher points at a dinosaur.",
            "A knight in Sussex sharpens his sword."   // "sex" inside "Sussex" must not match
        ]
        for scene in scenes {
            XCTAssertEqual(ContentPolicy.checkInput(sceneDescription: scene, loras: []), .allow, scene)
        }
    }

    func testRomanceBetweenAdultsIsAllowed() {
        XCTAssertTrue(ContentPolicy.checkInput(
            sceneDescription: "Two adults share a romantic dinner on a rooftop.", loras: []).isAllowed)
    }

    // MARK: - Explicit content

    func testExplicitSceneIsBlocked() {
        let decision = ContentPolicy.checkInput(sceneDescription: "A NUDE figure poses on the bed", loras: [])
        XCTAssertEqual(decision, .block([.explicitContent(source: "the scene description", term: "nude")]))
    }

    func testCaseAndPunctuationDoNotEvadeTheCheck() {
        XCTAssertFalse(ContentPolicy.checkInput(sceneDescription: "NSFW! please", loras: []).isAllowed)
        XCTAssertFalse(ContentPolicy.checkInput(sceneDescription: "style: nsfw, comic", loras: []).isAllowed)
        XCTAssertFalse(ContentPolicy.checkInput(sceneDescription: "Topless-portrait", loras: []).isAllowed)
    }

    func testWholeWordMatching() {
        XCTAssertTrue(ContentPolicy.checkInput(sceneDescription: "A classic glass bottle", loras: []).isAllowed)
        XCTAssertTrue(ContentPolicy.checkInput(sceneDescription: "Essex county fair", loras: []).isAllowed)
    }

    // MARK: - Minors

    func testMinorWithSuggestiveWordingIsBlocked() {
        let decision = ContentPolicy.checkInput(sceneDescription: "a teen girl posing seductively", loras: [])
        guard case .block(let violations) = decision else { return XCTFail("expected block") }
        XCTAssertTrue(violations.contains { if case .minorInSexualContext = $0 { return true }; return false })
    }

    func testMinorWithExplicitTermIsBlockedTwice() {
        guard case .block(let violations) = ContentPolicy.checkInput(
            sceneDescription: "underage character, nsfw", loras: []) else { return XCTFail("expected block") }
        XCTAssertTrue(violations.contains(.explicitContent(source: "the scene description", term: "nsfw")))
        XCTAssertTrue(violations.contains { if case .minorInSexualContext = $0 { return true }; return false })
    }

    func testMinorInSwimwearIsBlockedConservatively() {
        XCTAssertFalse(ContentPolicy.checkInput(
            sceneDescription: "kids in swimsuits at the beach", loras: []).isAllowed)
    }

    // MARK: - LoRA trigger words

    func testExplicitLoRATriggerIsBlockedBeforeClaude() {
        let decision = ContentPolicy.checkInput(
            sceneDescription: "A quiet library scene", loras: [lora("lingerie_style", name: "Wardrobe")])
        // "lingerie_style" normalizes to "lingerie style", so the trigger is caught.
        XCTAssertEqual(decision, .block([.explicitContent(source: "LoRA \"Wardrobe\" trigger words", term: "lingerie")]))
    }

    func testCleanLoRATriggerIsAllowed() {
        XCTAssertTrue(ContentPolicy.checkInput(
            sceneDescription: "A quiet library scene", loras: [lora("inkwash_style")]).isAllowed)
    }

    // MARK: - Panels returned by Claude

    func testPanelsAreCheckedBeforeComfyUI() {
        let panels = [panel("The hero enters the castle"), panel("She undresses by the fire")]
        XCTAssertEqual(ContentPolicy.checkPanels(panels, loras: []),
                       .block([.explicitContent(source: "panel 2", term: "undresses")]))
    }

    func testCharacterNamesAreChecked() {
        let panels = [panel("Waves at the crowd", characters: ["Nude Bandit"])]
        XCTAssertFalse(ContentPolicy.checkPanels(panels, loras: []).isAllowed)
    }

    // MARK: - Prompt builder safety baseline

    func testNegativePromptAlwaysCarriesSafetyTerms() {
        let builder = PromptBuilder()
        for style in StyleMode.allCases {
            let (_, negative) = builder.build(panel: panel("A duel at dawn"), style: style, loras: [])
            XCTAssertTrue(negative.contains("nsfw"), "\(style)")
            XCTAssertTrue(negative.contains("nudity"), "\(style)")
        }
    }
}
