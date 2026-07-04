import AppKit
import ScreenCaptureKit
import ServiceManagement

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var peekWindow = PeekWindow()
    private let hotkey = HotkeyListener()
    private var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()

        hotkey.onTrigger = { [weak self] in
            guard let self else { return }
            if self.isShowing {
                self.peekWindow.hidePeek()
                self.isShowing = false
            } else {
                // (Capture and cache screenshot of current workspace FIRST (before picker appears), then show)
                Task { @MainActor in
                    let focused = WindowManager.focusedWorkspace()
                    await WorkspaceCaptureEngine.captureAndCache(workspaceId: focused)
                    self.peekWindow.showPeek()
                    self.isShowing = true
                }
            }
        }
        hotkey.start()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: peekWindow,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing else { return }
            self.peekWindow.hidePeek()
            self.isShowing = false
        }
    }

    private func registerLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .notRegistered {
                try? service.register()
            }
        }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
