import Foundation

/// Errors that ComfyService can surface to the caller.
enum ComfyServiceError: LocalizedError {
    case invalidBaseURL
    case networkError(Error)
    case httpError(Int)
    case generationFailed(String)
    case noOutputImage
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:         return "ComfyUI base URL is invalid. Check Settings."
        case .networkError(let e):    return "ComfyUI network error: \(e.localizedDescription)"
        case .httpError(let code):    return "ComfyUI returned HTTP \(code)."
        case .generationFailed(let m): return "ComfyUI generation failed: \(m)"
        case .noOutputImage:          return "ComfyUI finished but returned no image."
        case .timeout:                return "ComfyUI generation timed out. Is ComfyUI running?"
        }
    }
}

/// Interacts with a local ComfyUI instance to generate images from prompts.
struct ComfyService {
    let baseURL: URL

    // MARK: - Public API

    /// Generates an image for a single panel and returns the PlatformImage.
    func generateImage(
        positive: String,
        negative: String,
        style: StyleMode
    ) async throws -> PlatformImage {
        let workflow = buildWorkflow(positive: positive, negative: negative, style: style)
        let promptID = try await queuePrompt(workflow: workflow)
        let filename = try await pollForCompletion(promptID: promptID)
        return try await downloadImage(filename: filename)
    }

    /// Generates images for all panels in parallel using a TaskGroup.
    func generateImages(
        for panels: [Panel],
        style: StyleMode,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> [PlatformImage?] {
        var results = Array<PlatformImage?>(repeating: nil, count: panels.count)

        try await withThrowingTaskGroup(of: (Int, PlatformImage).self) { group in
            for (index, panel) in panels.enumerated() {
                group.addTask {
                    let image = try await self.generateImage(
                        positive: panel.prompt,
                        negative: panel.negativePrompt,
                        style: style
                    )
                    return (index, image)
                }
            }

            for try await (index, image) in group {
                results[index] = image
                onProgress(index)
            }
        }

        return results
    }

    // MARK: - Workflow Construction

    private func buildWorkflow(
        positive: String,
        negative: String,
        style: StyleMode
    ) -> [String: Any] {
        let checkpoint: String
        let steps: Int
        let cfg: Double

        switch style {
        case .manga:
            checkpoint = "v1-5-pruned-emaonly.ckpt"
            steps = 20
            cfg   = 7.5
        case .color:
            checkpoint = "v1-5-pruned-emaonly.ckpt"
            steps = 25
            cfg   = 7.0
        }

        return [
            "1": [
                "class_type": "CheckpointLoaderSimple",
                "inputs": ["ckpt_name": checkpoint]
            ],
            "2": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": positive,
                    "clip": ["1", 1]
                ]
            ],
            "3": [
                "class_type": "CLIPTextEncode",
                "inputs": [
                    "text": negative,
                    "clip": ["1", 1]
                ]
            ],
            "4": [
                "class_type": "EmptyLatentImage",
                "inputs": [
                    "width": 512,
                    "height": 768,
                    "batch_size": 1
                ]
            ],
            "5": [
                "class_type": "KSampler",
                "inputs": [
                    "seed": Int.random(in: 0 ..< Int.max),
                    "steps": steps,
                    "cfg": cfg,
                    "sampler_name": "euler",
                    "scheduler": "normal",
                    "denoise": 1.0,
                    "model": ["1", 0],
                    "positive": ["2", 0],
                    "negative": ["3", 0],
                    "latent_image": ["4", 0]
                ]
            ],
            "6": [
                "class_type": "VAEDecode",
                "inputs": [
                    "samples": ["5", 0],
                    "vae": ["1", 2]
                ]
            ],
            "7": [
                "class_type": "SaveImage",
                "inputs": [
                    "images": ["6", 0],
                    "filename_prefix": "panelforge"
                ]
            ]
        ]
    }

    // MARK: - ComfyUI API Calls

    private func queuePrompt(workflow: [String: Any]) async throws -> String {
        let url = baseURL.appendingPathComponent("prompt")
        let body: [String: Any] = ["prompt": workflow]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ComfyServiceError.generationFailed("Could not serialise workflow: \(error)")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ComfyServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ComfyServiceError.httpError(http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let promptID = json["prompt_id"] as? String
        else {
            throw ComfyServiceError.generationFailed("No prompt_id in queue response.")
        }

        return promptID
    }

    /// Polls /history/{promptID} until the job finishes, then returns the output filename.
    private func pollForCompletion(promptID: String) async throws -> String {
        let url = baseURL.appendingPathComponent("history/\(promptID)")
        let maxAttempts = 120   // 120 × 1 s = 2 minutes
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            attempts += 1

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(from: url)
            } catch {
                throw ComfyServiceError.networkError(error)
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ComfyServiceError.httpError(http.statusCode)
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let entry = json[promptID] as? [String: Any]
            else {
                // Not in history yet — keep polling.
                continue
            }

            // Check for errors returned by ComfyUI.
            if let error = entry["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ComfyServiceError.generationFailed(message)
            }

            // Look for output images.
            if let outputs = entry["outputs"] as? [String: Any] {
                for (_, nodeOutput) in outputs {
                    if let node = nodeOutput as? [String: Any],
                       let images = node["images"] as? [[String: Any]],
                       let first = images.first,
                       let filename = first["filename"] as? String {
                        return filename
                    }
                }
            }
        }

        throw ComfyServiceError.timeout
    }

    private func downloadImage(filename: String) async throws -> PlatformImage {
        var components = URLComponents(url: baseURL.appendingPathComponent("view"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "filename", value: filename)]
        guard let url = components.url else {
            throw ComfyServiceError.noOutputImage
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ComfyServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ComfyServiceError.httpError(http.statusCode)
        }

        guard let image = PlatformImage(data: data) else {
            throw ComfyServiceError.noOutputImage
        }

        return image
    }
}
