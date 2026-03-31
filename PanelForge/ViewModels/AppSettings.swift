import Foundation
import Combine

/// Observable store for user-configurable settings.
/// The Claude API key is kept in Keychain; all other settings use UserDefaults.
@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Claude

    @Published var claudeAPIKey: String = "" {
        didSet { KeychainService.save(claudeAPIKey, forKey: KeychainService.claudeAPIKeyKey) }
    }

    // MARK: - ComfyUI

    @Published var comfyBaseURLString: String {
        didSet { UserDefaults.standard.set(comfyBaseURLString, forKey: "comfy_base_url") }
    }

    var comfyBaseURL: URL {
        URL(string: comfyBaseURLString) ?? URL(string: "http://localhost:8188")!
    }

    // MARK: - LoRA manager

    @Published var loraModels: [LoRAModel] {
        didSet {
            if let data = try? JSONEncoder().encode(loraModels) {
                UserDefaults.standard.set(data, forKey: "lora_models")
            }
        }
    }

    // MARK: - Init

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "comfy_base_url")
        comfyBaseURLString = savedURL ?? "http://localhost:8188"

        let savedKey = KeychainService.load(forKey: KeychainService.claudeAPIKeyKey) ?? ""
        claudeAPIKey = savedKey

        if let data = UserDefaults.standard.data(forKey: "lora_models"),
           let models = try? JSONDecoder().decode([LoRAModel].self, from: data) {
            loraModels = models
        } else {
            loraModels = []
        }
    }

    // MARK: - LoRA helpers

    func addLoRA(_ model: LoRAModel) {
        loraModels.append(model)
    }

    func deleteLoRA(at offsets: IndexSet) {
        loraModels.remove(atOffsets: offsets)
    }

    func updateLoRA(_ model: LoRAModel) {
        if let idx = loraModels.firstIndex(where: { $0.id == model.id }) {
            loraModels[idx] = model
        }
    }
}
