import Foundation

/// A saved LoRA model that can be selected during generation.
struct LoRAModel: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var triggerWord: String
    var filePath: String
}
