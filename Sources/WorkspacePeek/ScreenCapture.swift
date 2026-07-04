import ScreenCaptureKit
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

final class WorkspaceCaptureEngine {

    static let cacheDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".cache/workspacepeek")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // (Capture current screen and cache for the given workspace ID)
    static func captureAndCache(workspaceId: String) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }

            let config = SCStreamConfiguration()
            config.width = Int(display.width / 3)
            config.height = Int(display.height / 3)
            config.showsCursor = false
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
            print("WorkspacePeek capture error: \(error)")
        }
    }

    static func loadCached(workspaceId: String) -> CGImage? {
        let url = cacheDirectory.appendingPathComponent("\(workspaceId).png")
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
