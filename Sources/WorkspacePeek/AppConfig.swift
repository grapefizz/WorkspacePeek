import AppKit
import Foundation

struct WorkspacePeekConfig: Codable {
    var paths = PathConfig()
    var loginItem = LoginItemConfig()
    var hotkey = HotkeyConfig()
    var navigation = NavigationConfig()
    var capture = CaptureConfig()
    var windowManager = WindowManagerConfig()
    var hud = HUDConfig()
    var colors = ColorConfig()
    var glyphs = GlyphConfig()
    var logging = LoggingConfig()

    static let fileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/workspacepeek/config.json")
    }()

    static var current: WorkspacePeekConfig {
        loadOrCreate()
    }

    static func loadOrCreate() -> WorkspacePeekConfig {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: fileURL.path) {
            let cfg = WorkspacePeekConfig()
            cfg.writeDefault(to: fileURL)
            return cfg
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let cfg = try JSONDecoder().decode(WorkspacePeekConfig.self, from: data)
            if String(data: data, encoding: .utf8)?.contains("\"triggerKeyCode\"") == true {
                cfg.writeDefault(to: fileURL)
            }
            return cfg
        } catch {
            print("WorkspacePeek config error: \(error)")
            return WorkspacePeekConfig()
        }
    }

    func writeDefault(to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    static func url(forConfiguredPath path: String) -> URL {
        URL(fileURLWithPath: expandPath(path))
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paths = try c.decodeIfPresent(PathConfig.self, forKey: .paths) ?? PathConfig()
        loginItem = try c.decodeIfPresent(LoginItemConfig.self, forKey: .loginItem) ?? LoginItemConfig()
        hotkey = try c.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? HotkeyConfig()
        navigation = try c.decodeIfPresent(NavigationConfig.self, forKey: .navigation) ?? NavigationConfig()
        capture = try c.decodeIfPresent(CaptureConfig.self, forKey: .capture) ?? CaptureConfig()
        windowManager = try c.decodeIfPresent(WindowManagerConfig.self, forKey: .windowManager) ?? WindowManagerConfig()
        hud = try c.decodeIfPresent(HUDConfig.self, forKey: .hud) ?? HUDConfig()
        colors = try c.decodeIfPresent(ColorConfig.self, forKey: .colors) ?? ColorConfig()
        glyphs = try c.decodeIfPresent(GlyphConfig.self, forKey: .glyphs) ?? GlyphConfig()
        logging = try c.decodeIfPresent(LoggingConfig.self, forKey: .logging) ?? LoggingConfig()
    }
}

struct PathConfig: Codable {
    var screenshotCacheDirectory = "~/.cache/workspacepeek"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        screenshotCacheDirectory = try c.decodeIfPresent(String.self, forKey: .screenshotCacheDirectory) ?? screenshotCacheDirectory
    }
}

struct LoginItemConfig: Codable {
    var registerOnLaunch = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        registerOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .registerOnLaunch) ?? registerOnLaunch
    }
}

struct HotkeyConfig: Codable {
    var triggerKey = "w"
    var triggerModifiers = ["option"]
    var consumeEvent = true

    var triggerKeyCode: CGKeyCode? {
        KeyCodeMap.code(for: triggerKey)
    }

    var modifierFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for modifier in triggerModifiers {
            switch modifier.lowercased() {
            case "option", "alternate", "alt":
                flags.insert(.maskAlternate)
            case "command", "cmd":
                flags.insert(.maskCommand)
            case "control", "ctrl":
                flags.insert(.maskControl)
            case "shift":
                flags.insert(.maskShift)
            default:
                continue
            }
        }
        return flags
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case triggerKey
        case triggerKeyCode
        case triggerModifiers
        case consumeEvent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let key = try c.decodeIfPresent(String.self, forKey: .triggerKey) {
            triggerKey = key
        } else if let keyCode = try c.decodeIfPresent(UInt16.self, forKey: .triggerKeyCode),
                  let key = KeyCodeMap.name(for: keyCode) {
            triggerKey = key
        }
        triggerModifiers = try c.decodeIfPresent([String].self, forKey: .triggerModifiers) ?? triggerModifiers
        consumeEvent = try c.decodeIfPresent(Bool.self, forKey: .consumeEvent) ?? consumeEvent
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(triggerKey, forKey: .triggerKey)
        try c.encode(triggerModifiers, forKey: .triggerModifiers)
        try c.encode(consumeEvent, forKey: .consumeEvent)
    }
}

enum KeyCodeMap {
    static let namesByCode: [UInt16: String] = [
        0x00: "a", 0x01: "s", 0x02: "d", 0x03: "f", 0x04: "h", 0x05: "g",
        0x06: "z", 0x07: "x", 0x08: "c", 0x09: "v", 0x0B: "b", 0x0C: "q",
        0x0D: "w", 0x0E: "e", 0x0F: "r", 0x10: "y", 0x11: "t", 0x12: "1",
        0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
        0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "o", 0x20: "u", 0x21: "[", 0x22: "i", 0x23: "p", 0x24: "return",
        0x25: "l", 0x26: "j", 0x27: "'", 0x28: "k", 0x29: ";", 0x2A: "\\",
        0x2B: ",", 0x2C: "/", 0x2D: "n", 0x2E: "m", 0x2F: ".", 0x30: "tab",
        0x31: "space", 0x32: "`", 0x33: "delete", 0x35: "escape",
    ]

    static let codesByName: [String: UInt16] = {
        var map = Dictionary(uniqueKeysWithValues: namesByCode.map { ($0.value, $0.key) })
        map["esc"] = 0x35
        map["enter"] = 0x24
        map["backspace"] = 0x33
        map["del"] = 0x33
        return map
    }()

    static func code(for key: String) -> CGKeyCode? {
        codesByName[key.lowercased()]
    }

    static func name(for code: UInt16) -> String? {
        namesByCode[code]
    }
}

struct NavigationConfig: Codable {
    var escapeKeyCode: UInt16 = 53
    var returnKeyCode: UInt16 = 36
    var leftKeyCode: UInt16 = 123
    var rightKeyCode: UInt16 = 124
    var upKeyCode: UInt16 = 126
    var downKeyCode: UInt16 = 125
    var numberSelectionStartsAt = 1

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        escapeKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .escapeKeyCode) ?? escapeKeyCode
        returnKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .returnKeyCode) ?? returnKeyCode
        leftKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .leftKeyCode) ?? leftKeyCode
        rightKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .rightKeyCode) ?? rightKeyCode
        upKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .upKeyCode) ?? upKeyCode
        downKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .downKeyCode) ?? downKeyCode
        numberSelectionStartsAt = try c.decodeIfPresent(Int.self, forKey: .numberSelectionStartsAt) ?? numberSelectionStartsAt
    }
}

struct CaptureConfig: Codable {
    var displayIndex = 0
    var imageScaleDivisor: Double = 3
    var showsCursor = false
    var excludingDesktopWindows = false
    var onScreenWindowsOnly = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayIndex = try c.decodeIfPresent(Int.self, forKey: .displayIndex) ?? displayIndex
        imageScaleDivisor = try c.decodeIfPresent(Double.self, forKey: .imageScaleDivisor) ?? imageScaleDivisor
        showsCursor = try c.decodeIfPresent(Bool.self, forKey: .showsCursor) ?? showsCursor
        excludingDesktopWindows = try c.decodeIfPresent(Bool.self, forKey: .excludingDesktopWindows) ?? excludingDesktopWindows
        onScreenWindowsOnly = try c.decodeIfPresent(Bool.self, forKey: .onScreenWindowsOnly) ?? onScreenWindowsOnly
    }
}

struct WindowManagerConfig: Codable {
    var backend = "auto"
    var pgrepPath = "/usr/bin/pgrep"
    var riftProcessName = "rift"
    var includeEmptyWorkspaces = false
    var aerospaceBinaryCandidates = [
        "/opt/homebrew/bin/aerospace",
        "/usr/local/bin/aerospace",
        "/usr/bin/aerospace",
    ]
    var riftBinaryCandidates = [
        "/opt/homebrew/bin/rift-cli",
        "/usr/local/bin/rift-cli",
    ]
    var aerospaceListWorkspacesArguments = ["list-workspaces", "--all"]
    var aerospaceFocusedWorkspaceArguments = ["list-workspaces", "--focused"]
    var aerospaceListWindowsArguments = ["list-windows", "--all", "--format", "%{workspace}|%{app-name}"]
    var aerospaceSwitchWorkspaceArguments = ["workspace", "{workspace}"]
    var aerospaceWindowSeparator = "|"
    var riftQueryWorkspacesArguments = ["query", "workspaces"]
    var riftSwitchWorkspaceArguments = ["execute", "workspace", "switch", "{index}"]
    var riftNumericWorkspaceIndexOffset = -1

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backend = try c.decodeIfPresent(String.self, forKey: .backend) ?? backend
        pgrepPath = try c.decodeIfPresent(String.self, forKey: .pgrepPath) ?? pgrepPath
        riftProcessName = try c.decodeIfPresent(String.self, forKey: .riftProcessName) ?? riftProcessName
        includeEmptyWorkspaces = try c.decodeIfPresent(Bool.self, forKey: .includeEmptyWorkspaces) ?? includeEmptyWorkspaces
        aerospaceBinaryCandidates = try c.decodeIfPresent([String].self, forKey: .aerospaceBinaryCandidates) ?? aerospaceBinaryCandidates
        riftBinaryCandidates = try c.decodeIfPresent([String].self, forKey: .riftBinaryCandidates) ?? riftBinaryCandidates
        aerospaceListWorkspacesArguments = try c.decodeIfPresent([String].self, forKey: .aerospaceListWorkspacesArguments) ?? aerospaceListWorkspacesArguments
        aerospaceFocusedWorkspaceArguments = try c.decodeIfPresent([String].self, forKey: .aerospaceFocusedWorkspaceArguments) ?? aerospaceFocusedWorkspaceArguments
        aerospaceListWindowsArguments = try c.decodeIfPresent([String].self, forKey: .aerospaceListWindowsArguments) ?? aerospaceListWindowsArguments
        aerospaceSwitchWorkspaceArguments = try c.decodeIfPresent([String].self, forKey: .aerospaceSwitchWorkspaceArguments) ?? aerospaceSwitchWorkspaceArguments
        aerospaceWindowSeparator = try c.decodeIfPresent(String.self, forKey: .aerospaceWindowSeparator) ?? aerospaceWindowSeparator
        riftQueryWorkspacesArguments = try c.decodeIfPresent([String].self, forKey: .riftQueryWorkspacesArguments) ?? riftQueryWorkspacesArguments
        riftSwitchWorkspaceArguments = try c.decodeIfPresent([String].self, forKey: .riftSwitchWorkspaceArguments) ?? riftSwitchWorkspaceArguments
        riftNumericWorkspaceIndexOffset = try c.decodeIfPresent(Int.self, forKey: .riftNumericWorkspaceIndexOffset) ?? riftNumericWorkspaceIndexOffset
    }
}

struct HUDConfig: Codable {
    var maxPerRow = 5
    var containerCornerRadius: CGFloat = 16
    var gridRowSpacing: CGFloat = 12
    var gridColumnSpacing: CGFloat = 12
    var contentPadding: CGFloat = 16
    var titleTopPadding: CGFloat = 14
    var titleBottomPadding: CGFloat = 14
    var titleFontNames = ["JetBrainsMono Nerd Font", "JetBrainsMonoNL Nerd Font"]
    var glyphFontNames = ["sketchybar-app-font", "JetBrainsMono Nerd Font", "JetBrainsMonoNL Nerd Font"]
    var badge = BadgeConfig()
    var thumbnail = ThumbnailConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxPerRow = try c.decodeIfPresent(Int.self, forKey: .maxPerRow) ?? maxPerRow
        containerCornerRadius = try c.decodeIfPresent(CGFloat.self, forKey: .containerCornerRadius) ?? containerCornerRadius
        gridRowSpacing = try c.decodeIfPresent(CGFloat.self, forKey: .gridRowSpacing) ?? gridRowSpacing
        gridColumnSpacing = try c.decodeIfPresent(CGFloat.self, forKey: .gridColumnSpacing) ?? gridColumnSpacing
        contentPadding = try c.decodeIfPresent(CGFloat.self, forKey: .contentPadding) ?? contentPadding
        titleTopPadding = try c.decodeIfPresent(CGFloat.self, forKey: .titleTopPadding) ?? titleTopPadding
        titleBottomPadding = try c.decodeIfPresent(CGFloat.self, forKey: .titleBottomPadding) ?? titleBottomPadding
        titleFontNames = try c.decodeIfPresent([String].self, forKey: .titleFontNames) ?? titleFontNames
        glyphFontNames = try c.decodeIfPresent([String].self, forKey: .glyphFontNames) ?? glyphFontNames
        badge = try c.decodeIfPresent(BadgeConfig.self, forKey: .badge) ?? BadgeConfig()
        thumbnail = try c.decodeIfPresent(ThumbnailConfig.self, forKey: .thumbnail) ?? ThumbnailConfig()
    }
}

struct BadgeConfig: Codable {
    var bubbleSize: CGFloat = 26
    var cornerRadius: CGFloat = 5
    var spacing: CGFloat = 5
    var fontSize: CGFloat = 15
    var glyphYOffset: CGFloat = 0
    var glyphXOffset: CGFloat = 0
    var insetX: CGFloat = 10
    var insetY: CGFloat = 10
    var maxApps = 5
    var selBorderWidth: CGFloat = 3
    var selGlowRadius: CGFloat = 12
    var selGlowOpacity: CGFloat = 0.9
    var titleText = "workspaces"
    var titleFontSize: CGFloat = 18
    var showTitle = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bubbleSize = try c.decodeIfPresent(CGFloat.self, forKey: .bubbleSize) ?? bubbleSize
        cornerRadius = try c.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? cornerRadius
        spacing = try c.decodeIfPresent(CGFloat.self, forKey: .spacing) ?? spacing
        fontSize = try c.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? fontSize
        glyphYOffset = try c.decodeIfPresent(CGFloat.self, forKey: .glyphYOffset) ?? glyphYOffset
        glyphXOffset = try c.decodeIfPresent(CGFloat.self, forKey: .glyphXOffset) ?? glyphXOffset
        insetX = try c.decodeIfPresent(CGFloat.self, forKey: .insetX) ?? insetX
        insetY = try c.decodeIfPresent(CGFloat.self, forKey: .insetY) ?? insetY
        maxApps = try c.decodeIfPresent(Int.self, forKey: .maxApps) ?? maxApps
        selBorderWidth = try c.decodeIfPresent(CGFloat.self, forKey: .selBorderWidth) ?? selBorderWidth
        selGlowRadius = try c.decodeIfPresent(CGFloat.self, forKey: .selGlowRadius) ?? selGlowRadius
        selGlowOpacity = try c.decodeIfPresent(CGFloat.self, forKey: .selGlowOpacity) ?? selGlowOpacity
        titleText = try c.decodeIfPresent(String.self, forKey: .titleText) ?? titleText
        titleFontSize = try c.decodeIfPresent(CGFloat.self, forKey: .titleFontSize) ?? titleFontSize
        showTitle = try c.decodeIfPresent(Bool.self, forKey: .showTitle) ?? showTitle
    }
}

struct ThumbnailConfig: Codable {
    var width: CGFloat = 220
    var imageHeight: CGFloat = 130
    var labelHeight: CGFloat = 28
    var cornerRadius: CGFloat = 10
    var imageCornerRadius: CGFloat = 7
    var imageInset: CGFloat = 8
    var labelTopSpacing: CGFloat = 0
    var backgroundAlpha: CGFloat = 0.6
    var placeholderAlpha: CGFloat = 0.4
    var placeholderCornerRadius: CGFloat = 6
    var focusedIndicator = "* "
    var focusedRingBorderWidth: CGFloat = 1.5
    var unselectedRingBorderWidth: CGFloat = 0
    var unselectedRingAlpha: CGFloat = 0.6
    var labelUnfocusedAlpha: CGFloat = 0.8
    var hoverDuration: TimeInterval = 0.1
    var hoverAlpha: CGFloat = 0.1
    var labelFontSize: CGFloat = 13
    var labelFontNames = [
        "JetBrainsMonoNL Nerd Font Mono",
        "JetBrainsMono Nerd Font Mono",
        "JetBrainsMono-Regular",
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(CGFloat.self, forKey: .width) ?? width
        imageHeight = try c.decodeIfPresent(CGFloat.self, forKey: .imageHeight) ?? imageHeight
        labelHeight = try c.decodeIfPresent(CGFloat.self, forKey: .labelHeight) ?? labelHeight
        cornerRadius = try c.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? cornerRadius
        imageCornerRadius = try c.decodeIfPresent(CGFloat.self, forKey: .imageCornerRadius) ?? imageCornerRadius
        imageInset = try c.decodeIfPresent(CGFloat.self, forKey: .imageInset) ?? imageInset
        labelTopSpacing = try c.decodeIfPresent(CGFloat.self, forKey: .labelTopSpacing) ?? labelTopSpacing
        backgroundAlpha = try c.decodeIfPresent(CGFloat.self, forKey: .backgroundAlpha) ?? backgroundAlpha
        placeholderAlpha = try c.decodeIfPresent(CGFloat.self, forKey: .placeholderAlpha) ?? placeholderAlpha
        placeholderCornerRadius = try c.decodeIfPresent(CGFloat.self, forKey: .placeholderCornerRadius) ?? placeholderCornerRadius
        focusedIndicator = try c.decodeIfPresent(String.self, forKey: .focusedIndicator) ?? focusedIndicator
        focusedRingBorderWidth = try c.decodeIfPresent(CGFloat.self, forKey: .focusedRingBorderWidth) ?? focusedRingBorderWidth
        unselectedRingBorderWidth = try c.decodeIfPresent(CGFloat.self, forKey: .unselectedRingBorderWidth) ?? unselectedRingBorderWidth
        unselectedRingAlpha = try c.decodeIfPresent(CGFloat.self, forKey: .unselectedRingAlpha) ?? unselectedRingAlpha
        labelUnfocusedAlpha = try c.decodeIfPresent(CGFloat.self, forKey: .labelUnfocusedAlpha) ?? labelUnfocusedAlpha
        hoverDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .hoverDuration) ?? hoverDuration
        hoverAlpha = try c.decodeIfPresent(CGFloat.self, forKey: .hoverAlpha) ?? hoverAlpha
        labelFontSize = try c.decodeIfPresent(CGFloat.self, forKey: .labelFontSize) ?? labelFontSize
        labelFontNames = try c.decodeIfPresent([String].self, forKey: .labelFontNames) ?? labelFontNames
    }
}

struct ColorConfig: Codable {
    var useWalColors = true
    var walColorsPath = "~/.cache/wal/colors.json"
    var fallback = ColorPalette()
    var roles = ColorRoleConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        useWalColors = try c.decodeIfPresent(Bool.self, forKey: .useWalColors) ?? useWalColors
        walColorsPath = try c.decodeIfPresent(String.self, forKey: .walColorsPath) ?? walColorsPath
        fallback = try c.decodeIfPresent(ColorPalette.self, forKey: .fallback) ?? ColorPalette()
        roles = try c.decodeIfPresent(ColorRoleConfig.self, forKey: .roles) ?? ColorRoleConfig()
    }
}

struct ColorPalette: Codable {
    var background = "#280d2a"
    var foreground = "#f2c4e1"
    var color0 = "#280d2a"
    var color1 = "#642c66"
    var color2 = "#6d346e"
    var color3 = "#744271"
    var color4 = "#804482"
    var color5 = "#8e568c"
    var color6 = "#9c5f9d"
    var color7 = "#f2c4e1"
    var color8 = "#541f57"
    var color13 = "#aa80a8"
    var color15 = "#f2c4e1"

    init() {}
}

struct ColorRoleConfig: Codable {
    var title = "color7"
    var focusedBubbleBackground = "color13"
    var unfocusedBubbleBackground = "color8"
    var focusedBubbleGlyph = "background"
    var unfocusedBubbleGlyph = "color15"
    var focusedThumbnailLabel = "color7"
    var selectedThumbnailLabel = "color4"
    var selectedThumbnailRing = "color4"
    var unselectedThumbnailRing = "color2"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? title
        focusedBubbleBackground = try c.decodeIfPresent(String.self, forKey: .focusedBubbleBackground) ?? focusedBubbleBackground
        unfocusedBubbleBackground = try c.decodeIfPresent(String.self, forKey: .unfocusedBubbleBackground) ?? unfocusedBubbleBackground
        focusedBubbleGlyph = try c.decodeIfPresent(String.self, forKey: .focusedBubbleGlyph) ?? focusedBubbleGlyph
        unfocusedBubbleGlyph = try c.decodeIfPresent(String.self, forKey: .unfocusedBubbleGlyph) ?? unfocusedBubbleGlyph
        focusedThumbnailLabel = try c.decodeIfPresent(String.self, forKey: .focusedThumbnailLabel) ?? focusedThumbnailLabel
        selectedThumbnailLabel = try c.decodeIfPresent(String.self, forKey: .selectedThumbnailLabel) ?? selectedThumbnailLabel
        selectedThumbnailRing = try c.decodeIfPresent(String.self, forKey: .selectedThumbnailRing) ?? selectedThumbnailRing
        unselectedThumbnailRing = try c.decodeIfPresent(String.self, forKey: .unselectedThumbnailRing) ?? unselectedThumbnailRing
    }
}

struct GlyphConfig: Codable {
    var defaultGlyph = "\u{F0614}"
    var appGlyphs = [
        "WezTerm": "\u{F018D}",
        "Zen": "\u{F0239}",
        "Discord": "\u{F066F}",
        "Anki": "\u{F04CE}",
        "Finder": "\u{F0036}",
        "Safari": "\u{F0039}",
        "Notes": "\u{F082E}",
        "Mail": "\u{F01EE}",
        "System Settings": "\u{F0493}",
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultGlyph = try c.decodeIfPresent(String.self, forKey: .defaultGlyph) ?? defaultGlyph
        appGlyphs = try c.decodeIfPresent([String: String].self, forKey: .appGlyphs) ?? appGlyphs
    }
}

struct LoggingConfig: Codable {
    var prefix = "WorkspacePeek"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix) ?? prefix
    }
}

extension Array where Element == String {
    func replacingPlaceholders(_ values: [String: String]) -> [String] {
        map { arg in
            values.reduce(arg) { partial, pair in
                partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
            }
        }
    }
}

extension NSFont {
    static func firstAvailable(names: [String], size: CGFloat, fallback: NSFont) -> NSFont {
        for name in names {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return fallback
    }
}
