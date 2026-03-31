import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Composites panel images into a page and handles export.
struct ImageExporter {

    // MARK: - Types

    struct ExportResult {
        let pageImage: PlatformImage
        let panelImages: [PlatformImage]
    }

    enum ExportError: LocalizedError {
        case noImages
        case renderFailed
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noImages:           return "No images to export."
            case .renderFailed:       return "Failed to render the page image."
            case .saveFailed(let e):  return "Failed to save file: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Public API

    /// Composites all panel images into a single page image using CoreGraphics.
    func compositePage(panels: [Panel], layout: LayoutTemplate) throws -> PlatformImage {
        let validImages = panels.compactMap(\.image)
        guard !validImages.isEmpty else { throw ExportError.noImages }

        let pageSize = CGSize(width: 1240, height: 1754)  // A4 at 150dpi
        let padding: CGFloat = 16
        let rects = layoutRects(for: layout, in: pageSize, padding: padding)

        return try renderImage(size: pageSize) { ctx in
            // Background
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            for (i, rect) in rects.enumerated() {
                guard i < validImages.count else { break }
                let img = validImages[i]
                if let cgImage = img.cgImageRepresentation() {
                    ctx.draw(cgImage, in: rect)
                    // Panel border
                    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
                    ctx.setLineWidth(2)
                    ctx.stroke(rect)
                }
            }
        }
    }

    /// Saves the composited page image as a PNG to the given URL.
    func savePage(_ image: PlatformImage, to url: URL) throws {
        guard let data = image.pngData() else { throw ExportError.renderFailed }
        do {
            try data.write(to: url)
        } catch {
            throw ExportError.saveFailed(error)
        }
    }

    /// Saves all panel images as individual PNGs under a timestamped folder.
    /// Returns the directory URL containing the saved files.
    @discardableResult
    func savePanels(_ panels: [Panel], named prefix: String) throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PanelForge/Exports/\(prefix)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for (i, panel) in panels.enumerated() {
            guard let img = panel.image, let data = img.pngData() else { continue }
            let url = dir.appendingPathComponent("panel_\(i + 1).png")
            try data.write(to: url)
        }

        return dir
    }

    // MARK: - Layout Math

    private func layoutRects(for layout: LayoutTemplate, in size: CGSize, padding: CGFloat) -> [CGRect] {
        let inner = CGRect(
            x: padding, y: padding,
            width:  size.width  - padding * 2,
            height: size.height - padding * 2
        )

        switch layout {
        case .two:
            let h = (inner.height - padding) / 2
            return [
                CGRect(x: inner.minX, y: inner.minY,         width: inner.width, height: h),
                CGRect(x: inner.minX, y: inner.minY + h + padding, width: inner.width, height: h)
            ]
        case .three:
            let w = (inner.width - padding * 2) / 3
            return (0..<3).map { col in
                CGRect(x: inner.minX + CGFloat(col) * (w + padding), y: inner.minY,
                       width: w, height: inner.height)
            }
        case .four:
            let w = (inner.width  - padding) / 2
            let h = (inner.height - padding) / 2
            return [
                CGRect(x: inner.minX,         y: inner.minY,         width: w, height: h),
                CGRect(x: inner.minX + w + padding, y: inner.minY,   width: w, height: h),
                CGRect(x: inner.minX,         y: inner.minY + h + padding, width: w, height: h),
                CGRect(x: inner.minX + w + padding, y: inner.minY + h + padding, width: w, height: h)
            ]
        case .six:
            let w = (inner.width  - padding * 2) / 3
            let h = (inner.height - padding)     / 2
            var rects: [CGRect] = []
            for row in 0..<2 {
                for col in 0..<3 {
                    rects.append(CGRect(
                        x: inner.minX + CGFloat(col) * (w + padding),
                        y: inner.minY + CGFloat(row) * (h + padding),
                        width: w, height: h
                    ))
                }
            }
            return rects
        }
    }

    // MARK: - CoreGraphics Render Helpers

    private func renderImage(size: CGSize, draw: (CGContext) -> Void) throws -> PlatformImage {
        let scale: CGFloat = 1
        let w = Int(size.width  * scale)
        let h = Int(size.height * scale)

        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ExportError.renderFailed }

        ctx.scaleBy(x: scale, y: scale)
        draw(ctx)

        guard let cgImage = ctx.makeImage() else { throw ExportError.renderFailed }
        return PlatformImage.from(cgImage: cgImage, size: size)
    }
}

// MARK: - PlatformImage helpers

private extension PlatformImage {
    func pngData() -> Data? {
        #if os(macOS)
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return self.pngData()
        #endif
    }

    func cgImageRepresentation() -> CGImage? {
        #if os(macOS)
        var rect = CGRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return self.cgImage
        #endif
    }

    static func from(cgImage: CGImage, size: CGSize) -> PlatformImage {
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}
