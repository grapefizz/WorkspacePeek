import Foundation
import AppKit
import CoreImage

struct Workspace: Identifiable, Equatable {
    let id: String
    let isFocused: Bool
    let appNames: [String]   // app names on this workspace, for icons

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id && lhs.isFocused == rhs.isFocused && lhs.appNames == rhs.appNames
    }
}

final class AerospaceClient {

    static var binaryPath: String? {
        WorkspacePeekConfig.current.windowManager.aerospaceBinaryCandidates
            .map(WorkspacePeekConfig.expandPath)
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    static func listWorkspaces() -> [Workspace] {
        let cfg = WorkspacePeekConfig.current.windowManager
        let focus = focusedWorkspace()

        let all = run(args: cfg.aerospaceListWorkspacesArguments)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let windowOutput = run(args: cfg.aerospaceListWindowsArguments)
        var appsByWorkspace: [String: [String]] = [:]
        for line in windowOutput.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: cfg.aerospaceWindowSeparator)
            guard parts.count == 2 else { continue }
            let ws = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let app = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ws.isEmpty, !app.isEmpty else { continue }
            appsByWorkspace[ws, default: []].append(app)
        }

        return all
            .filter { cfg.includeEmptyWorkspaces || appsByWorkspace[$0] != nil }
            .map { wsId in
                Workspace(id: wsId, isFocused: wsId == focus, appNames: appsByWorkspace[wsId] ?? [])
            }
    }

    static func focusedWorkspace() -> String {
        let cfg = WorkspacePeekConfig.current.windowManager
        return run(args: cfg.aerospaceFocusedWorkspaceArguments)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func switchTo(_ workspace: String) {
        let cfg = WorkspacePeekConfig.current.windowManager
        _ = run(args: cfg.aerospaceSwitchWorkspaceArguments.replacingPlaceholders(["workspace": workspace]))
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

// (Maps app names to Nerd Font glyphs to match sketchybar icons)
enum AppGlyphMap {
    static func glyph(for appName: String) -> String {
        let cfg = WorkspacePeekConfig.current.glyphs
        return cfg.appGlyphs[appName] ?? cfg.defaultGlyph
    }
}
