import Foundation

@MainActor
final class GeneratorViewModel: ObservableObject {

    // MARK: - Published State

    @Published var panels: [Panel] = []
    @Published var phase: Phase = .idle
    @Published var errorMessage: String?

    enum Phase: Equatable {
        case idle
        case parsingScene
        case generatingPanels(completed: Int, total: Int)
        case complete
        case failed

        var isActive: Bool {
            switch self {
            case .parsingScene, .generatingPanels: return true
            default: return false
            }
        }
    }

    // MARK: - Dependencies

    private let claude  = ClaudeService()
    private let builder = PromptBuilder()
    private let exporter = ImageExporter()

    // MARK: - Public API

    func generate(scene: ComicScene) async {
        guard !phase.isActive else { return }
        errorMessage = nil

        // 0. Policy check on the user's input before anything leaves the device.
        if case .block(let violations) = ContentPolicy.checkInput(
            sceneDescription: scene.description, loras: scene.selectedLoRAs) {
            fail(Self.message(for: violations))
            return
        }

        phase = .parsingScene

        // 1. Ask Claude to parse the scene.
        let rawPanels: [Panel]
        do {
            rawPanels = try await claude.parseScene(scene.description)
        } catch {
            fail(error.localizedDescription)
            return
        }

        // 1b. Policy check on Claude's panels before anything is sent to ComfyUI.
        if case .block(let violations) = ContentPolicy.checkPanels(rawPanels, loras: scene.selectedLoRAs) {
            fail(Self.message(for: violations))
            return
        }

        // 2. Build prompts for each panel.
        panels = rawPanels.map { raw in
            var p = raw
            let (pos, neg) = builder.build(panel: raw, style: scene.styleMode, loras: scene.selectedLoRAs)
            p.prompt         = pos
            p.negativePrompt = neg
            p.state          = .pending
            return p
        }

        // Trim or pad panel count to match the chosen layout.
        let target = scene.layout.panelCount
        if panels.count > target { panels = Array(panels.prefix(target)) }

        phase = .generatingPanels(completed: 0, total: panels.count)

        // 3. Generate images via ComfyUI in parallel.
        let comfy = ComfyService(baseURL: scene.comfyBaseURL)
        var completedCount = 0

        await withTaskGroup(of: (Int, PlatformImage?).self) { group in
            for (index, panel) in panels.enumerated() {
                group.addTask {
                    do {
                        let image = try await comfy.generateImage(
                            positive: panel.prompt,
                            negative: panel.negativePrompt,
                            style: scene.styleMode
                        )
                        return (index, image)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            for await (index, image) in group {
                completedCount += 1
                panels[index].image = image
                panels[index].state = image != nil ? .complete : .failed("Generation failed")
                phase = .generatingPanels(completed: completedCount, total: panels.count)
            }
        }

        phase = .complete
    }

    func reset() {
        panels = []
        phase  = .idle
        errorMessage = nil
    }

    // MARK: - Private

    private static func message(for violations: [PolicyViolation]) -> String {
        violations.map(\.description).joined(separator: "\n")
    }

    private func fail(_ message: String) {
        errorMessage = message
        phase = .failed
    }
}

// MARK: - ComicScene + comfyBaseURL helper

extension ComicScene {
    var comfyBaseURL: URL {
        URL(string: "http://localhost:8188")!
    }
}
