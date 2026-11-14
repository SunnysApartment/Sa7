import AppKit
import ApplicationServices

/// A small confirmation bubble shown near the text cursor after a fix. Never takes focus.
@MainActor
final class HUD {
    static let shared = HUD()

    private static let green = NSColor(srgbRed: 0x1f / 255, green: 0x3d / 255, blue: 0x32 / 255, alpha: 1)
    private static let chalk = NSColor(srgbRed: 0xf3 / 255, green: 0xf2 / 255, blue: 0xe8 / 255, alpha: 1)
    private static let height: CGFloat = 34

    private let panel: NSPanel
    private var generation = 0

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSView()
        panel.contentView?.wantsLayer = true
    }

    /// Shows `text` (e.g. the fixed word, or "Nothing to fix") with an SF Symbol, near the text cursor of the focused app,
    /// falling back to just below the mouse pointer, then fades out after ~1.4 s. Calling again while visible replaces it smoothly.
    func show(_ text: String, symbol: String = "checkmark.circle.fill", tint: NSColor = .systemYellow, sound: Bool = false) {
        present(text, symbol: symbol, tint: tint, key: nil, seconds: 1.4)
        if sound, let s = NSSound(named: "Pop") {
            s.stop()
            s.volume = 0.3
            s.play()
        }
    }

    /// A hint with a key cap, e.g. HUD.shared.hint("مرحبا", key: "⌃K") → "مرحبا  ⌃K" meaning "press ⌃K to fix"; stays ~3 s.
    func hint(_ text: String, key: String) {
        present(text, symbol: "keyboard", tint: .systemYellow, key: key, seconds: 3)
    }

    #if DEBUG
    /// Try it: English, Arabic, then a hint.
    static func demo() {
        Task { @MainActor in
            HUD.shared.show("hello", sound: true)
            try? await Task.sleep(for: .seconds(2))
            HUD.shared.show("مرحبا بالعالم")
            try? await Task.sleep(for: .seconds(2))
            HUD.shared.hint("مرحبا", key: "⌃K")
        }
    }
    #endif

    // MARK: - Internals

    private func present(_ raw: String, symbol: String, tint: NSColor, key: String?, seconds: Double) {
        let text = Self.truncated(raw)
        generation += 1
        let gen = generation
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let wasVisible = panel.isVisible && panel.alphaValue > 0

        let pill = makePill(text, symbol: symbol, tint: tint, key: key)
        let size = NSSize(width: ceil(pill.fittingSize.width), height: Self.height)
        let frame = Self.placement(for: size, near: Self.caretRect() ?? Self.mouseAnchor())

        let root = panel.contentView!
        root.subviews.forEach { $0.removeFromSuperview() }
        // Pin to the content view so the pill tracks the (possibly animated) panel frame.
        pill.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            pill.topAnchor.constraint(equalTo: root.topAnchor),
            pill.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        if wasVisible {
            // Replace smoothly: cross-fade the content and glide to the new spot.
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.15
            root.layer?.add(fade, forKey: "swap")
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = reduceMotion ? 0 : 0.15
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            if !reduceMotion, let layer = pill.layer {
                // Layer anchor is bottom-left, so translate to keep the scale centred.
                let s: CGFloat = 0.96
                let from = CATransform3DConcat(CATransform3DMakeScale(s, s, 1),
                                               CATransform3DMakeTranslation(size.width * (1 - s) / 2, size.height * (1 - s) / 2, 0))
                let pop = CASpringAnimation(perceptualDuration: 0.18, bounce: 0) // bounce 0 = critically damped
                pop.keyPath = "transform"
                pop.fromValue = NSValue(caTransform3D: from)
                pop.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                layer.add(pop, forKey: "pop")
            }
        }
        panel.invalidateShadow()

        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: key.map { "\(text), \($0)" } ?? text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.generation == gen else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                self.panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    if self.generation == gen { self.panel.orderOut(nil) }
                }
            })
        }
    }

    private func makePill(_ text: String, symbol: String, tint: NSColor, key: String?) -> NSView {
        let height = Self.height
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = height / 2
        pill.layer?.masksToBounds = true

        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            pill.layer?.backgroundColor = Self.green.cgColor
        } else {
            let glass = NSVisualEffectView()
            glass.material = .hudWindow
            glass.blendingMode = .behindWindow
            glass.state = .active
            glass.appearance = NSAppearance(named: .darkAqua)
            fill(pill, with: glass)
            let tintView = NSView()
            tintView.wantsLayer = true
            tintView.layer?.backgroundColor = Self.green.withAlphaComponent(0.7).cgColor
            fill(pill, with: tintView)
        }

        // 1 px light top edge, inset so it stays on the straight part of the pill.
        let edge = NSView()
        edge.wantsLayer = true
        edge.layer?.backgroundColor = Self.chalk.withAlphaComponent(0.28).cgColor
        edge.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(edge)
        NSLayoutConstraint.activate([
            edge.topAnchor.constraint(equalTo: pill.topAnchor),
            edge.heightAnchor.constraint(equalToConstant: 1),
            edge.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: height / 2),
            edge.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -height / 2),
        ])

        let rtl = Self.isRightToLeft(text)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))
        icon.contentTintColor = tint

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = Self.chalk
        label.alignment = .natural
        label.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        var items: [NSView] = [icon, label]
        if let key { items.append(keyCap(key)) }
        let stack = NSStackView(views: items)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.userInterfaceLayoutDirection = rtl ? .rightToLeft : .leftToRight
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 13),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -16),
        ])
        return pill
    }

    private func keyCap(_ key: String) -> NSView {
        let label = NSTextField(labelWithString: key)
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = Self.green
        label.translatesAutoresizingMaskIntoConstraints = false
        let cap = NSView()
        cap.wantsLayer = true
        cap.layer?.cornerRadius = 5
        cap.layer?.backgroundColor = Self.chalk.cgColor
        cap.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -6),
            cap.heightAnchor.constraint(equalToConstant: 20),
        ])
        return cap
    }

    private func fill(_ parent: NSView, with child: NSView) {
        child.frame = parent.bounds
        child.autoresizingMask = [.width, .height]
        child.translatesAutoresizingMaskIntoConstraints = true
        parent.addSubview(child)
    }

    // MARK: - Text

    static func truncated(_ text: String, limit: Int = 40) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > limit ? String(flat.prefix(limit - 1)) + "…" : flat
    }

    /// Direction from the first strong letter: Hebrew/Arabic blocks are right-to-left.
    static func isRightToLeft(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first(where: { CharacterSet.letters.contains($0) }) else { return false }
        return (0x0590...0x08FF).contains(first.value) || (0xFB1D...0xFEFF).contains(first.value)
    }

    // MARK: - Positioning

    /// Caret/selection rect of the focused element, in AppKit (bottom-left origin) coordinates.
    private static func caretRect() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.1)

        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let range else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var r = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &r), r.origin != .zero || r.size != .zero else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let flipped = NSRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
        // Some apps report junk rects; only trust ones that land on a screen.
        return NSScreen.screens.contains { $0.frame.intersects(flipped.insetBy(dx: -1, dy: -1)) } ? flipped : nil
    }

    /// Treat the pointer as a ~20 pt tall "caret" so the bubble lands just below the cursor arrow.
    private static func mouseAnchor() -> NSRect {
        let m = NSEvent.mouseLocation
        return NSRect(x: m.x, y: m.y - 20, width: 0, height: 20)
    }

    /// ~8 pt below the anchor (above if that would leave the screen), clamped to the visible frame.
    static func placement(for size: NSSize, near anchor: NSRect) -> NSRect {
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        var x = anchor.midX - size.width / 2
        var y = anchor.minY - 8 - size.height
        if y < visible.minY { y = anchor.maxY + 8 }
        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        y = min(max(y, visible.minY + 4), visible.maxY - size.height - 4)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
