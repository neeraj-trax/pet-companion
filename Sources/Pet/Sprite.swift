import AppKit

/// Sprite-atlas character (the blue cloud-headed terminal robot), played back by the rules in
/// `gpt-pet-exact-animation-spec.md`: nine timed animation rows plus sixteen directional gaze poses.
/// All frame selection is a pure function of elapsed time, so the view needs no timers of its own.

enum SpriteState: Int, CaseIterable {
    case idle = 0, runningRight, runningLeft, waving, jumping, failed, waiting, running, review

    var id: String {
        switch self {
        case .idle: return "idle"; case .runningRight: return "running-right"; case .runningLeft: return "running-left"
        case .waving: return "waving"; case .jumping: return "jumping"; case .failed: return "failed"
        case .waiting: return "waiting"; case .running: return "running"; case .review: return "review"
        }
    }

    /// Per-frame durations in milliseconds, column order. Idle's base values are multiplied by 6 at playback.
    var durations: [Int] {
        switch self {
        case .idle:          return [280, 110, 110, 140, 140, 320]
        case .runningRight:  return [120, 120, 120, 120, 120, 120, 120, 220]
        case .runningLeft:   return [120, 120, 120, 120, 120, 120, 120, 220]
        case .waving:        return [140, 140, 140, 280]
        case .jumping:       return [140, 140, 140, 140, 280]
        case .failed:        return [140, 140, 140, 140, 140, 140, 140, 240]
        case .waiting:       return [150, 150, 150, 150, 150, 260]
        case .running:       return [120, 120, 120, 120, 120, 220]
        case .review:        return [150, 150, 150, 150, 150, 280]
        }
    }
    var frameCount: Int { durations.count }
}

/// One cell of the atlas.
struct SpriteFrame: Equatable {
    var row: Int
    var col: Int
}

enum SpriteAtlas {
    static let columns = 8
    static let rows = 11                                   // version 2: 9 animation rows + 2 gaze rows
    static let cell = CGSize(width: 192, height: 208)
    /// Where the character sits inside a cell (measured): x 24…167, top 8…177 (top-down), i.e. feet 30 px above the cell bottom.
    static let characterSize = CGSize(width: 144, height: 170)
    static let feetOffset: CGFloat = 30                    // px from cell bottom to the soles
    static let characterLeft: CGFloat = 24

    /// Slow idle: base durations × 6 → 6600 ms per cycle.
    static let slowIdle: [(SpriteFrame, Int)] = SpriteState.idle.durations.enumerated().map { (SpriteFrame(row: 0, col: $0.offset), $0.element * 6) }

    /// The full playback list for a state: three fast cycles, then the slow idle which loops forever.
    static func sequence(for state: SpriteState) -> (frames: [(SpriteFrame, Int)], loopFrom: Int) {
        if state == .idle { return (slowIdle, 0) }
        let cycle = state.durations.enumerated().map { (SpriteFrame(row: state.rawValue, col: $0.offset), $0.element) }
        let intro = cycle + cycle + cycle
        return (intro + slowIdle, intro.count)
    }

    /// Frame to show `elapsed` seconds after `state` began.
    static func frame(for state: SpriteState, elapsed: TimeInterval, reducedMotion: Bool = false, loop: Bool = false) -> SpriteFrame {
        if reducedMotion { return SpriteFrame(row: state.rawValue, col: 0) }
        if loop {   // keep the cycle going for as long as the state lasts (walking), no slow idle tail
            let cycle = state.durations
            let total = cycle.reduce(0, +)
            var ms = Int((max(0, elapsed) * 1000).truncatingRemainder(dividingBy: Double(total)))
            for (i, d) in cycle.enumerated() { if ms < d { return SpriteFrame(row: state.rawValue, col: i) }; ms -= d }
            return SpriteFrame(row: state.rawValue, col: cycle.count - 1)
        }
        let (frames, loopFrom) = sequence(for: state)
        var ms = max(0, elapsed) * 1000
        let introMs = frames[..<loopFrom].reduce(0) { $0 + Double($1.1) }
        if ms >= introMs {
            let loopMs = frames[loopFrom...].reduce(0) { $0 + Double($1.1) }
            ms = introMs + (ms - introMs).truncatingRemainder(dividingBy: loopMs)
        }
        var acc = 0.0
        for (f, d) in frames {
            acc += Double(d)
            if ms < acc { return f }
        }
        return frames[frames.count - 1].0
    }

    /// Directional gaze pose. `dx` positive = right, `dyUp` positive = up (native bottom-up coordinates).
    /// 0° is up, 90° right, 180° down, 270° left; sixteen 22.5° sectors over rows 9 and 10.
    static func lookFrame(dx: CGFloat, dyUp: CGFloat) -> SpriteFrame {
        let angle = (atan2(dx, dyUp) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let sector = Int((angle / 22.5).rounded()) % 16
        return SpriteFrame(row: 9 + sector / 8, col: sector % 8)
    }

    static func rect(of frame: SpriteFrame) -> CGRect {   // top-down pixel rect inside the atlas image
        CGRect(x: CGFloat(frame.col) * cell.width, y: CGFloat(frame.row) * cell.height, width: cell.width, height: cell.height)
    }

    // MARK: Loading and skins

    static let image: CGImage? = load()

    private static var recolored: [Coat: CGImage] = [:]

    /// The atlas tinted for a skin: body, glyph accent and face panel recoloured separately. Made once per skin and cached.
    static func image(for coat: Coat) -> CGImage? {
        guard let base = image else { return nil }
        guard let tones = coat.spriteTones else { return base }
        if let done = recolored[coat] { return done }
        let out = recolor(base, body: tones.body, accent: tones.accent, screenHue: tones.screenHue) ?? base
        recolored[coat] = out
        return out
    }

    private static func hsv(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h: CGFloat = 0
        if d > 0.0001 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h *= 60; if h < 0 { h += 360 }
        }
        return (h, mx > 0 ? d / mx : 0, mx)
    }

    private static func rgb(_ h: CGFloat, _ s: CGFloat, _ v: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let c = v * s, hh = h / 60, x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        switch Int(hh) % 6 {
        case 0: return (c + m, x + m, m); case 1: return (x + m, c + m, m); case 2: return (m, c + m, x + m)
        case 3: return (m, x + m, c + m); case 4: return (x + m, m, c + m); default: return (c + m, m, x + m)
        }
    }

    /// Region-based recolour of the original blue art: outlines stay, cyan glyphs → accent, the white chest glyph → pale accent,
    /// the dark face panel → screenHue, everything else (cloud, limbs) → body. Shading survives because only hue is replaced.
    private static func recolor(_ src: CGImage, body: SpriteTone, accent: SpriteTone, screenHue: CGFloat) -> CGImage? {
        let w = src.width, h = src.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let a = CGFloat(px[i + 3]) / 255
            if a == 0 { continue }
            let (h0, s0, v0) = hsv(CGFloat(px[i]) / 255 / a, CGFloat(px[i + 1]) / 255 / a, CGFloat(px[i + 2]) / 255 / a)
            let t: SpriteTone
            if v0 < 0.2 { continue }
            else if h0 > 165 && h0 < 205 && v0 > 0.6 { t = accent }
            else if s0 < 0.3 && v0 > 0.75 { t = SpriteTone(hue: accent.hue, sat: 0.35, val: accent.val) }
            else if v0 < 0.45 { t = SpriteTone(hue: screenHue, sat: 1, val: 1) }
            else { t = body }
            let (r, g, b) = rgb(t.hue, min(1, s0 * t.sat), min(1, v0 * t.val))
            px[i] = UInt8(max(0, min(255, r * a * 255)))
            px[i + 1] = UInt8(max(0, min(255, g * a * 255)))
            px[i + 2] = UInt8(max(0, min(255, b * a * 255)))
        }
        return ctx.makeImage()
    }

    private static func load() -> CGImage? {
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["PET_ATLAS"] { candidates.append(URL(fileURLWithPath: env)) }
        if let res = Bundle.main.resourceURL { candidates.append(res.appendingPathComponent("pet-atlas.webp")) }
        // running from `swift build`: .build/<config>/Pet → ../../Assets/pet-atlas.webp
        var dir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        for _ in 0..<5 {
            candidates.append(dir.appendingPathComponent("Assets/pet-atlas.webp"))
            dir.deleteLastPathComponent()
        }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
               cg.width == Int(cell.width) * columns, cg.height == Int(cell.height) * rows {
                return cg
            }
        }
        return nil
    }
}
