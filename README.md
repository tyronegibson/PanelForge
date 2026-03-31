# Panel Forge

A native SwiftUI app (macOS 14+ / iOS 17+) that turns a scene description into a multi-panel comic page.

**Stack:** Swift, SwiftUI, Claude API (scene parsing), ComfyUI (image generation), CoreGraphics (page composition).

---

## Requirements

| Dependency | Where |
|---|---|
| Xcode 16+ | Mac App Store |
| ComfyUI | Running locally at `http://localhost:8188` (configurable) |
| Claude API key | `https://console.anthropic.com` |

---

## Quick Start

```bash
# 1 — Clone / open project
open ~/Developer/PanelForge/PanelForge.xcodeproj

# 2 — Select scheme: PanelForge_macOS  or  PanelForge_iOS
# 3 — Build & Run (⌘R)
```

---

## Configuring the Claude API Key

The key is stored in the macOS/iOS **Keychain** — never written to disk in plaintext.

1. Launch the app.
2. Go to **Settings** (gear icon / sidebar item).
3. Paste your key (`sk-ant-api03-…`) into the **Claude API Key** field.
4. Tap **Save API Key**.

Alternatively, set the environment variable `CLAUDE_API_KEY` in the Xcode scheme's *Run → Arguments → Environment Variables* (for local development only — not persisted to Keychain this way).

---

## Configuring ComfyUI

1. Start ComfyUI: `python main.py --listen 0.0.0.0 --port 8188`
2. In Panel Forge → Settings, confirm the URL is `http://localhost:8188` (or update if different).
3. The app expects a standard SD 1.5 checkpoint (`v1-5-pruned-emaonly.ckpt`) accessible from ComfyUI's model directory. Update `ComfyService.buildWorkflow()` to change the checkpoint name.

---

## Adding LoRA Models

1. Settings → **LoRA Models** → **Add LoRA**.
2. Enter: model name, trigger word(s), and the file path on the ComfyUI host.
3. Select the LoRA(s) in the **Generate** view before generating.

---

## Project Structure

```
PanelForge/
├── Models/          # ComicScene, Panel, LoRAModel, GeneratedPage, enums
├── Services/        # ClaudeService, ComfyService, PromptBuilder, ImageExporter, KeychainService
├── ViewModels/      # GeneratorViewModel, AppSettings, LibraryStore
└── Views/           # ContentView, GenerateView, PanelGridView, LibraryView, SettingsView
```

Business logic in `Services/` is 100% platform-agnostic. Platform-specific UI differences are handled with `#if os(macOS)` / `#if os(iOS)` guards in `Views/` and `ViewModels/`.

---

## Regenerating the Xcode Project

```bash
cd ~/Developer/PanelForge
xcodegen generate
```

---

## Notes

- **No third-party dependencies** — only Apple frameworks (SwiftUI, CoreGraphics, Security, Foundation).
- **Not sandboxed on macOS** (personal use). The entitlements file enables unrestricted network client access and user-selected file read/write.
- ComfyUI workflow uses a basic SD 1.5 node graph. Swap in your preferred checkpoint by editing `ComfyService.buildWorkflow()`.
