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

    static let binaryPath: String? = {
        let candidates = ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace", "/usr/bin/aerospace"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }()

    static func listWorkspaces() -> [Workspace] {
        let focus = focusedWorkspace()

        let all = run(args: ["list-workspaces", "--all"])
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let windowOutput = run(args: ["list-windows", "--all", "--format", "%{workspace}|%{app-name}"])
        var appsByWorkspace: [String: [String]] = [:]
        for line in windowOutput.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "|")
            guard parts.count == 2 else { continue }
            let ws = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let app = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ws.isEmpty, !app.isEmpty else { continue }
            appsByWorkspace[ws, default: []].append(app)
        }

        return all
            .filter { appsByWorkspace[$0] != nil }
            .map { wsId in
                Workspace(id: wsId, isFocused: wsId == focus, appNames: appsByWorkspace[wsId] ?? [])
            }
    }

    static func focusedWorkspace() -> String {
        return run(args: ["list-workspaces", "--focused"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func switchTo(_ workspace: String) {
        _ = run(args: ["workspace", workspace])
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
        switch appName {
        case "WezTerm": return "\u{F018D}"
        case "Zen": return "\u{F0239}"
        case "Discord": return "\u{F066F}"
        case "Anki": return "\u{F04CE}"
        case "Finder": return "\u{F0036}"
        case "Safari": return "\u{F0039}"
        case "Notes": return "\u{F082E}"
        case "Mail": return "\u{F01EE}"
        case "System Settings": return "\u{F0493}"
        default: return "\u{F0614}"
        }
    }
}
