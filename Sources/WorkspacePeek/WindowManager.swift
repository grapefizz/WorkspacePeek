import Foundation

// Backend selector so WorkspacePeek can run w either rift or Aerospace.
enum WindowManager {

    static var useRift: Bool {
        let cfg = WorkspacePeekConfig.current.windowManager
        switch cfg.backend.lowercased() {
        case "rift":
            return true
        case "aerospace":
            return false
        default:
            return isProcessRunning(cfg.riftProcessName)
        }
    }

    static func listWorkspaces() -> [Workspace] {
        useRift ? RiftClient.listWorkspaces() : AerospaceClient.listWorkspaces()
    }

    static func focusedWorkspace() -> String {
        useRift ? RiftClient.focusedWorkspace() : AerospaceClient.focusedWorkspace()
    }

    static func switchTo(_ workspace: String) {
        useRift ? RiftClient.switchTo(workspace) : AerospaceClient.switchTo(workspace)
    }

    private static func isProcessRunning(_ name: String) -> Bool {
        let cfg = WorkspacePeekConfig.current.windowManager
        let task = Process()
        task.executableURL = URL(fileURLWithPath: WorkspacePeekConfig.expandPath(cfg.pgrepPath))
        task.arguments = ["-x", name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
