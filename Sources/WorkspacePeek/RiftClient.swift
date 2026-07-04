import Foundation

//rift-cli based client, equivalent of AerospaceClient except for rift 
final class RiftClient {

    static let binaryPath: String? = {
        let candidates = ["/opt/homebrew/bin/rift-cli", "/usr/local/bin/rift-cli"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }()

    private static func queryWorkspaces() -> [[String: Any]] {
        let out = run(args: ["query", "workspaces"])
        guard let data = out.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr
    }

    static func listWorkspaces() -> [Workspace] {
        return queryWorkspaces().compactMap { ws -> Workspace? in
            guard let name = ws["name"] as? String else { return nil }
            let count = (ws["window_count"] as? Int) ?? 0
            guard count > 0 else { return nil }
            let isFocused = (ws["is_active"] as? Bool) ?? false
            let windows = (ws["windows"] as? [[String: Any]]) ?? []
            let apps = windows
                .sorted { frameOrigin($0) < frameOrigin($1) }
                .compactMap { $0["app_name"] as? String }
            return Workspace(id: name, isFocused: isFocused, appNames: apps)
        }
    }

    private static func frameOrigin(_ win: [String: Any]) -> (Double, Double) {
        let origin = (win["frame"] as? [String: Any])?["origin"] as? [String: Any]
        let x = (origin?["x"] as? NSNumber)?.doubleValue ?? 0
        let y = (origin?["y"] as? NSNumber)?.doubleValue ?? 0
        return (x, y)
    }

    static func focusedWorkspace() -> String {
        for ws in queryWorkspaces() where (ws["is_active"] as? Bool) ?? false {
            return (ws["name"] as? String) ?? ""
        }
        return ""
    }

    static func switchTo(_ workspace: String) {
        var index: Int? = nil
        for ws in queryWorkspaces() where (ws["name"] as? String) == workspace {
            index = ws["index"] as? Int
            break
        }
        if index == nil, let n = Int(workspace) { index = n - 1 }
        guard let idx = index else { return }
        _ = run(args: ["execute", "workspace", "switch", String(idx)])
    }

    @discardableResult
    private static func run(args: [String]) -> String {
        guard let path = binaryPath else { return "" }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
