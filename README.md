# Panel Forge

A native SwiftUI app (macOS 14+ / iOS 17+) that turns a scene description into a multi-panel comic page.

**Stack:** Swift, SwiftUI, Claude API (scene parsing), ComfyUI (image generation), CoreGraphics (page composition).

```
scene text ──► ContentPolicy (input) ──► Claude: scene → panels (or refusal)
                                              │
                         ContentPolicy (panels + LoRA triggers)
                                              │
                    PromptBuilder (style + LoRA + safety negatives) ──► ComfyUI ──► page
```

---

## Content safety

Image models will render whatever the prompt describes, and LoRAs can pull output in directions the user never typed. PanelForge stays safe for work with three independent layers, so a failure in one doesn't open the door:

1. **A deterministic policy check, run twice** (`Services/ContentPolicy.swift`).
   - *Before Claude:* the scene description and every selected LoRA trigger word.
   - *Before ComfyUI:* every panel Claude returns (action, mood, character names) and the LoRA triggers again.
   - Explicit terms block on their own. Words referring to children or minors are fine on their own (comics have kids in them), but they block when they appear with any explicit or suggestive wording. That rule is deliberately conservative: "kids in swimsuits" is blocked too.
   - Matching is whole-word and ignores case, accents and punctuation, so "NSFW!" and `lingerie_style` are caught while "Sussex" and "classic" are not.
   - A blocked request shows the reason and generates nothing.
2. **Instructions to Claude** (`Services/ClaudeService.swift`). The scene director must keep every panel SFW, never depict a minor in a sexual, romantic or suggestive way, and refuse rather than soften. It answers in a JSON envelope with a `refused` flag and a reason, and the app surfaces the refusal.
3. **A safety baseline in every negative prompt** (`Services/PromptBuilder.swift`). Terms like `nsfw, nudity, explicit, sexual content` are always appended and can't be removed from the UI.

The policy layer has 13 unit tests (`PanelForgeTests/ContentPolicyTests.swift`, all passing on macOS via `xcodebuild test`) covering ordinary scenes that must pass, explicit scenes that must block, minors with suggestive wording, LoRA triggers, panels returned by the model, and false positives like "Sussex".

**Known limits:** keyword lists catch clear cases, not euphemisms or other languages, and nothing here inspects the generated pixels. The next step would be an on-device image classifier on each panel before it is saved.

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
# 1 — Generate the Xcode project (it is not committed)
brew install xcodegen
xcodegen generate
open PanelForge.xcodeproj

# 2 — Select scheme: PanelForge_macOS  or  PanelForge_iOS
# 3 — Build & Run (⌘R); run tests with ⌘U on PanelForge_macOS
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

1. Start ComfyUI bound to this machine only: `python main.py --listen 127.0.0.1 --port 8188`. Don't use `0.0.0.0`, which exposes ComfyUI to everyone on your network.
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
├── Services/        # ClaudeService, ComfyService, ContentPolicy, PromptBuilder, ImageExporter, KeychainService
├── ViewModels/      # GeneratorViewModel, AppSettings, LibraryStore
├── Views/           # ContentView, GenerateView, PanelGridView, LibraryView, SettingsView
PanelForgeTests/     # ContentPolicy unit tests
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

- **How it was built:** the first version was built with Claude Code in one session, in seven planned phases (the commit history shows them landing together). The content-safety layer and its tests were added afterwards, after a review found the app had no SFW guardrails.

- **No third-party dependencies** — only Apple frameworks (SwiftUI, CoreGraphics, Security, Foundation).
- **Not sandboxed on macOS** (personal use). The entitlements file enables unrestricted network client access and user-selected file read/write.
- ComfyUI workflow uses a basic SD 1.5 node graph. Swap in your preferred checkpoint by editing `ComfyService.buildWorkflow()`.
