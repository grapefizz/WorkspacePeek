import ScreenCaptureKit
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

final class WorkspaceCaptureEngine {

    static var cacheDirectory: URL {
        let cfg = WorkspacePeekConfig.current
        let dir = WorkspacePeekConfig.url(forConfiguredPath: cfg.paths.screenshotCacheDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // (Capture current screen and cache for the given workspace ID)
    static func captureAndCache(workspaceId: String) async {
        do {
            let cfg = WorkspacePeekConfig.current
            let capture = cfg.capture
            let content = try await SCShareableContent.excludingDesktopWindows(
                capture.excludingDesktopWindows,
                onScreenWindowsOnly: capture.onScreenWindowsOnly
            )
            guard !content.displays.isEmpty else { return }
            let index = min(max(capture.displayIndex, 0), content.displays.count - 1)
            let display = content.displays[index]
            let scaleDivisor = max(capture.imageScaleDivisor, 1)

            let config = SCStreamConfiguration()
            config.width = Int(Double(display.width) / scaleDivisor)
            config.height = Int(Double(display.height) / scaleDivisor)
            config.showsCursor = capture.showsCursor
            config.captureResolution = .nominal
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let url = cacheDirectory.appendingPathComponent("\(workspaceId).png")
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, image, nil)
                CGImageDestinationFinalize(dest)
            }
        } catch {
            let cfg = WorkspacePeekConfig.current
            print("\(cfg.logging.prefix) capture error: \(error)")
        }
    }

    static func loadCached(workspaceId: String) -> CGImage? {
        let url = cacheDirectory.appendingPathComponent("\(workspaceId).png")
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
