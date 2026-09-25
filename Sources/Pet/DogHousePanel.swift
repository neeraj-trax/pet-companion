import AppKit

/// A small, persistent place for the dog to rest. The empty house is click-through;
/// while occupied, one click on the visible dog wakes him.
final class DogHousePanel: NSPanel {
    static let size = CGSize(width: 150, height: 142)
    private let house = DogHouseView(frame: CGRect(origin: .zero, size: size))
    var onWake: (() -> Void)?

    var occupied: Bool {
        get { house.occupied }
        set {
            house.occupied = newValue
            ignoresMouseEvents = !newValue
        }
    }
    var dropHighlighted: Bool {
        get { house.dropHighlighted }
        set { house.dropHighlighted = newValue }
    }
    var coat: Coat {
        get { house.coat }
        set { house.coat = newValue }
    }

    init() {
        super.init(contentRect: CGRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        house.onWake = { [weak self] in self?.onWake?() }
        contentView = house
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(in visibleFrame: CGRect) {
        setFrameOrigin(CGPoint(x: (visibleFrame.maxX - Self.size.width - 10).rounded(),
                               y: (visibleFrame.minY + 4).rounded()))
    }

    func acceptsDrop(at pointer: CGPoint, dogRect: CGRect) -> Bool {
        let target = frame.insetBy(dx: -12, dy: -10)
        if target.contains(pointer) { return true }
        let overlap = target.intersection(dogRect)
        return !overlap.isNull && overlap.width > 45 && overlap.height > 45
    }

    func tick(time: TimeInterval) {
        if occupied { house.sleepPhase = CGFloat(time) }
    }
}

final class DogHouseView: NSView {
    var occupied = false { didSet { needsDisplay = true } }
    var dropHighlighted = false { didSet { needsDisplay = true } }
    var coat: Coat = .hojiro { didSet { needsDisplay = true } }
    var sleepPhase: CGFloat = 0 { didSet { needsDisplay = true } }
    var onWake: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if occupied { onWake?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.interpolationQuality = .high
        let dark = NSColor(red: 0.26, green: 0.20, blue: 0.18, alpha: 1)
        let wood = NSColor(red: 0.88, green: 0.70, blue: 0.49, alpha: 1)
        let roof = dropHighlighted
            ? NSColor(red: 0.86, green: 0.58, blue: 0.32, alpha: 1)
            : NSColor(red: 0.73, green: 0.43, blue: 0.31, alpha: 1)

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
        ctx.fillEllipse(in: CGRect(x: 13, y: 4, width: 126, height: 12))

        let walls = CGPath(roundedRect: CGRect(x: 22, y: 12, width: 106, height: 91),
                           cornerWidth: 9, cornerHeight: 9, transform: nil)
        ctx.addPath(walls); ctx.setFillColor(wood.cgColor); ctx.fillPath()
        ctx.addPath(walls); ctx.setStrokeColor(dark.cgColor); ctx.setLineWidth(2.5); ctx.strokePath()

        // The doorway masks the standing sprite, leaving only the sleeping face
        // visible. The current coat is taken from the same atlas as the live dog.
        let door = CGMutablePath()
        door.move(to: CGPoint(x: 43, y: 13))
        door.addLine(to: CGPoint(x: 43, y: 60))
        door.addCurve(to: CGPoint(x: 107, y: 60), control1: CGPoint(x: 43, y: 104), control2: CGPoint(x: 107, y: 104))
        door.addLine(to: CGPoint(x: 107, y: 13))
        door.closeSubpath()
        ctx.addPath(door)
        ctx.setFillColor(NSColor(red: 0.31, green: 0.25, blue: 0.23, alpha: 1).cgColor)
        ctx.fillPath()
        if occupied, let atlas = SpriteAtlas.image(for: coat),
           let blink = atlas.cropping(to: SpriteAtlas.rect(of: SpriteFrame(row: 0, col: 1))) {
            ctx.saveGState()
            ctx.addPath(door); ctx.clip()
            ctx.draw(blink, in: CGRect(x: 16, y: -19, width: 119, height: 129))
            ctx.restoreGState()
        }
        ctx.addPath(door); ctx.setStrokeColor(dark.cgColor); ctx.setLineWidth(2.5); ctx.strokePath()

        // A small sill makes the rest of the body feel tucked inside the house.
        let sill = CGPath(roundedRect: CGRect(x: 39, y: 11, width: 72, height: 18),
                          cornerWidth: 5, cornerHeight: 5, transform: nil)
        ctx.addPath(sill); ctx.setFillColor(NSColor(red: 0.68, green: 0.48, blue: 0.33, alpha: 1).cgColor); ctx.fillPath()
        ctx.addPath(sill); ctx.setStrokeColor(dark.cgColor); ctx.setLineWidth(2); ctx.strokePath()

        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: 11, y: 94))
        roofPath.addLine(to: CGPoint(x: 68, y: 133))
        roofPath.addQuadCurve(to: CGPoint(x: 82, y: 133), control: CGPoint(x: 75, y: 139))
        roofPath.addLine(to: CGPoint(x: 139, y: 94))
        roofPath.addLine(to: CGPoint(x: 134, y: 87))
        roofPath.addLine(to: CGPoint(x: 75, y: 125))
        roofPath.addLine(to: CGPoint(x: 16, y: 87))
        roofPath.closeSubpath()
        ctx.addPath(roofPath); ctx.setFillColor(roof.cgColor); ctx.fillPath()
        ctx.addPath(roofPath); ctx.setStrokeColor(dark.cgColor); ctx.setLineWidth(2.5)
        ctx.setLineJoin(.round); ctx.strokePath()

        if occupied {
            for (index, mark) in ["z", "Z", "Z"].enumerated() {
                let i = CGFloat(index)
                let rise = 2 * sin(sleepPhase * 1.4 - i * 0.6)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10 + i * 3, weight: .semibold),
                    .foregroundColor: NSColor(red: 0.42, green: 0.39, blue: 0.60,
                                              alpha: 0.65 + i * 0.12)
                ]
                (mark as NSString).draw(at: CGPoint(x: 101 + i * 13, y: 79 + i * 20 + rise),
                                        withAttributes: attrs)
            }
        }
        ctx.restoreGState()
    }
}

enum DogHousePreview {
    static func render(to url: URL) {
        let view = DogHouseView(frame: CGRect(origin: .zero, size: DogHousePanel.size))
        view.occupied = true
        view.coat = .hojiro
        view.sleepPhase = 0.5
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
