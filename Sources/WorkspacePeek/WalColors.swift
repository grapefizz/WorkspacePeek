import AppKit

struct WalColors {
    let background: NSColor
    let foreground: NSColor
    let color0: NSColor
    let color1: NSColor
    let color2: NSColor
    let color3: NSColor
    let color4: NSColor
    let color5: NSColor
    let color6: NSColor
    let color7: NSColor
    let color8: NSColor
    let color13: NSColor
    let color15: NSColor

    static var current: WalColors {
        let cfg = WorkspacePeekConfig.current
        if cfg.colors.useWalColors, let colors = load(path: cfg.colors.walColorsPath) {
            return colors
        }
        return fallback(from: cfg.colors.fallback)
    }

    static func load(path configuredPath: String) -> WalColors? {
        let path = WorkspacePeekConfig.expandPath(configuredPath)
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let special = json["special"] as? [String: String],
            let colors = json["colors"] as? [String: String],
            let bg = special["background"].flatMap(NSColor.init(hex:)),
            let fg = special["foreground"].flatMap(NSColor.init(hex:))
        else { return nil }

        func c(_ key: String, _ fallback: NSColor) -> NSColor {
            colors[key].flatMap(NSColor.init(hex:)) ?? fallback
        }

        return WalColors(
            background: bg,
            foreground: fg,
            color0: c("color0", .black),
            color1: c("color1", .red),
            color2: c("color2", .green),
            color3: c("color3", .yellow),
            color4: c("color4", .blue),
            color5: c("color5", .magenta),
            color6: c("color6", .cyan),
            color7: c("color7", .white),
            color8: c("color8", .gray),
            color13: c("color13", .magenta),
            color15: c("color15", fg)
        )
    }

    static func fallback(from palette: ColorPalette) -> WalColors {
        let fg = NSColor(hex: palette.foreground) ?? .white
        return WalColors(
            background: NSColor(hex: palette.background) ?? .black,
            foreground: fg,
            color0: NSColor(hex: palette.color0) ?? .black,
            color1: NSColor(hex: palette.color1) ?? .red,
            color2: NSColor(hex: palette.color2) ?? .green,
            color3: NSColor(hex: palette.color3) ?? .yellow,
            color4: NSColor(hex: palette.color4) ?? .blue,
            color5: NSColor(hex: palette.color5) ?? .magenta,
            color6: NSColor(hex: palette.color6) ?? .cyan,
            color7: NSColor(hex: palette.color7) ?? fg,
            color8: NSColor(hex: palette.color8) ?? .gray,
            color13: NSColor(hex: palette.color13) ?? .magenta,
            color15: NSColor(hex: palette.color15) ?? fg
        )
    }

    func color(named name: String) -> NSColor {
        switch name {
        case "background": return background
        case "foreground": return foreground
        case "color0": return color0
        case "color1": return color1
        case "color2": return color2
        case "color3": return color3
        case "color4": return color4
        case "color5": return color5
        case "color6": return color6
        case "color7": return color7
        case "color8": return color8
        case "color13": return color13
        case "color15": return color15
        default: return foreground
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8)  & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
