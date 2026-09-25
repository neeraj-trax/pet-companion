import AppKit

// Three small, flat dog-house studies using the production dog's closed-eye frame.
// Run: swift Tools/render-house-concepts.swift Assets/pet-dog-atlas.png Assets/dog-house-concepts.png

private let ink = NSColor(red: 0.11, green: 0.14, blue: 0.18, alpha: 1)
private let doorway = NSColor(red: 0.20, green: 0.25, blue: 0.29, alpha: 1)

private func fillStroke(_ ctx: CGContext, _ path: CGPath, fill: NSColor, width: CGFloat = 2.6) {
    ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    ctx.addPath(path); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(width)
    ctx.setLineJoin(.round); ctx.setLineCap(.round); ctx.strokePath()
}

private func archedDoor(x: CGFloat = 43, top: CGFloat = 90, width: CGFloat = 64) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: 13))
    p.addLine(to: CGPoint(x: x, y: top - 29))
    p.addCurve(to: CGPoint(x: x + width, y: top - 29),
               control1: CGPoint(x: x, y: top + 10), control2: CGPoint(x: x + width, y: top + 10))
    p.addLine(to: CGPoint(x: x + width, y: 13))
    p.closeSubpath()
    return p
}

private func drawDog(_ ctx: CGContext, blink: CGImage, door: CGPath) {
    ctx.addPath(door); ctx.setFillColor(doorway.cgColor); ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(door); ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(blink, in: CGRect(x: 16, y: -19, width: 119, height: 129))
    ctx.restoreGState()
    ctx.addPath(door); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(2.6); ctx.strokePath()
}

private func drawSill(_ ctx: CGContext, color: NSColor) {
    let sill = CGPath(roundedRect: CGRect(x: 39, y: 11, width: 72, height: 17),
                      cornerWidth: 7, cornerHeight: 7, transform: nil)
    fillStroke(ctx, sill, fill: color, width: 2.4)
}

private func drawSleep(_ ctx: CGContext) {
    for (index, mark) in ["z", "Z", "Z"].enumerated() {
        let i = CGFloat(index)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10 + i * 3, weight: .semibold),
            .foregroundColor: NSColor(red: 0.38, green: 0.37, blue: 0.58, alpha: 1)
        ]
        (mark as NSString).draw(at: CGPoint(x: 101 + i * 13, y: 79 + i * 20), withAttributes: attrs)
    }
}

private func drawHouse(_ ctx: CGContext, style: Int, blink: CGImage) {
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.10).cgColor)
    ctx.fillEllipse(in: CGRect(x: 11, y: 4, width: 128, height: 12))

    switch style {
    case 0: // Classic cottage: warm and familiar, with a simpler rounded roof.
        let wallColor = NSColor(red: 0.96, green: 0.83, blue: 0.63, alpha: 1)
        let wall = CGPath(roundedRect: CGRect(x: 22, y: 12, width: 106, height: 91),
                          cornerWidth: 11, cornerHeight: 11, transform: nil)
        fillStroke(ctx, wall, fill: wallColor)
        let gable = CGMutablePath()
        gable.move(to: CGPoint(x: 21, y: 98))
        gable.addLine(to: CGPoint(x: 75, y: 128))
        gable.addLine(to: CGPoint(x: 129, y: 98))
        gable.closeSubpath()
        ctx.addPath(gable); ctx.setFillColor(wallColor.cgColor); ctx.fillPath()
        drawDog(ctx, blink: blink, door: archedDoor())
        drawSill(ctx, color: NSColor(red: 0.76, green: 0.54, blue: 0.39, alpha: 1))
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: 10, y: 92))
        roof.addLine(to: CGPoint(x: 69, y: 133))
        roof.addQuadCurve(to: CGPoint(x: 81, y: 133), control: CGPoint(x: 75, y: 138))
        roof.addLine(to: CGPoint(x: 140, y: 92))
        roof.addLine(to: CGPoint(x: 134, y: 84))
        roof.addLine(to: CGPoint(x: 75, y: 123))
        roof.addLine(to: CGPoint(x: 16, y: 84))
        roof.closeSubpath()
        fillStroke(ctx, roof, fill: NSColor(red: 0.88, green: 0.54, blue: 0.42, alpha: 1))
    case 1: // Pebble: a softer rounded silhouette echoing the dog's ears.
        let wall = CGPath(roundedRect: CGRect(x: 19, y: 12, width: 112, height: 114),
                          cornerWidth: 37, cornerHeight: 37, transform: nil)
        fillStroke(ctx, wall, fill: NSColor(red: 0.87, green: 0.89, blue: 0.76, alpha: 1))
        drawDog(ctx, blink: blink, door: archedDoor(x: 44, top: 91, width: 62))
        drawSill(ctx, color: NSColor(red: 0.70, green: 0.78, blue: 0.67, alpha: 1))
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: 15, y: 85))
        cap.addCurve(to: CGPoint(x: 135, y: 85),
                     control1: CGPoint(x: 20, y: 149), control2: CGPoint(x: 130, y: 149))
        cap.addLine(to: CGPoint(x: 128, y: 77))
        cap.addCurve(to: CGPoint(x: 22, y: 77),
                     control1: CGPoint(x: 120, y: 129), control2: CGPoint(x: 30, y: 129))
        cap.closeSubpath()
        fillStroke(ctx, cap, fill: NSColor(red: 0.60, green: 0.74, blue: 0.70, alpha: 1))
    default: // A-frame: a sheltered nook with the same bold, simple outline.
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: 9, y: 17))
        roof.addLine(to: CGPoint(x: 68, y: 133))
        roof.addQuadCurve(to: CGPoint(x: 82, y: 133), control: CGPoint(x: 75, y: 139))
        roof.addLine(to: CGPoint(x: 141, y: 17))
        roof.closeSubpath()
        fillStroke(ctx, roof, fill: NSColor(red: 0.84, green: 0.62, blue: 0.40, alpha: 1))
        let front = CGMutablePath()
        front.move(to: CGPoint(x: 25, y: 15))
        front.addLine(to: CGPoint(x: 75, y: 113))
        front.addLine(to: CGPoint(x: 125, y: 15))
        front.closeSubpath()
        fillStroke(ctx, front, fill: NSColor(red: 0.98, green: 0.88, blue: 0.70, alpha: 1))
        drawDog(ctx, blink: blink, door: archedDoor(x: 45, top: 86, width: 60))
        drawSill(ctx, color: NSColor(red: 0.79, green: 0.65, blue: 0.45, alpha: 1))
        ctx.move(to: CGPoint(x: 9, y: 17)); ctx.addLine(to: CGPoint(x: 75, y: 133))
        ctx.addLine(to: CGPoint(x: 141, y: 17))
        ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(4); ctx.setLineJoin(.round); ctx.strokePath()
    }
    drawSleep(ctx)
}

final class HouseConceptSheet: NSView {
    let blink: CGImage
    init(frame: CGRect, blink: CGImage) { self.blink = blink; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(red: 0.985, green: 0.977, blue: 0.954, alpha: 1).cgColor)
        ctx.fill(bounds)
        let titles = ["1  Cozy cottage", "2  Pebble house", "3  A-frame nook"]
        let captions = ["Warm, familiar", "Soft and rounded", "Quiet little shelter"]
        for style in 0..<3 {
            let x = CGFloat(style) * 226 + 22
            let card = CGPath(roundedRect: CGRect(x: x, y: 17, width: 208, height: 231),
                              cornerWidth: 18, cornerHeight: 18, transform: nil)
            ctx.addPath(card)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillPath()
            ctx.addPath(card)
            ctx.setStrokeColor(NSColor(red: 0.88, green: 0.85, blue: 0.80, alpha: 1).cgColor)
            ctx.setLineWidth(1); ctx.strokePath()
            ctx.saveGState()
            ctx.translateBy(x: x + 29, y: 70)
            drawHouse(ctx, style: style, blink: blink)
            ctx.restoreGState()
            (titles[style] as NSString).draw(at: CGPoint(x: x + 16, y: 43), withAttributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: ink
            ])
            (captions[style] as NSString).draw(at: CGPoint(x: x + 16, y: 24), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray
            ])
        }
    }
}

guard CommandLine.arguments.count == 3,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let atlas = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let blink = atlas.cropping(to: CGRect(x: 192, y: 0, width: 192, height: 208)) else {
    fputs("usage: swift render-house-concepts.swift atlas.png output.png\n", stderr)
    exit(1)
}

_ = NSApplication.shared
let view = HouseConceptSheet(frame: CGRect(x: 0, y: 0, width: 722, height: 265), blink: blink)
let scale: CGFloat = 2
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = view.bounds.size
view.cacheDisplay(in: view.bounds, to: rep)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
