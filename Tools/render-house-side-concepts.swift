import AppKit

// Side-turned dog-house studies. Uses the same closed-eye dog atlas frame as the live house.
// Run: swift Tools/render-house-side-concepts.swift Assets/pet-dog-atlas.png Assets/dog-house-side-concepts.png

private let ink = NSColor(red: 0.11, green: 0.14, blue: 0.18, alpha: 1)
private let doorDark = NSColor(red: 0.20, green: 0.25, blue: 0.29, alpha: 1)

private func path(_ points: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let first = points.first else { return p }
    p.move(to: first)
    for point in points.dropFirst() { p.addLine(to: point) }
    p.closeSubpath()
    return p
}

private func fillStroke(_ ctx: CGContext, _ p: CGPath, _ fill: NSColor, width: CGFloat = 2.5) {
    ctx.addPath(p); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    ctx.addPath(p); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(width)
    ctx.setLineJoin(.round); ctx.setLineCap(.round); ctx.strokePath()
}

private func entrance(x: CGFloat, width: CGFloat, top: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: 18))
    p.addLine(to: CGPoint(x: x, y: top - 23))
    p.addCurve(to: CGPoint(x: x + width, y: top - 23),
               control1: CGPoint(x: x, y: top + 9), control2: CGPoint(x: x + width, y: top + 9))
    p.addLine(to: CGPoint(x: x + width, y: 18))
    p.closeSubpath()
    return p
}

private func sleepyDog(_ ctx: CGContext, cell: CGImage, door: CGPath) {
    ctx.addPath(door); ctx.setFillColor(doorDark.cgColor); ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(door); ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(cell, in: CGRect(x: door.boundingBox.midX - 48, y: -4, width: 96, height: 104))
    ctx.restoreGState()
    ctx.addPath(door); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(2.5); ctx.strokePath()
}

private func sill(_ ctx: CGContext, x: CGFloat, width: CGFloat, fill: NSColor) {
    fillStroke(ctx, CGPath(roundedRect: CGRect(x: x, y: 15, width: width, height: 14),
                           cornerWidth: 6, cornerHeight: 6, transform: nil), fill, width: 2.2)
}

private func sleepMarks() {
    let marks = [("z", 143.0, 91.0, 10.0), ("Z", 155.0, 110.0, 13.0), ("Z", 169.0, 129.0, 16.0)]
    for (mark, x, y, size) in marks {
        (mark as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor(red: 0.39, green: 0.38, blue: 0.59, alpha: 1)
        ])
    }
}

private func drawCottage(_ ctx: CGContext, dog: CGImage) {
    let warm = NSColor(red: 0.96, green: 0.83, blue: 0.63, alpha: 1)
    fillStroke(ctx, path([CGPoint(x: 15, y: 28), CGPoint(x: 96, y: 19),
                          CGPoint(x: 96, y: 100), CGPoint(x: 15, y: 106)]),
               NSColor(red: 0.89, green: 0.72, blue: 0.52, alpha: 1))
    fillStroke(ctx, path([CGPoint(x: 96, y: 19), CGPoint(x: 177, y: 19),
                          CGPoint(x: 177, y: 100), CGPoint(x: 137, y: 127), CGPoint(x: 96, y: 100)]), warm)
    let door = entrance(x: 112, width: 51, top: 84)
    sleepyDog(ctx, cell: dog, door: door)
    sill(ctx, x: 108, width: 59, fill: NSColor(red: 0.76, green: 0.54, blue: 0.39, alpha: 1))
    fillStroke(ctx, path([CGPoint(x: 12, y: 103), CGPoint(x: 53, y: 137),
                          CGPoint(x: 137, y: 137), CGPoint(x: 96, y: 103)]),
               NSColor(red: 0.88, green: 0.54, blue: 0.42, alpha: 1))
    let roofEdge = path([CGPoint(x: 96, y: 103), CGPoint(x: 137, y: 137), CGPoint(x: 180, y: 103),
                         CGPoint(x: 176, y: 94), CGPoint(x: 137, y: 127), CGPoint(x: 99, y: 94)])
    fillStroke(ctx, roofEdge, NSColor(red: 0.81, green: 0.45, blue: 0.35, alpha: 1))
}

private func drawPebble(_ ctx: CGContext, dog: CGImage) {
    let side = CGMutablePath()
    side.move(to: CGPoint(x: 14, y: 26))
    side.addLine(to: CGPoint(x: 110, y: 20))
    side.addLine(to: CGPoint(x: 110, y: 105))
    side.addCurve(to: CGPoint(x: 14, y: 99), control1: CGPoint(x: 80, y: 130), control2: CGPoint(x: 18, y: 122))
    side.closeSubpath()
    fillStroke(ctx, side, NSColor(red: 0.76, green: 0.83, blue: 0.73, alpha: 1))
    let front = CGPath(roundedRect: CGRect(x: 102, y: 17, width: 75, height: 100),
                       cornerWidth: 34, cornerHeight: 34, transform: nil)
    fillStroke(ctx, front, NSColor(red: 0.88, green: 0.91, blue: 0.78, alpha: 1))
    let door = entrance(x: 115, width: 50, top: 86)
    sleepyDog(ctx, cell: dog, door: door)
    sill(ctx, x: 111, width: 58, fill: NSColor(red: 0.68, green: 0.77, blue: 0.66, alpha: 1))
    let cap = CGMutablePath()
    cap.move(to: CGPoint(x: 12, y: 81))
    cap.addLine(to: CGPoint(x: 12, y: 97))
    cap.addCurve(to: CGPoint(x: 177, y: 96), control1: CGPoint(x: 15, y: 153), control2: CGPoint(x: 159, y: 155))
    cap.addLine(to: CGPoint(x: 177, y: 81))
    cap.closeSubpath()
    fillStroke(ctx, cap, NSColor(red: 0.60, green: 0.74, blue: 0.70, alpha: 1))
    fillStroke(ctx, CGPath(ellipseIn: CGRect(x: 44, y: 57, width: 27, height: 27), transform: nil),
               NSColor(red: 0.89, green: 0.93, blue: 0.84, alpha: 1), width: 2)
}

private func drawAFrame(_ ctx: CGContext, dog: CGImage) {
    let roof = path([CGPoint(x: 10, y: 20), CGPoint(x: 51, y: 138),
                     CGPoint(x: 138, y: 138), CGPoint(x: 98, y: 20)])
    fillStroke(ctx, roof, NSColor(red: 0.84, green: 0.62, blue: 0.40, alpha: 1), width: 3)
    let front = path([CGPoint(x: 98, y: 19), CGPoint(x: 138, y: 132), CGPoint(x: 179, y: 19)])
    fillStroke(ctx, front, NSColor(red: 0.98, green: 0.88, blue: 0.70, alpha: 1), width: 3)
    let inner = path([CGPoint(x: 110, y: 20), CGPoint(x: 138, y: 108), CGPoint(x: 166, y: 20)])
    fillStroke(ctx, inner, NSColor(red: 0.91, green: 0.78, blue: 0.58, alpha: 1), width: 2)
    let door = entrance(x: 113, width: 50, top: 78)
    sleepyDog(ctx, cell: dog, door: door)
    sill(ctx, x: 110, width: 56, fill: NSColor(red: 0.79, green: 0.65, blue: 0.45, alpha: 1))
    ctx.move(to: CGPoint(x: 98, y: 20))
    ctx.addLine(to: CGPoint(x: 138, y: 138))
    ctx.addLine(to: CGPoint(x: 179, y: 20))
    ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(3.5); ctx.setLineJoin(.round); ctx.strokePath()
}

final class SideHouseSheet: NSView {
    let dog: CGImage
    init(frame: CGRect, dog: CGImage) { self.dog = dog; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(red: 0.985, green: 0.977, blue: 0.954, alpha: 1).cgColor)
        ctx.fill(bounds)
        let titles = ["1  Side cottage", "2  Rounded pod", "3  Side A-frame"]
        let captions = ["A familiar little home", "Soft, curved shelter", "A snug sleeping nook"]
        for index in 0..<3 {
            let x = CGFloat(index) * 255 + 18
            let card = CGPath(roundedRect: CGRect(x: x, y: 17, width: 240, height: 243),
                              cornerWidth: 18, cornerHeight: 18, transform: nil)
            ctx.addPath(card); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
            ctx.addPath(card); ctx.setStrokeColor(NSColor(red: 0.88, green: 0.85, blue: 0.80, alpha: 1).cgColor)
            ctx.setLineWidth(1); ctx.strokePath()
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.10).cgColor)
            ctx.fillEllipse(in: CGRect(x: x + 29, y: 76, width: 180, height: 12))
            ctx.saveGState()
            ctx.translateBy(x: x + 25, y: 76)
            switch index {
            case 0: drawCottage(ctx, dog: dog)
            case 1: drawPebble(ctx, dog: dog)
            default: drawAFrame(ctx, dog: dog)
            }
            sleepMarks()
            ctx.restoreGState()
            (titles[index] as NSString).draw(at: CGPoint(x: x + 17, y: 46), withAttributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: ink
            ])
            (captions[index] as NSString).draw(at: CGPoint(x: x + 17, y: 25), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray
            ])
        }
    }
}

guard CommandLine.arguments.count == 3,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let atlas = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let dog = atlas.cropping(to: CGRect(x: 192, y: 0, width: 192, height: 208)) else {
    fputs("usage: swift render-house-side-concepts.swift atlas.png output.png\n", stderr)
    exit(1)
}

_ = NSApplication.shared
let view = SideHouseSheet(frame: CGRect(x: 0, y: 0, width: 783, height: 277), dog: dog)
let scale: CGFloat = 2
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = view.bounds.size
view.cacheDisplay(in: view.bounds, to: rep)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
