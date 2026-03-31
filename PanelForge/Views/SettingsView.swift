import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var apiKeyInput   = ""
    @State private var showAPIKey    = false
    @State private var showAddLoRA   = false
    @State private var comfyURLInput = ""

    var body: some View {
        Form {
            // Claude API Key
            Section {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-…", text: $apiKeyInput)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    } else {
                        SecureField("sk-ant-…", text: $apiKeyInput)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Save API Key") {
                    settings.claudeAPIKey = apiKeyInput
                }
                .disabled(apiKeyInput.isEmpty)
            } header: {
                Label("Claude API Key", systemImage: "key")
            } footer: {
                Text("Stored securely in Keychain. Never written to disk in plaintext.")
            }

            // ComfyUI URL
            Section {
                TextField("http://localhost:8188", text: $comfyURLInput)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif

                Button("Save URL") {
                    settings.comfyBaseURLString = comfyURLInput
                }
                .disabled(comfyURLInput.isEmpty)
            } header: {
                Label("ComfyUI", systemImage: "network")
            } footer: {
                Text("ComfyUI must be running locally. Default: http://localhost:8188")
            }

            // LoRA Manager
            Section {
                ForEach(settings.loraModels) { model in
                    NavigationLink {
                        LoRAEditView(model: model)
                            .environmentObject(settings)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name).font(.subheadline)
                            Text(model.triggerWord).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: settings.deleteLoRA)

                Button {
                    showAddLoRA = true
                } label: {
                    Label("Add LoRA", systemImage: "plus.circle")
                }
            } header: {
                Label("LoRA Models", systemImage: "person.crop.circle.badge.plus")
            } footer: {
                Text("LoRAs are injected into prompts using their trigger word.")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKeyInput   = settings.claudeAPIKey.isEmpty ? "" : String(repeating: "•", count: 12)
            comfyURLInput = settings.comfyBaseURLString
        }
        .sheet(isPresented: $showAddLoRA) {
            LoRAAddView()
                .environmentObject(settings)
        }
        #if os(iOS)
        .toolbar {
            EditButton()
        }
        #endif
    }
}

// MARK: - LoRA Add/Edit views

struct LoRAAddView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var triggerWord = ""
    @State private var filePath    = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Model name", text: $name)
                    TextField("Trigger word", text: $triggerWord)
                    TextField("File path (on ComfyUI host)", text: $filePath)
                }
            }
            .navigationTitle("Add LoRA")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let model = LoRAModel(name: name, triggerWord: triggerWord, filePath: filePath)
                        settings.addLoRA(model)
                        dismiss()
                    }
                    .disabled(name.isEmpty || triggerWord.isEmpty)
                }
            }
        }
    }
}

struct LoRAEditView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let model: LoRAModel
    @State private var name        = ""
    @State private var triggerWord = ""
    @State private var filePath    = ""

    var body: some View {
        Form {
            Section("Details") {
                TextField("Model name", text: $name)
                TextField("Trigger word", text: $triggerWord)
                TextField("File path", text: $filePath)
            }
        }
        .navigationTitle("Edit LoRA")
        .onAppear {
            name        = model.name
            triggerWord = model.triggerWord
            filePath    = model.filePath
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updated       = model
                    updated.name        = name
                    updated.triggerWord = triggerWord
                    updated.filePath    = filePath
                    settings.updateLoRA(updated)
                    dismiss()
                }
                .disabled(name.isEmpty || triggerWord.isEmpty)
            }
        }
    }
}
