import AppKit

/// A small cushion in the screen corner. The empty bed is click-through;
/// one click on the sleeping dog brings him back out.
final class DogBedPanel: NSPanel {
    static let size = CGSize(width: 174, height: 118)
    private let bed = DogBedView(frame: CGRect(origin: .zero, size: size))
    var onWake: (() -> Void)?

    var occupied: Bool {
        get { bed.occupied }
        set {
            bed.occupied = newValue
            ignoresMouseEvents = !newValue
        }
    }
    var dropHighlighted: Bool {
        get { bed.dropHighlighted }
        set { bed.dropHighlighted = newValue }
    }
    var coat: Coat {
        get { bed.coat }
        set { bed.coat = newValue }
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
        bed.onWake = { [weak self] in self?.onWake?() }
        contentView = bed
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(in visibleFrame: CGRect) {
        setFrameOrigin(CGPoint(x: (visibleFrame.maxX - Self.size.width - 10).rounded(),
                               y: (visibleFrame.minY + 4).rounded()))
    }

    func acceptsDrop(at pointer: CGPoint, dogRect: CGRect) -> Bool {
        let target = frame.insetBy(dx: -14, dy: -12)
        if target.contains(pointer) { return true }
        let overlap = target.intersection(dogRect)
        return !overlap.isNull && overlap.width > 45 && overlap.height > 35
    }

    func tick(time: TimeInterval) {
        if occupied { bed.sleepPhase = CGFloat(time) }
    }
}

final class DogBedView: NSView {
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
        let ink = NSColor(red: 0.13, green: 0.17, blue: 0.21, alpha: 1)
        let bolster = dropHighlighted
            ? NSColor(red: 0.95, green: 0.72, blue: 0.61, alpha: 1)
            : NSColor(red: 0.89, green: 0.67, blue: 0.59, alpha: 1)
        let inside = NSColor(red: 0.98, green: 0.87, blue: 0.81, alpha: 1)

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.11).cgColor)
        ctx.fillEllipse(in: CGRect(x: 13, y: 3, width: 148, height: 13))

        // One plump outline, with a softer inset where the dog curls up.
        let cushion = CGMutablePath()
        cushion.move(to: CGPoint(x: 10, y: 32))
        cushion.addCurve(to: CGPoint(x: 39, y: 70), control1: CGPoint(x: 9, y: 51), control2: CGPoint(x: 21, y: 68))
        cushion.addCurve(to: CGPoint(x: 132, y: 70), control1: CGPoint(x: 63, y: 78), control2: CGPoint(x: 111, y: 78))
        cushion.addCurve(to: CGPoint(x: 164, y: 32), control1: CGPoint(x: 153, y: 68), control2: CGPoint(x: 165, y: 51))
        cushion.addCurve(to: CGPoint(x: 134, y: 13), control1: CGPoint(x: 165, y: 17), control2: CGPoint(x: 154, y: 11))
        cushion.addCurve(to: CGPoint(x: 40, y: 13), control1: CGPoint(x: 110, y: 9), control2: CGPoint(x: 64, y: 9))
        cushion.addCurve(to: CGPoint(x: 10, y: 32), control1: CGPoint(x: 20, y: 11), control2: CGPoint(x: 9, y: 17))
        cushion.closeSubpath()
        ctx.addPath(cushion); ctx.setFillColor(bolster.cgColor); ctx.fillPath()
        ctx.addPath(cushion); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(2.5); ctx.strokePath()

        let inset = CGMutablePath()
        inset.move(to: CGPoint(x: 25, y: 39))
        inset.addCurve(to: CGPoint(x: 55, y: 58), control1: CGPoint(x: 26, y: 50), control2: CGPoint(x: 38, y: 57))
        inset.addCurve(to: CGPoint(x: 122, y: 58), control1: CGPoint(x: 74, y: 63), control2: CGPoint(x: 105, y: 63))
        inset.addCurve(to: CGPoint(x: 149, y: 39), control1: CGPoint(x: 139, y: 57), control2: CGPoint(x: 149, y: 50))
        inset.addCurve(to: CGPoint(x: 87, y: 26), control1: CGPoint(x: 143, y: 25), control2: CGPoint(x: 111, y: 26))
        inset.addCurve(to: CGPoint(x: 25, y: 39), control1: CGPoint(x: 61, y: 26), control2: CGPoint(x: 31, y: 25))
        inset.closeSubpath()
        ctx.addPath(inset); ctx.setFillColor(inside.cgColor); ctx.fillPath()
        ctx.addPath(inset); ctx.setStrokeColor(ink.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1.4); ctx.strokePath()

        if occupied, let atlas = SpriteAtlas.image(for: coat),
           let nap = atlas.cropping(to: SpriteAtlas.rect(of: SpriteFrame(row: 5, col: 1))) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 12, y: 13, width: 150, height: 100))
            ctx.draw(nap, in: CGRect(x: 29, y: -15, width: 116, height: 126))
            ctx.restoreGState()
        }

        // The front pillow edge overlaps the sprite a little so it feels nested.
        let lip = CGMutablePath()
        lip.move(to: CGPoint(x: 17, y: 32))
        lip.addCurve(to: CGPoint(x: 157, y: 32), control1: CGPoint(x: 45, y: 16), control2: CGPoint(x: 129, y: 16))
        lip.addCurve(to: CGPoint(x: 132, y: 12), control1: CGPoint(x: 160, y: 19), control2: CGPoint(x: 149, y: 12))
        lip.addCurve(to: CGPoint(x: 42, y: 12), control1: CGPoint(x: 108, y: 9), control2: CGPoint(x: 66, y: 9))
        lip.addCurve(to: CGPoint(x: 17, y: 32), control1: CGPoint(x: 25, y: 12), control2: CGPoint(x: 14, y: 19))
        lip.closeSubpath()
        ctx.addPath(lip)
        ctx.setFillColor(NSColor(red: 0.83, green: 0.57, blue: 0.51, alpha: 1).cgColor)
        ctx.fillPath()
        ctx.addPath(lip); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(2.2); ctx.strokePath()

        if occupied {
            for (index, mark) in ["z", "Z", "Z"].enumerated() {
                let i = CGFloat(index)
                let rise = 2 * sin(sleepPhase * 1.3 - i * 0.6)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10 + i * 3, weight: .semibold),
                    .foregroundColor: NSColor(red: 0.43, green: 0.42, blue: 0.61, alpha: 0.66 + i * 0.11)
                ]
                (mark as NSString).draw(at: CGPoint(x: 119 + i * 14, y: 65 + i * 18 + rise),
                                        withAttributes: attrs)
            }
        }
        ctx.restoreGState()
    }
}

enum DogBedPreview {
    static func render(to url: URL, occupied: Bool = true) {
        let view = DogBedView(frame: CGRect(origin: .zero, size: DogBedPanel.size))
        view.occupied = occupied
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
