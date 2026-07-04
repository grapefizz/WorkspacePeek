import AppKit

final class PeekWindow: NSPanel {

    private var workspaces: [Workspace] = []
    private var thumbnailViews: [WorkspaceThumbnailView] = []
    private var gridView: NSGridView!
    private var container: NSVisualEffectView!
    private var badgeOverlay: NSView?
    private var titleLabel: NSTextField?
    private var selectedIndex: Int = 0
    private var colors: WalColors = .current

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
        container.layer?.cornerRadius = WorkspacePeekConfig.current.hud.containerCornerRadius
        container.layer?.masksToBounds = true
        contentView = container
    }

    func showPeek() {
        container.layer?.cornerRadius = WorkspacePeekConfig.current.hud.containerCornerRadius
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

        let cfg = WorkspacePeekConfig.current
        let hud = cfg.hud
        let badge = hud.badge
        let maxPerRow = max(hud.maxPerRow, 1)

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
        gridView.rowSpacing = hud.gridRowSpacing
        gridView.columnSpacing = hud.gridColumnSpacing
        gridView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gridView)

        // (centred title above the grid optional)
        var gridTopConstant: CGFloat = hud.contentPadding
        if badge.showTitle {
            let title = NSTextField(labelWithString: badge.titleText)
            title.font = NSFont.firstAvailable(
                names: hud.titleFontNames,
                size: badge.titleFontSize,
                fallback: .monospacedSystemFont(ofSize: badge.titleFontSize, weight: .medium)
            )
            title.textColor = colors.color(named: cfg.colors.roles.title)
            title.alignment = .center
            title.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(title)
            titleLabel = title

            NSLayoutConstraint.activate([
                title.topAnchor.constraint(equalTo: container.topAnchor, constant: hud.titleTopPadding),
                title.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ])
            gridTopConstant = hud.titleTopPadding + badge.titleFontSize + hud.titleBottomPadding
        }

        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: container.topAnchor, constant: gridTopConstant),
            gridView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -hud.contentPadding),
            gridView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hud.contentPadding),
            gridView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -hud.contentPadding),
        ])
    }

    // (Geometry reads from ~/.config/workspacepeek/config.json each open.)
    private func layoutBadges() {
        badgeOverlay?.removeFromSuperview()
        let overlay = NSView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        container.addSubview(overlay, positioned: .above, relativeTo: gridView)
        badgeOverlay = overlay

        let config = WorkspacePeekConfig.current
        let cfg = config.hud.badge
        let roles = config.colors.roles

        let glyphFont = NSFont.firstAvailable(
            names: config.hud.glyphFontNames,
            size: cfg.fontSize,
            fallback: .systemFont(ofSize: cfg.fontSize)
        )

        for (index, thumb) in thumbnailViews.enumerated() {
            guard index < workspaces.count else { continue }
            let ws = workspaces[index]
            let names = Array(ws.appNames.prefix(max(cfg.maxApps, 0)))
            guard !names.isEmpty else { continue }

            let frameInOverlay = thumb.convert(thumb.bounds, to: overlay)
            let cornerX = frameInOverlay.minX + cfg.insetX
            let cornerY = frameInOverlay.maxY - cfg.insetY  // flipped: maxY is visual top

            let bubbleBG = ws.isFocused
                ? colors.color(named: roles.focusedBubbleBackground)
                : colors.color(named: roles.unfocusedBubbleBackground)
            let glyphColor = ws.isFocused
                ? colors.color(named: roles.focusedBubbleGlyph)
                : colors.color(named: roles.unfocusedBubbleGlyph)

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
        let padding = WorkspacePeekConfig.current.hud.contentPadding
        let windowSize = NSSize(width: size.width + padding * 2, height: size.height + padding * 2)
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
        let config = WorkspacePeekConfig.current
        let nav = config.navigation
        let maxPerRow = max(config.hud.maxPerRow, 1)
        switch event.keyCode {
        case nav.escapeKeyCode:
            hidePeek()
        case nav.returnKeyCode:
            confirm(index: selectedIndex)
        case nav.leftKeyCode:
            if selectedIndex > 0 { selectedIndex -= 1; updateSelection() }
        case nav.rightKeyCode:
            if selectedIndex < workspaces.count - 1 { selectedIndex += 1; updateSelection() }
        case nav.upKeyCode:
            if selectedIndex - maxPerRow >= 0 { selectedIndex -= maxPerRow; updateSelection() }
        case nav.downKeyCode:
            if selectedIndex + maxPerRow < workspaces.count { selectedIndex += maxPerRow; updateSelection() }
        default:
            let start = nav.numberSelectionStartsAt
            if let c = event.characters, let n = Int(c), n >= start, n < start + workspaces.count {
                confirm(index: n - start)
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
        let config = WorkspacePeekConfig.current
        let cfg = config.hud.thumbnail
        let roles = config.colors.roles

        wantsLayer = true
        layer?.cornerRadius = cfg.cornerRadius
        layer?.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = colors.background.withAlphaComponent(cfg.backgroundAlpha).cgColor

        ring.wantsLayer = true
        ring.layer?.cornerRadius = cfg.cornerRadius
        ring.layer?.borderWidth = 0
        ring.layer?.masksToBounds = false
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = cfg.imageCornerRadius
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let font = NSFont.firstAvailable(
            names: cfg.labelFontNames,
            size: cfg.labelFontSize,
            fallback: .monospacedSystemFont(ofSize: cfg.labelFontSize, weight: .medium)
        )
        label.stringValue = workspace.isFocused ? "\(cfg.focusedIndicator)\(workspace.id)" : workspace.id
        label.font = font
        label.textColor = workspace.isFocused
            ? colors.color(named: roles.focusedThumbnailLabel)
            : colors.foreground.withAlphaComponent(cfg.labelUnfocusedAlpha)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: cfg.width),
            heightAnchor.constraint(equalToConstant: cfg.imageHeight + cfg.labelHeight + cfg.imageInset + cfg.labelTopSpacing),

            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor, constant: cfg.imageInset),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: cfg.imageInset),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -cfg.imageInset),
            imageView.heightAnchor.constraint(equalToConstant: cfg.imageHeight),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: cfg.labelTopSpacing),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.heightAnchor.constraint(equalToConstant: cfg.labelHeight),
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
        let cfg = WorkspacePeekConfig.current.hud.thumbnail
        let img = NSImage(size: NSSize(width: cfg.width - cfg.imageInset * 2, height: cfg.imageHeight))
        img.lockFocus()
        colors.background.withAlphaComponent(cfg.placeholderAlpha).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: img.size),
            xRadius: cfg.placeholderCornerRadius,
            yRadius: cfg.placeholderCornerRadius
        ).fill()
        img.unlockFocus()
        return img
    }

    func setSelected(_ selected: Bool) {
        let config = WorkspacePeekConfig.current
        let badge = config.hud.badge
        let thumb = config.hud.thumbnail
        let roles = config.colors.roles
        ring.layer?.borderWidth = selected ? badge.selBorderWidth : (workspace.isFocused ? thumb.focusedRingBorderWidth : thumb.unselectedRingBorderWidth)
        ring.layer?.borderColor = selected
            ? colors.color(named: roles.selectedThumbnailRing).cgColor
            : colors.color(named: roles.unselectedThumbnailRing).withAlphaComponent(thumb.unselectedRingAlpha).cgColor

        // (glow on selected workspaces)
        if selected {
            ring.layer?.shadowColor = colors.color(named: roles.selectedThumbnailRing).cgColor
            ring.layer?.shadowRadius = badge.selGlowRadius
            ring.layer?.shadowOpacity = Float(badge.selGlowOpacity)
            ring.layer?.shadowOffset = .zero
            ring.layer?.masksToBounds = false
        } else {
            ring.layer?.shadowOpacity = 0
        }

        if workspace.isFocused {
            label.textColor = colors.color(named: roles.focusedThumbnailLabel)
        } else {
            label.textColor = selected
                ? colors.color(named: roles.selectedThumbnailLabel)
                : colors.foreground.withAlphaComponent(thumb.labelUnfocusedAlpha)
        }
    }

    @objc private func tapped() { onSelect?() }

    override func mouseEntered(with event: NSEvent) {
        let config = WorkspacePeekConfig.current
        let cfg = config.hud.thumbnail
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = cfg.hoverDuration
            animator().layer?.backgroundColor = colors.color(named: config.colors.roles.selectedThumbnailRing).withAlphaComponent(cfg.hoverAlpha).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        let cfg = WorkspacePeekConfig.current.hud.thumbnail
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = cfg.hoverDuration
            animator().layer?.backgroundColor = colors.background.withAlphaComponent(cfg.backgroundAlpha).cgColor
        }
    }
}
