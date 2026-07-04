import AppKit

//(Badge geometry stuff)
struct BadgeConfig {
    var bubbleSize: CGFloat = 26
    var cornerRadius: CGFloat = 5
    var spacing: CGFloat = 5
    var fontSize: CGFloat = 15
    var glyphYOffset: CGFloat = 0   // + moves glyph up, - moves down
    var glyphXOffset: CGFloat = 0
    var insetX: CGFloat = 10
    var insetY: CGFloat = 10
    // selection styling
    var selBorderWidth: CGFloat = 3
    var selGlowRadius: CGFloat = 12
    var selGlowOpacity: CGFloat = 0.9
    // title
    var titleText: String = "workspaces"
    var titleFontSize: CGFloat = 18
    var showTitle: Bool = true

    static func load() -> BadgeConfig {
        var cfg = BadgeConfig()
        let path = NSString(string: "~/.config/workspacepeek/badge.json").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return cfg }
        func d(_ k: String) -> CGFloat? { (json[k] as? Double).map { CGFloat($0) } }
        if let v = d("bubbleSize") { cfg.bubbleSize = v }
        if let v = d("cornerRadius") { cfg.cornerRadius = v }
        if let v = d("spacing") { cfg.spacing = v }
        if let v = d("fontSize") { cfg.fontSize = v }
        if let v = d("glyphYOffset") { cfg.glyphYOffset = v }
        if let v = d("glyphXOffset") { cfg.glyphXOffset = v }
        if let v = d("insetX") { cfg.insetX = v }
        if let v = d("insetY") { cfg.insetY = v }
        if let v = d("selBorderWidth") { cfg.selBorderWidth = v }
        if let v = d("selGlowRadius") { cfg.selGlowRadius = v }
        if let v = d("selGlowOpacity") { cfg.selGlowOpacity = v }
        if let v = d("titleFontSize") { cfg.titleFontSize = v }
        if let s = json["titleText"] as? String { cfg.titleText = s }
        if let b = json["showTitle"] as? Bool { cfg.showTitle = b }
        return cfg
    }
}

final class PeekWindow: NSPanel {

    private var workspaces: [Workspace] = []
    private var thumbnailViews: [WorkspaceThumbnailView] = []
    private var gridView: NSGridView!
    private var container: NSVisualEffectView!
    private var badgeOverlay: NSView?
    private var titleLabel: NSTextField?
    private var selectedIndex: Int = 0
    private var colors: WalColors = .current

    private let maxPerRow = 5

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        setup()
    }

    private func setup() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        hasShadow = true
        animationBehavior = .utilityWindow

        container = NSVisualEffectView()
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        contentView = container
    }

    func showPeek() {
        colors = .current
        workspaces = WindowManager.listWorkspaces()
        selectedIndex = workspaces.firstIndex(where: { $0.isFocused }) ?? 0
        rebuildGrid()
        sizeAndCenter()
        layoutBadges()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePeek() {
        orderOut(nil)
    }

    func refreshFocused() {
        guard let focusedIndex = workspaces.firstIndex(where: { $0.isFocused }),
              focusedIndex < thumbnailViews.count,
              let image = WorkspaceCaptureEngine.loadCached(workspaceId: workspaces[focusedIndex].id)
        else { return }
        thumbnailViews[focusedIndex].updateImage(image)
    }

    private func rebuildGrid() {
        gridView?.removeFromSuperview()
        titleLabel?.removeFromSuperview()
        thumbnailViews = []

        let cfg = BadgeConfig.load()

        for (index, workspace) in workspaces.enumerated() {
            let thumb = WorkspaceThumbnailView(
                workspace: workspace,
                colors: colors,
                isSelected: index == selectedIndex
            )
            thumb.onSelect = { [weak self] in self?.confirm(index: index) }
            thumbnailViews.append(thumb)
        }

        var rows: [[NSView]] = []
        var i = 0
        while i < thumbnailViews.count {
            let end = min(i + maxPerRow, thumbnailViews.count)
            rows.append(Array(thumbnailViews[i..<end]))
            i = end
        }

        if let last = rows.last, last.count < maxPerRow, rows.count > 1 {
            var padded = last
            while padded.count < maxPerRow {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                padded.append(spacer)
            }
            rows[rows.count - 1] = padded
        }

        gridView = NSGridView(views: rows)
        gridView.rowSpacing = 12
        gridView.columnSpacing = 12
        gridView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gridView)

        // (centred title above the grid optional)
        var gridTopConstant: CGFloat = 16
        if cfg.showTitle {
            let title = NSTextField(labelWithString: cfg.titleText)
            title.font = NSFont(name: "JetBrainsMono Nerd Font", size: cfg.titleFontSize)
                ?? NSFont(name: "JetBrainsMonoNL Nerd Font", size: cfg.titleFontSize)
                ?? NSFont.monospacedSystemFont(ofSize: cfg.titleFontSize, weight: .medium)
            title.textColor = colors.color7
            title.alignment = .center
            title.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(title)
            titleLabel = title

            NSLayoutConstraint.activate([
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                title.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ])
            gridTopConstant = 14 + cfg.titleFontSize + 14
        }

        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: container.topAnchor, constant: gridTopConstant),
            gridView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            gridView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            gridView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
    }

    // (Geometry reads from ~/.config/workspacepeek/badge.json each open.)
    private func layoutBadges() {
        badgeOverlay?.removeFromSuperview()
        let overlay = NSView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        container.addSubview(overlay, positioned: .above, relativeTo: gridView)
        badgeOverlay = overlay

        let cfg = BadgeConfig.load()

        let glyphFont = NSFont(name: "sketchybar-app-font", size: cfg.fontSize)
            ?? NSFont(name: "JetBrainsMono Nerd Font", size: cfg.fontSize)
            ?? NSFont(name: "JetBrainsMonoNL Nerd Font", size: cfg.fontSize)
            ?? NSFont.systemFont(ofSize: cfg.fontSize)

        for (index, thumb) in thumbnailViews.enumerated() {
            guard index < workspaces.count else { continue }
            let ws = workspaces[index]
            let names = Array(ws.appNames.prefix(5))
            guard !names.isEmpty else { continue }

            let frameInOverlay = thumb.convert(thumb.bounds, to: overlay)
            let cornerX = frameInOverlay.minX + cfg.insetX
            let cornerY = frameInOverlay.maxY - cfg.insetY  // flipped: maxY is visual top

            let bubbleBG = ws.isFocused ? colors.sbFocusedBubbleBG : colors.sbUnfocusedBubbleBG
            let glyphColor = ws.isFocused ? colors.sbFocusedGlyph : colors.sbUnfocusedGlyph

            var x = cornerX
            for name in names {
                let glyph = AppGlyphMap.glyph(for: name)

                let bubble = NSView(frame: NSRect(
                    x: x,
                    y: cornerY - cfg.bubbleSize,
                    width: cfg.bubbleSize,
                    height: cfg.bubbleSize
                ))
                bubble.wantsLayer = true
                bubble.layer?.backgroundColor = bubbleBG.cgColor
                bubble.layer?.cornerRadius = cfg.cornerRadius
                bubble.layer?.masksToBounds = false  // don't clip the glyph
                bubble.layer?.isGeometryFlipped = true
                bubble.shadow = {
                    let s = NSShadow()
                    s.shadowColor = colors.background.withAlphaComponent(0.6)
                    s.shadowBlurRadius = 3
                    s.shadowOffset = NSSize(width: 0, height: -1)
                    return s
                }()

                let textLayer = CATextLayer()
                textLayer.string = NSAttributedString(string: glyph, attributes: [
                    .font: glyphFont,
                    .foregroundColor: glyphColor,
                ])
                textLayer.alignmentMode = .center
                textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                textLayer.truncationMode = .none
                textLayer.isWrapped = false

                let measured = (glyph as NSString).size(withAttributes: [.font: glyphFont])
                let textHeight = max(measured.height, cfg.fontSize * 1.6)
                textLayer.frame = CGRect(
                    x: cfg.glyphXOffset - 2,
                    y: (cfg.bubbleSize - textHeight) / 2 + cfg.glyphYOffset,
                    width: cfg.bubbleSize + 4,
                    height: textHeight
                )
                bubble.layer?.addSublayer(textLayer)

                overlay.addSubview(bubble)
                x += cfg.bubbleSize + cfg.spacing
            }
        }
    }

    private func sizeAndCenter() {
        layoutIfNeeded()
        gridView.layoutSubtreeIfNeeded()
        let size = gridView.fittingSize
        let windowSize = NSSize(width: size.width + 32, height: size.height + 32)
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        setFrame(NSRect(
            x: sf.midX - windowSize.width / 2,
            y: sf.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        ), display: true)
    }

    private func updateSelection() {
        for (i, thumb) in thumbnailViews.enumerated() {
            thumb.setSelected(i == selectedIndex)
        }
    }

    private func confirm(index: Int) {
        guard index < workspaces.count else { return }
        WindowManager.switchTo(workspaces[index].id)
        hidePeek()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC
            hidePeek()
        case 36: // Return
            confirm(index: selectedIndex)
        case 123: // Left
            if selectedIndex > 0 { selectedIndex -= 1; updateSelection() }
        case 124: // Right
            if selectedIndex < workspaces.count - 1 { selectedIndex += 1; updateSelection() }
        case 126: // Up
            if selectedIndex - maxPerRow >= 0 { selectedIndex -= maxPerRow; updateSelection() }
        case 125: // Down
            if selectedIndex + maxPerRow < workspaces.count { selectedIndex += maxPerRow; updateSelection() }
        default:
            if let c = event.characters, let n = Int(c), n >= 1, n <= workspaces.count {
                confirm(index: n - 1)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class WorkspaceThumbnailView: NSView {

    let workspace: Workspace
    var onSelect: (() -> Void)?

    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let ring = NSView()
    private let colors: WalColors

    private let W: CGFloat = 220
    private let H: CGFloat = 130
    private let labelH: CGFloat = 28

    init(workspace: Workspace, colors: WalColors, isSelected: Bool) {
        self.workspace = workspace
        self.colors = colors
        super.init(frame: .zero)
        setup()
        setSelected(isSelected)
        loadImage()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = colors.background.withAlphaComponent(0.6).cgColor

        ring.wantsLayer = true
        ring.layer?.cornerRadius = 10
        ring.layer?.borderWidth = 0
        ring.layer?.masksToBounds = false
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let font = NSFont(name: "JetBrainsMonoNL Nerd Font Mono", size: 13)
            ?? NSFont(name: "JetBrainsMono Nerd Font Mono", size: 13)
            ?? NSFont(name: "JetBrainsMono-Regular", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.stringValue = workspace.isFocused ? "● \(workspace.id)" : workspace.id
        label.font = font
        label.textColor = workspace.isFocused
            ? colors.color7   // bright foreground = "you are here"
            : colors.foreground.withAlphaComponent(0.8)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: W),
            heightAnchor.constraint(equalToConstant: H + labelH),

            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalToConstant: H),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 0),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.heightAnchor.constraint(equalToConstant: labelH),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(click)

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    private func loadImage() {
        if let cached = WorkspaceCaptureEngine.loadCached(workspaceId: workspace.id) {
            imageView.image = NSImage(cgImage: cached, size: .zero)
        } else {
            imageView.image = placeholderImage()
        }
    }

    func updateImage(_ cgImage: CGImage) {
        imageView.image = NSImage(cgImage: cgImage, size: .zero)
    }

    private func placeholderImage() -> NSImage {
        let img = NSImage(size: NSSize(width: W - 16, height: H))
        img.lockFocus()
        colors.background.withAlphaComponent(0.4).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: img.size), xRadius: 6, yRadius: 6).fill()
        img.unlockFocus()
        return img
    }

    func setSelected(_ selected: Bool) {
        let cfg = BadgeConfig.load()
        ring.layer?.borderWidth = selected ? cfg.selBorderWidth : (workspace.isFocused ? 1.5 : 0)
        ring.layer?.borderColor = selected
            ? colors.color4.cgColor
            : colors.color2.withAlphaComponent(0.6).cgColor

        // (glow on selected workspaces)
        if selected {
            ring.layer?.shadowColor = colors.color4.cgColor
            ring.layer?.shadowRadius = cfg.selGlowRadius
            ring.layer?.shadowOpacity = Float(cfg.selGlowOpacity)
            ring.layer?.shadowOffset = .zero
            ring.layer?.masksToBounds = false
        } else {
            ring.layer?.shadowOpacity = 0
        }

        if workspace.isFocused {
            label.textColor = colors.color7
        } else {
            label.textColor = selected ? colors.color4 : colors.foreground.withAlphaComponent(0.8)
        }
    }

    @objc private func tapped() { onSelect?() }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            animator().layer?.backgroundColor = colors.color4.withAlphaComponent(0.1).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            animator().layer?.backgroundColor = colors.background.withAlphaComponent(0.6).cgColor
        }
    }
}
