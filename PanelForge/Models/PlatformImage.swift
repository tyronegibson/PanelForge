/// Cross-platform image type alias.
/// All platform-specific image handling is isolated here so that
/// the rest of the codebase uses PlatformImage uniformly.
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
