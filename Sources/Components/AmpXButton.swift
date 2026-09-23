import AppKit
import CoreGraphics

final class AmpXButton: AmpXControlView {
    enum Style {
        case bevel
        case menu
    }

    var action: (() -> Void)?
    var isActive = false {
        didSet { needsDisplay = true }
    }

    var label: String? {
        didSet { needsDisplay = true }
    }

    var icon: AmpXIcon? {
        didSet { needsDisplay = true }
    }

    var iconColor: NSColor? {
        didSet { needsDisplay = true }
    }

    var showsActiveIndicator = false {
        didSet { needsDisplay = true }
    }

    /// Active state is shown as a depressed face (e.g. Play while playing).
    var showsActiveFace = false {
        didSet { needsDisplay = true }
    }

    var style: Style = .bevel {
        didSet { needsDisplay = true }
    }

    /// Measured content layout in bounds coordinates; `nil` values center the content.
    var labelBaselineOrigin: CGPoint? {
        didSet { needsDisplay = true }
    }

    var labelFontSize: CGFloat? {
        didSet { needsDisplay = true }
    }

    var labelWeight: NSFont.Weight = .semibold {
        didSet { needsDisplay = true }
    }

    var iconRect: CGRect? {
        didSet { needsDisplay = true }
    }

    var indicatorRect: CGRect? {
        didSet { needsDisplay = true }
    }

    /// Glyph ink while active; defaults to `faceGreen` (`green` on the pressed face).
    var activeIconColor: NSColor? {
        didSet { needsDisplay = true }
    }

    /// Lit-lamp green; also the ink for active glyphs that should read like a lit lamp.
    static let lampGreen = NSColor(srgbRed: 0.28, green: 0.94, blue: 0.20, alpha: 1)

    /// Display-only active state for deterministic reference presentation.
    var displayActiveOverride: Bool? {
        didSet { needsDisplay = true }
    }

    var accessibilityTitle: String?

    private(set) var isPressed = false {
        didSet { needsDisplay = true }
    }

    private var pressResetWorkItem: DispatchWorkItem?

    override init(skin: any AmpXSkin) {
        super.init(skin: skin)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var displaysActive: Bool {
        self.displayActiveOverride ?? self.isActive
    }

    /// Glyph and label ink: dark on steel faces, light on the orange menu face.
    private var inkColor: NSColor {
        self.style == .menu ? skin.text : skin.faceInk
    }

    private var dimInkColor: NSColor {
        self.style == .menu ? skin.textDim : skin.faceInkDim
    }

    private var labelLines: [String] {
        self.label?.components(separatedBy: "\n") ?? []
    }

    var labelFont: NSFont {
        skin.font(size: self.labelFontSize ?? (self.labelLines.count > 1 ? 7 : 8), weight: self.labelWeight)
    }

    /// Typographic box of the label lines; never narrower than one line height.
    var labelRect: CGRect {
        let font = self.labelFont
        let lineHeight = font.ascender - font.descender
        let blockHeight = lineHeight * CGFloat(max(self.labelLines.count, 1))
        let width = self.labelLines.map { self.measuredWidth(of: $0) }.max() ?? 0
        if let origin = labelBaselineOrigin {
            return CGRect(x: origin.x, y: origin.y - font.ascender, width: width, height: blockHeight)
        }
        let height = min(blockHeight, bounds.height)
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    var resolvedIconRect: CGRect {
        if let iconRect {
            return iconRect
        }
        let area = bounds.insetBy(dx: 8, dy: 8)
        return area.insetBy(dx: area.width * 0.28, dy: area.height * 0.28)
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        let faceStyle: AmpXFaceStyle = switch self.style {
        case .menu: .menu
        case .bevel where self.isPressed || (self.showsActiveFace && self.displaysActive): .pressed
        case .bevel where isHovered && isEnabled: .hovered
        case .bevel: .normal
        }
        skin.raisedFace(bounds, style: faceStyle, in: context, backingScale: backingScale)
        if self.style == .menu, self.isPressed {
            context.setFillColor(skin.borderDark.withAlphaComponent(0.25).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if !isEnabled {
            context.setFillColor(skin.background.withAlphaComponent(0.35).cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
        }

        if self.label != nil {
            self.drawLabel(in: context)
        }

        if let icon {
            // Bright green reads on the darker pressed face; light steel needs the deep variant.
            let activeTint = self.activeIconColor ?? (faceStyle == .pressed ? skin.green : skin.faceGreen)
            let tint = self.pressedAccent(for: self.iconColor, faceStyle: faceStyle)
                ?? (self.displaysActive ? activeTint : self.inkColor)
            icon.draw(in: self.resolvedIconRect, context: context, skin: skin, color: isEnabled ? tint : self.dimInkColor)
        }

        if self.showsActiveIndicator {
            self.drawIndicator(in: context)
        }

        drawFocusRing(in: context, backingScale: backingScale)
    }

    /// Deep accent inks (`faceGreen`, `faceAmber`) are tuned for light steel and drop to ~2:1 on the
    /// darker pressed face; swap them for their bright counterparts there (≥3:1), like active glyphs.
    func pressedAccent(for color: NSColor?, faceStyle: AmpXFaceStyle) -> NSColor? {
        guard faceStyle == .pressed, let color else { return color }
        if color == skin.faceGreen { return skin.green }
        if color == skin.faceAmber { return skin.yellow }
        return color
    }

    private func drawLabel(in context: CGContext) {
        let font = self.labelFont
        let color = isEnabled ? self.inkColor : self.dimInkColor
        let rect = self.labelRect
        let lineHeight = font.ascender - font.descender
        for (index, line) in self.labelLines.enumerated() {
            let baseline = rect.minY + font.ascender + CGFloat(index) * lineHeight
            if self.labelBaselineOrigin != nil {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: self.labelWeight)
                    .draw(x: rect.minX, baseline: baseline, context: context, skin: skin)
            } else {
                AmpXLabel(text: line, color: color, fontSize: font.pointSize, weight: self.labelWeight, alignment: .center)
                    .draw(x: bounds.midX, baseline: baseline, context: context, skin: skin)
            }
        }
    }

    private func drawIndicator(in context: CGContext) {
        guard let lamp = indicatorRect else {
            let indicator = CGRect(x: bounds.maxX - 7, y: bounds.midY - 2, width: 4, height: 4)
            context.setFillColor((self.displaysActive ? skin.green : skin.textDim).cgColor)
            context.fill(indicator)
            return
        }

        guard self.displaysActive else {
            self.drawInactiveLamp(in: lamp, context: context)
            return
        }
        context.setFillColor(NSColor(srgbRed: 0.02, green: 0.05, blue: 0.04, alpha: 1).cgColor)
        context.fill(lamp)
        let inner = lamp.insetBy(dx: 1, dy: 1)
        context.setFillColor(NSColor(srgbRed: 0.10, green: 0.78, blue: 0.08, alpha: 1).cgColor)
        context.fill(inner)
        context.setFillColor(Self.lampGreen.cgColor)
        context.fill(inner.insetBy(dx: 0.5, dy: 0.5))
        context.setFillColor(NSColor(srgbRed: 0.62, green: 1, blue: 0.52, alpha: 1).cgColor)
        context.fill(CGRect(x: inner.minX + 0.5, y: inner.minY + 0.5, width: inner.width - 1, height: 0.5))
    }

    /// Unlit lamp: a grey square with the lit lamp's dark rim and footprint, so toggling only changes color.
    private func drawInactiveLamp(in lamp: CGRect, context: CGContext) {
        context.setFillColor(NSColor(srgbRed: 8 / 255, green: 15 / 255, blue: 28 / 255, alpha: 1).cgColor)
        context.fill(lamp)
        let inner = lamp.insetBy(dx: 1, dy: 1)
        context.saveGState()
        context.clip(to: inner)
        if let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [
                NSColor(srgbRed: 104 / 255, green: 117 / 255, blue: 139 / 255, alpha: 1).cgColor,
                NSColor(srgbRed: 150 / 255, green: 163 / 255, blue: 183 / 255, alpha: 1).cgColor,
                NSColor(srgbRed: 170 / 255, green: 183 / 255, blue: 200 / 255, alpha: 1).cgColor,
            ] as CFArray,
            locations: [0, 0.6, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: inner.minX, y: inner.minY),
                end: CGPoint(x: inner.maxX, y: inner.maxY),
                options: []
            )
        }
        context.restoreGState()
    }

    private func measuredWidth(of text: String) -> CGFloat {
        AmpXLabel(text: text, color: skin.text, fontSize: self.labelFont.pointSize, weight: self.labelWeight)
            .measuredSize(skin: skin).width
    }

    override func mouseDown(with _: NSEvent) {
        guard isEnabled else { return }
        self.pressResetWorkItem?.cancel()
        self.pressResetWorkItem = nil
        self.isPressed = true
    }

    override func cancelInteraction() {
        self.pressResetWorkItem?.cancel()
        self.pressResetWorkItem = nil
        self.isPressed = false
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let shouldFire = self.isPressed && isEnabled && bounds.contains(point)
        if shouldFire {
            self.action?()
            self.schedulePressReset()
        } else {
            self.isPressed = false
        }
    }

    /// Presses the button from the keyboard (Return/Enter while focused). Space stays global play/pause.
    @discardableResult
    func performKeyboardPress() -> Bool {
        guard isEnabled else { return false }
        self.action?()
        self.isPressed = true
        self.schedulePressReset()
        return true
    }

    override func accessibilityLabel() -> String? {
        self.accessibilityTitle ?? self.label ?? super.accessibilityLabel()
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        self.action?()
        self.isPressed = true
        self.schedulePressReset()
        return true
    }

    private func schedulePressReset() {
        self.pressResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isPressed = false
        }
        self.pressResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AmpXControlMath.buttonPressDuration, execute: work)
    }
}
