import Cocoa
import PortRadarCore

/// A menu item view with the native selection behind its content. AppKit does not
/// highlight items that have a custom view; the delegate's `menu(_:willHighlight:)`
/// sets `isHighlighted` instead.
class HighlightView: NSView {
    static let height: CGFloat = 24
    static let inset: CGFloat = 17

    private let selection = NSVisualEffectView()
    private let canvas = Canvas()

    /// False for rows that react to the pointer without the selection bar.
    var showsSelection = true
    var isHighlighted = false {
        didSet {
            selection.isHidden = !(isHighlighted && showsSelection)
            canvas.needsDisplay = true
        }
    }
    var textColor: NSColor { isHighlighted ? .selectedMenuItemTextColor : .labelColor }
    var dimColor: NSColor { isHighlighted ? .selectedMenuItemTextColor : .secondaryLabelColor }

    override init(frame: NSRect) {
        super.init(frame: frame)
        autoresizingMask = [.width]
        selection.material = .selection
        selection.state = .active
        selection.isEmphasized = true
        selection.wantsLayer = true
        selection.layer?.cornerRadius = 7
        selection.isHidden = true
        selection.frame = bounds.insetBy(dx: 5, dy: 0)
        canvas.frame = bounds
        canvas.owner = self
        for view in [selection, canvas] {
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The whole row is one click target.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    /// Subclasses draw their row here, in the view's own coordinates.
    func drawContent() {}

    /// Sits above the selection so the content is drawn over it.
    private final class Canvas: NSView {
        weak var owner: HighlightView?
        override func draw(_ dirtyRect: NSRect) { owner?.drawContent() }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// Draws one line of text vertically centred, and returns the rect it used.
    @discardableResult
    func draw(_ text: String, font: NSFont, color: NSColor, x: CGFloat, dy: CGFloat = 0, maxWidth: CGFloat = .greatestFiniteMagnitude) -> NSRect {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingMiddle
        let string = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ])
        let size = string.size()
        let rect = NSRect(
            x: x, y: ((bounds.height - size.height) / 2).rounded() + dy,
            width: min(ceil(size.width), maxWidth), height: size.height
        )
        string.draw(in: rect)
        return rect
    }

    func drawSymbol(_ name: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(.init(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let origin = NSPoint(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2)
        image.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    }

    static func width(of text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// One service: `:4178   tools/admin-gallery            Vite ›`.
/// While highlighted, copy and open icons replace the kind.
final class ServiceRowView: HighlightView {
    static let menuFont = NSFont.menuFont(ofSize: 0)
    static let portFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let portWidth = HighlightView.width(of: ":00000", font: portFont) + 10
    static let maxTitleWidth: CGFloat = 280
    static let chevronSpace: CGFloat = 18
    static let iconSize: CGFloat = 16

    let row: Row
    var onOpen: () -> Void = {}
    var onCopy: () -> Void = {}
    private var showsCopied = false

    init(row: Row) {
        self.row = row
        super.init(frame: NSRect(x: 0, y: 0, width: Self.fittingWidth(row), height: Self.height))
        toolTip = row.service.commandLine
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel("Port \(row.service.port), \(row.title), \(row.kind)")
    }

    required init?(coder: NSCoder) { fatalError() }

    static func fittingWidth(_ row: Row) -> CGFloat {
        let title = min(width(of: row.title, font: menuFont), maxTitleWidth)
        let right = max(width(of: row.kind, font: menuFont), iconSize * 2 + 8)
        return inset + portWidth + title + 28 + right + chevronSpace + inset
    }

    private var rightEdge: CGFloat { bounds.width - Self.inset - Self.chevronSpace }
    private var openRect: NSRect {
        NSRect(x: rightEdge - Self.iconSize, y: (bounds.height - Self.iconSize) / 2, width: Self.iconSize, height: Self.iconSize)
    }
    private var copyRect: NSRect { openRect.offsetBy(dx: -(Self.iconSize + 8), dy: 0) }

    override func drawContent() {
        draw(":\(row.service.port)", font: Self.portFont, color: textColor, x: Self.inset - 1.5)
        let titleX = Self.inset + Self.portWidth
        let rightWidth = max(Self.width(of: row.kind, font: Self.menuFont), Self.iconSize * 2 + 8)
        draw(row.title, font: Self.menuFont, color: textColor, x: titleX, maxWidth: rightEdge - rightWidth - 12 - titleX)

        if showsCopied {
            let width = Self.width(of: "Copied", font: Self.menuFont)
            draw("Copied", font: Self.menuFont, color: textColor, x: rightEdge - width)
        } else if isHighlighted {
            drawSymbol("doc.on.doc", in: copyRect, size: 12, color: textColor)
            drawSymbol("arrow.up.right.square", in: openRect, size: 12, color: textColor)
        } else {
            let width = Self.width(of: row.kind, font: Self.menuFont)
            draw(row.kind, font: Self.menuFont, color: dimColor, x: rightEdge - width)
        }
        let chevron = NSRect(x: bounds.width - Self.inset - 8, y: (bounds.height - 12) / 2, width: 10, height: 12)
        drawSymbol("chevron.right", in: chevron, size: 9, weight: .semibold, color: dimColor)
    }

    override func mouseUp(with event: NSEvent) {
        guard !showsCopied else { return }
        let point = convert(event.locationInWindow, from: nil)
        if copyRect.insetBy(dx: -4, dy: -3).contains(point) {
            copyAndClose()
        } else {
            enclosingMenuItem?.menu?.cancelTracking()
            onOpen()
        }
    }

    /// Shows "Copied" on the row for a moment, then closes the menu.
    private func copyAndClose() {
        onCopy()
        showsCopied = true
        isHighlighted = true  // redraws
        let timer = Timer(timeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.enclosingMenuItem?.menu?.cancelTracking()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}

/// The "Hidden" section header. Clicking it shows or hides that section's rows
/// while the menu stays open.
final class DisclosureHeaderView: HighlightView {
    static let font = NSFont.systemFont(ofSize: 11, weight: .semibold)

    let count: Int
    var isExpanded: Bool { didSet { isHighlighted = isHovered } }  // redraws
    /// Its item has no action, so the menu never highlights it; the view tracks the pointer.
    private var isHovered = false { didSet { isHighlighted = isHovered } }
    var onClick: () -> Void = {}

    init(count: Int, isExpanded: Bool) {
        self.count = count
        self.isExpanded = isExpanded
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: Self.height))
        showsSelection = false
        setAccessibilityElement(true)
        setAccessibilityRole(.disclosureTriangle)
        setAccessibilityLabel("\(count) hidden")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func drawContent() {
        // Sits low in its row and uses the same grey as AppKit's section headers.
        let color: NSColor = isHovered ? .labelColor : .disabledControlTextColor
        draw("Hidden", font: Self.font, color: color, x: Self.inset - 1, dy: -3)
        let chevron = NSRect(x: bounds.width - Self.inset - 8, y: (bounds.height - 12) / 2 - 3, width: 10, height: 12)
        let accessory: NSColor = isHovered ? .labelColor : .secondaryLabelColor
        drawSymbol(isExpanded ? "chevron.down" : "chevron.right", in: chevron, size: 9, weight: .semibold, color: accessory)
        if !isExpanded {
            let text = "\(count)"
            draw(text, font: Self.font, color: accessory, x: chevron.minX - 6 - Self.width(of: text, font: Self.font), dy: -3)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    // Acts on the press, like a disclosure triangle, and swallows the release.
    override func mouseDown(with event: NSEvent) { onClick() }
    override func mouseUp(with event: NSEvent) {}
    override func accessibilityPerformPress() -> Bool { onClick(); return true }
}

/// A menu item that runs a closure.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
