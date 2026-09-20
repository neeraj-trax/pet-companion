import AppKit
import QuartzCore
import UniformTypeIdentifiers
import ServiceManagement

enum ScreenEdge: String { case bottom, top, left, right, free }

enum Mood: String, CaseIterable {
    case shy, normal, chatty
    var title: String {
        switch self {
        case .shy: return "Shy (mostly hidden)"
        case .normal: return "Normal"
        case .chatty: return "Chatty"
        }
    }
}

/// Owns the pet window, runs the animation loop, and decides what the shark feels like doing.
final class PetController: NSObject, NSMenuDelegate {
    enum State { case idle, wandering, napping, poked, dragging, landing, diving, submerged, periscope, surfacing }
    enum DiveReason { case menu, drag, idle, typing, autopilot, shh, app }

    let window = PetWindow()
    let view = PetView(frame: CGRect(origin: .zero, size: PetGeometry.viewSize))
    let launchPanel = RingPanel()
    let store = ShortcutStore.shared
    let music = MusicWatcher()
    private var musicNoteIn: TimeInterval = 20

    private var pose = PetPose()
    private var state: State = .idle
    private var stateTime: TimeInterval = 0
    private var time: TimeInterval = 0
    private var lastTick = CACurrentMediaTime()
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    private var screenAsleep = false

    private(set) var edge: ScreenEdge = .bottom
    private(set) var hugEdges = true
    private var hideFromSharing = false
    private var mood: Mood = .normal
    private var quietHours = false
    private var shhUntil: TimeInterval = 0
    private var diveApps: Set<String> = []

    // idle brain
    private var nextDecisionIn: TimeInterval = 8
    private var lastNapEnded: TimeInterval = 0
    private var napDuration: TimeInterval = 0
    private var wanderTarget: CGFloat = 0
    private var wanderDeadline: TimeInterval = 0
    private var blinkIn: TimeInterval = 3
    private var blinkT: TimeInterval = -1
    private var idleLook = CGPoint.zero
    private var idleLookIn: TimeInterval = 2
    private var thoughtIn: TimeInterval = 20
    private var thoughtUntil: TimeInterval = 0
    private var finFlickUntil: TimeInterval = 0
    private var oppositeSideFor: TimeInterval = 0
    private var tailTwitchIn: TimeInterval = 5
    private var tailTwitchUntil: TimeInterval = 0

    // curious
    private var curiousT: TimeInterval = -1
    private var curiousAnchor = CGPoint.zero
    private var curiousBuild: TimeInterval = 0
    private var lastCurious: TimeInterval = -100
    private var curiousTilt: CGFloat = 0

    // pointer / hover / typing
    private var hoverDwell: TimeInterval = 0
    private var hoverGrace: TimeInterval = 0
    private var panelCooldownUntil: TimeInterval = 0
    private var lastMouse = NSEvent.mouseLocation
    private var mouseStillFor: TimeInterval = 0
    private var cursorSpeed: CGFloat = 0
    private var welcomeUntil: TimeInterval = 0
    private var lastIgnoresMouse = true
    private var keyIdle: TimeInterval = 999
    private var typingFor: TimeInterval = 0
    private var typingDiveAfter: TimeInterval = 75
    private var resurfaceAfter: TimeInterval = 22
    private var dropHovering = false
    private var gulpT: TimeInterval = -1

    // drag
    private var pressed = false
    private var pressStart = CGPoint.zero
    private var pressOrigin = CGPoint.zero
    private var lastDragX: CGFloat = 0
    private var dragVelocity: CGFloat = 0
    private var tilt: CGFloat = 0

    // landing / pulses
    private var landFrom = CGPoint.zero
    private var landTo = CGPoint.zero
    private var landDuration: TimeInterval = 0.4
    private var pulseT: TimeInterval = -1
    private var pulseDuration: TimeInterval = 0.3
    private var pulseAmount: CGFloat = 0
    private var turnT: TimeInterval = -1
    private var spinT: TimeInterval = -1

    // poke
    private var pokeCount = 0
    private var lastPoke: TimeInterval = -10

    // side-edge peeking (0 = tucked away, 1 = fully out)
    private var peek: CGFloat = 1
    private var peekTarget: CGFloat = 1
    private var peekChangeIn: TimeInterval = 4

    // under water (bottom edge): 0 standing ... 1 only the fin shows
    private var depth: CGFloat = 0
    private var diveReason: DiveReason = .idle
    /// Depth at which even the fin tip is under the edge.
    private let divePeak: CGFloat = (PetGeometry.earTop + 8 - PetGeometry.bodyBottom) / PetGeometry.submergeDepth
    private var diveSkipHop = false
    private var diveBubbled = false
    private var diveTurned = false
    private var cruiseUntil: TimeInterval = 0
    private var cruiseDir: CGFloat = 1
    private var cruiseSpeed: CGFloat = 0
    private var targetSpeed: CGFloat = 0
    private var legUntil: TimeInterval = 0
    private var pauseUntil: TimeInterval = 0
    private var turnUntil: TimeInterval = 0
    private var hitWall = false
    private var periscopeIn: TimeInterval = 60
    private var periscopeHold: TimeInterval = 1.5
    private var periscopeBlinked = false
    private var lastPeriscope: TimeInterval = -100
    private var slowCursorNear: TimeInterval = 0
    private var lastSelfSurface: TimeInterval = -1000
    private var surfaceFrom: CGFloat = 0
    private var surfaceDuration: TimeInterval = 0.6
    private var surfaceFast = true
    private var surfaceOvershoot: CGFloat = 0.08
    private var surfaceOpenPanel = false
    private var surfaceDropped = false
    private var pendingComeHere: CGPoint? = nil
    private var fullscreenHidden = false
    private var fullscreenCheckIn: TimeInterval = 1

    // apps
    private var recentApps: [URL] = []
    private var frontSince: TimeInterval = 0
    private var frontBundle: String?
    private var switchTimes: [TimeInterval] = []
    private var lastAutopilot: TimeInterval = -1000

    private enum Keys {
        static let x = "pet.origin.x", y = "pet.origin.y", edge = "pet.edge", hugEdges = "pet.hugEdges", coat = "pet.coat"
        static let sharing = "pet.hideFromSharing", mood = "pet.mood", quiet = "pet.quietHours", underwater = "pet.underwater"
        static let diveApps = "pet.diveApps", firstRun = "pet.firstRunDone", pillHint = "pet.pillHintShown"
    }
    private var saidBrb = false
    private var selfTesting = false
    private var pendingThoughts: [(TimeInterval, String, TimeInterval)] = []
    private var firstRunSurfaceAt: TimeInterval = -1

    override init() {
        super.init()
        view.controller = self
        window.contentView = view
        let d = UserDefaults.standard
        hugEdges = d.object(forKey: Keys.hugEdges) as? Bool ?? true
        pose.coat = Coat(rawValue: d.string(forKey: Keys.coat) ?? "") ?? .sand
        hideFromSharing = d.bool(forKey: Keys.sharing)
        mood = Mood(rawValue: d.string(forKey: Keys.mood) ?? "") ?? .normal
        quietHours = d.bool(forKey: Keys.quiet)
        diveApps = Set(d.stringArray(forKey: Keys.diveApps) ?? [])
        applySharing()
        launchPanel.onLaunch = { [weak self] url in self?.launch(url) }
        launchPanel.onAdd = { [weak self] in self?.addShortcut() }
        launchPanel.onClip = { [weak self] in self?.keepClipboard() }
        launchPanel.onPlayPause = { [weak self] in
            self?.music.playPause()
            self?.launchPanel.hide()
        }
        music.onChange = { [weak self] in
            guard let self else { return }
            self.launchPanel.nowPlaying = self.music.track
            self.launchPanel.reload()
            if self.music.isPlaying, self.state == .idle { self.think("♪", for: 2) }
        }
        launchPanel.onRemove = { [weak self] url in
            self?.store.remove(url)
            self?.launchPanel.reload()
        }
        launchPanel.onPin = { [weak self] url in
            self?.store.add(url)
            self?.launchPanel.reload()
            self?.spawnParticles("♥", count: 1)
        }
    }

    func start() {
        placeInitially()
        window.orderFrontRegardless()
        restartTimer(interval: 1.0 / 30.0)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(appActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        if let front = NSWorkspace.shared.frontmostApplication {
            frontBundle = front.bundleIdentifier
            if let url = front.bundleURL { recentApps = [url] }
        }
        enterIdle()
        let d = UserDefaults.standard
        if !d.bool(forKey: Keys.firstRun) && edge == .bottom && hugEdges {
            // first launch: the fin arrives, cruises for a moment, then the shark says hi
            d.set(true, forKey: Keys.firstRun)
            d.set(true, forKey: Keys.underwater)
            firstRunSurfaceAt = time + 4
        }
        if d.bool(forKey: Keys.underwater) && edge == .bottom && hugEdges {
            depth = 1
            pose.submerged = 1
            pose.waterline = PetGeometry.bodyBottom + PetGeometry.submergeDepth
            pose.earPerk = 0.5
            beginSubmerged()
            setOrigin(edgeTarget(for: .bottom, in: currentScreen.visibleFrame, from: origin))
            view.pose = pose
        }
    }

    // MARK: - Timer

    private func restartTimer(interval: TimeInterval) {
        guard interval != timerInterval else { return }
        timer?.invalidate()
        timerInterval = interval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Faster frames only when something is actually moving; slow ticks while the shark just breathes.
    private func desiredInterval(mouse: CGPoint) -> TimeInterval {
        if screenAsleep || fullscreenHidden { return 2.0 }
        switch state {
        case .landing, .dragging, .wandering, .poked, .diving, .surfacing, .periscope: return 1.0 / 60.0
        case .submerged: return cruiseSpeed > 1 ? 1.0 / 30.0 : 1.0 / 15.0
        default: break
        }
        if launchPanel.isShown || pressed || pulseT >= 0 || turnT >= 0 || spinT >= 0 || gulpT >= 0
            || !pose.particles.isEmpty || pose.thoughtAlpha > 0.01 || curiousT >= 0 {
            return 1.0 / 30.0
        }
        let c = refPoint
        if hypot(mouse.x - c.x, mouse.y - c.y) < 500 { return 1.0 / 30.0 }
        return state == .napping ? 1.0 / 10.0 : 1.0 / 15.0
    }

    @objc private func screensSlept() { screenAsleep = true }
    @objc private func screensWoke() { screenAsleep = false; lastTick = CACurrentMediaTime() }

    private func applySharing() {
        window.sharingType = hideFromSharing ? .none : .readOnly
        launchPanel.sharingType = hideFromSharing ? .none : .readOnly
    }

    // MARK: - Apps you use

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        if app.bundleIdentifier != frontBundle {
            frontBundle = app.bundleIdentifier
            frontSince = time
            switchTimes.append(time)
            switchTimes.removeAll { time - $0 > 60 }
        }
        guard let url = app.bundleURL, app.activationPolicy == .regular else { return }
        recentApps.removeAll { $0.path == url.path }
        recentApps.insert(url, at: 0)
        if recentApps.count > 4 { recentApps.removeLast() }
        if isUnderwater && (moodNow == .normal || moodNow == .chatty) && state == .submerged
            && time - lastPeriscope > 60 && !typing {
            startPeriscope()
        }
    }

    private var switchBackApps: [URL] {
        let front = NSWorkspace.shared.frontmostApplication?.bundleURL
        return recentApps.filter { $0.path != front?.path }
    }

    // MARK: - Geometry

    private var origin: CGPoint { window.frame.origin }
    private func setOrigin(_ p: CGPoint) { window.setFrameOrigin(CGPoint(x: (p.x * 2).rounded() / 2, y: (p.y * 2).rounded() / 2)) }

    var bodyCenterOnScreen: CGPoint {
        CGPoint(x: origin.x + PetGeometry.bodyCenter.x, y: origin.y + PetGeometry.bodyCenter.y)
    }
    /// A point that is always on-screen (fin tip area), used to resolve the screen and distances.
    private var finPointOnScreen: CGPoint {
        CGPoint(x: origin.x + PetGeometry.bodyCenter.x, y: origin.y + PetGeometry.earTop - 6)
    }
    private var isUnderwater: Bool { state == .diving || state == .submerged || state == .periscope || state == .surfacing }
    private var refPoint: CGPoint { isUnderwater ? finPointOnScreen : bodyCenterOnScreen }
    private var typing: Bool { keyIdle < 3 }

    private var lastKnownScreen: NSScreen?
    private var currentScreen: NSScreen {
        let c = finPointOnScreen
        let s = NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(c) }
            ?? NSScreen.main ?? NSScreen.screens.first ?? lastKnownScreen
        lastKnownScreen = s
        return s ?? NSScreen()
    }

    private func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? currentScreen
    }

    private var finHitRectOnScreen: CGRect {
        let f = currentScreen.visibleFrame
        let autoHideDock = f.minY == currentScreen.frame.minY
        return CGRect(x: origin.x + 58, y: f.minY + (autoHideDock ? 2 : -2), width: 54, height: 30)
    }

    /// True when a screen point is on the shark's visible silhouette.
    func petContains(_ point: CGPoint) -> Bool {
        if isUnderwater && depth > 0.5 { return finHitRectOnScreen.contains(point) }
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        guard PetGeometry.hitPath(bob: pose.bob, facing: pose.facing, squashX: pose.squashX, squashY: pose.squashY).contains(local) else { return false }
        return currentScreen.visibleFrame.insetBy(dx: -2, dy: -2).contains(point)
    }

    var hitRectOnScreen: CGRect {
        if isUnderwater && depth > 0.5 { return finHitRectOnScreen }
        let full = PetGeometry.hitPath(bob: pose.bob, facing: pose.facing, squashX: pose.squashX, squashY: pose.squashY)
            .boundingBox.offsetBy(dx: origin.x, dy: origin.y)
        let visible = full.intersection(currentScreen.visibleFrame.insetBy(dx: -2, dy: -2))
        return visible.isNull ? full : visible
    }

    private func edgeTarget(for edge: ScreenEdge, in f: CGRect, from o: CGPoint) -> CGPoint {
        let g = PetGeometry.self
        let minX = f.minX - g.bodyCenter.x + g.bodyHalfWidth + 4
        let maxX = f.maxX - g.bodyCenter.x - g.bodyHalfWidth - 4
        let minY = f.minY - g.bodyBottom
        let maxY = f.maxY - g.earTop - 2
        func cx(_ x: CGFloat) -> CGFloat { min(max(x, minX), maxX) }
        func cy(_ y: CGFloat) -> CGFloat { min(max(y, minY), maxY) }
        switch edge {
        case .bottom: return CGPoint(x: cx(o.x), y: minY - depth * g.submergeDepth)
        case .top:    return CGPoint(x: cx(o.x), y: maxY)
        case .left:   return CGPoint(x: minX + 8 - (g.bodyHalfWidth * 2 - 16) * (1 - peek), y: cy(o.y))
        case .right:  return CGPoint(x: maxX - 8 + (g.bodyHalfWidth * 2 - 16) * (1 - peek), y: cy(o.y))
        case .free:   return CGPoint(x: cx(o.x), y: cy(o.y))
        }
    }

    private func isSeam(_ probe: CGPoint, of f: CGRect) -> Bool {
        NSScreen.screens.contains { !$0.visibleFrame.equalTo(f) && $0.frame.contains(probe) }
    }

    private func nearestEdge(in f: CGRect, at c: CGPoint? = nil) -> ScreenEdge {
        let c = c ?? bodyCenterOnScreen
        var options: [(ScreenEdge, CGFloat)] = []
        if !isSeam(CGPoint(x: c.x, y: f.minY - 3), of: f) { options.append((.bottom, (c.y - f.minY) * 0.8)) }
        if !isSeam(CGPoint(x: c.x, y: f.maxY + 3), of: f) { options.append((.top, f.maxY - c.y)) }
        if !isSeam(CGPoint(x: f.minX - 3, y: c.y), of: f) { options.append((.left, c.x - f.minX)) }
        if !isSeam(CGPoint(x: f.maxX + 3, y: c.y), of: f) { options.append((.right, f.maxX - c.x)) }
        return options.min { $0.1 < $1.1 }?.0 ?? .bottom
    }

    private func placeInitially() {
        let d = UserDefaults.standard
        if let e = ScreenEdge(rawValue: d.string(forKey: Keys.edge) ?? "") { edge = e }
        if !hugEdges { edge = .free }
        var o = CGPoint(x: d.double(forKey: Keys.x), y: d.double(forKey: Keys.y))
        let saved = d.object(forKey: Keys.x) != nil
        let center = CGPoint(x: o.x + PetGeometry.bodyCenter.x, y: o.y + PetGeometry.bodyCenter.y)
        let onSomeScreen = NSScreen.screens.contains { $0.frame.insetBy(dx: -40, dy: -110).contains(center) }
        if !saved || !onSomeScreen {
            let f = (NSScreen.main ?? NSScreen.screens.first ?? currentScreen).visibleFrame
            o = CGPoint(x: f.midX + 140 - PetGeometry.bodyCenter.x, y: f.minY - PetGeometry.bodyBottom)
            edge = hugEdges ? .bottom : .free
        }
        setOrigin(o)
        setOrigin(edgeTarget(for: edge, in: currentScreen.visibleFrame, from: o))
        if edge == .right { pose.facing = -1 }
    }

    func savePosition() {
        let d = UserDefaults.standard
        let standingY = edge == .bottom ? currentScreen.visibleFrame.minY - PetGeometry.bodyBottom : origin.y
        d.set(Double(origin.x), forKey: Keys.x)
        d.set(Double(standingY), forKey: Keys.y)
        d.set(edge.rawValue, forKey: Keys.edge)
        d.set(isUnderwater, forKey: Keys.underwater)
    }

    @objc private func screensChanged() {
        guard state != .dragging else { return }
        if isUnderwater {
            setOrigin(edgeTarget(for: .bottom, in: currentScreen.visibleFrame, from: origin))
            return
        }
        let target = edgeTarget(for: edge, in: currentScreen.visibleFrame, from: origin)
        if hypot(target.x - origin.x, target.y - origin.y) < 2 { return }
        landFrom = origin; landTo = target; landDuration = 0.4
        peek = 1
        state = .landing; stateTime = 0
    }

    // MARK: - Mood

    private var isQuietTime: Bool {
        if time < shhUntil { return true }
        guard quietHours else { return false }
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 22 || h < 8
    }
    private var moodNow: Mood { isQuietTime ? .shy : mood }
    private var thoughtInterval: ClosedRange<Double> {
        switch moodNow { case .shy: return 60...120; case .normal: return 25...70; case .chatty: return 18...40 }
    }
    private var periscopeCheckIn: ClosedRange<Double>? {
        switch moodNow { case .shy: return nil; case .normal: return 40...120; case .chatty: return 30...60 }
    }
    private var curiousCooldown: TimeInterval {
        switch moodNow { case .shy: return 40; case .normal: return 20; case .chatty: return 12 }
    }
    private var selfSurfaceGap: TimeInterval {
        switch moodNow { case .shy: return 600; case .normal: return 300; case .chatty: return 240 }
    }
    private var idleDiveChance: Double {
        switch moodNow { case .shy: return 0.45; case .normal: return 0.30; case .chatty: return 0.15 }
    }

    // MARK: - Animation loop

    private func tick() {
        let now = CACurrentMediaTime()
        let wallDt = max(0, now - lastTick)
        let dt = min(wallDt, 0.1)          // animation step
        lastTick = now
        time += wallDt                      // clocks (naps, cruises, shh) follow the wall clock
        stateTime += dt

        let mouse = NSEvent.mouseLocation
        let moved = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y)
        cursorSpeed = approach(cursorSpeed, moved / CGFloat(max(dt, 0.001)), rate: 12, dt: CGFloat(dt))
        if moved > 0.5 {
            if mouseStillFor > 150 { welcomeBack() }
            mouseStillFor = 0
        } else { mouseStillFor += wallDt }
        lastMouse = mouse

        // typing, without any permission: how long since the last key press anywhere
        keyIdle = selfTesting ? 999 : CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        if keyIdle < 3 { typingFor += dt } else if keyIdle > 8 { typingFor = 0 }

        updateFullscreen(dt: wallDt)
        if fullscreenHidden {
            // frozen and invisible while a fullscreen app is in front
            if launchPanel.isShown { launchPanel.hide() }
            hoverDwell = 0
            restartTimer(interval: desiredInterval(mouse: mouse))
            return
        }
        updateHover(mouse: mouse, dt: dt)
        updateState(dt: dt, mouse: mouse)
        updateAnimation(dt: dt, mouse: mouse)
        launchPanel.tick(dt: CGFloat(dt))
        view.pose = pose
        applyScreenClip()
        restartTimer(interval: desiredInterval(mouse: mouse))
    }

    /// Fully gone while a fullscreen app (video, Keynote, a game) is in front.
    private func updateFullscreen(dt: TimeInterval) {
        fullscreenCheckIn -= dt
        guard fullscreenCheckIn <= 0 else { return }
        fullscreenCheckIn = 2
        let screenFrame = currentScreen.frame
        var covered = false
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard (w[kCGWindowLayer as String] as? Int) == 0,
                      (w[kCGWindowOwnerPID as String] as? Int32) != ProcessInfo.processInfo.processIdentifier,
                      let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                      let width = b["Width"], let height = b["Height"] else { continue }
                if abs(width - screenFrame.width) <= 2 && abs(height - screenFrame.height) <= 2 { covered = true; break }
            }
        }
        if covered != fullscreenHidden {
            fullscreenHidden = covered
            if covered {
                launchPanel.hide()
                window.orderOut(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    private func welcomeBack() {
        guard !isUnderwater else { return }
        if state == .napping { wake() }
        welcomeUntil = time + 1.6
        pulse(amount: 0.12, duration: 0.4)
        spawnBubbles(1)
        think("hi again", for: 1.8)
    }

    private func updateHover(mouse: CGPoint, dt: TimeInterval) {
        let f = currentScreen.visibleFrame
        let petRect = hitRectOnScreen
        let overPet = mouse.y >= f.minY - 2 && petContains(mouse)
        let overPanel = launchPanel.keepsOpen(for: mouse)

        if state != .dragging && !pressed {
            let ignore = !overPet
            if ignore != lastIgnoresMouse { window.ignoresMouseEvents = ignore; lastIgnoresMouse = ignore }
        }

        if overPet || overPanel {
            hoverGrace = 0
            let resting = cursorSpeed < 60 && NSEvent.pressedMouseButtons == 0
            if overPet && resting { hoverDwell += dt } else if cursorSpeed > 600 { hoverDwell = 0 }
            if time < panelCooldownUntil { hoverDwell = 0 }
            if !launchPanel.isShown, overPet, hoverDwell > 0.3, time > panelCooldownUntil, !pressed {
                switch state {
                case .dragging, .landing, .diving, .surfacing: break
                case .submerged, .periscope:
                    surface(fast: true, openPanel: true)
                    hoverDwell = 0
                default:
                    if (edge == .left || edge == .right) && peek < 0.9 { hoverDwell = 0.2; break }   // come out first
                    if state == .napping { wake() }
                    if state == .wandering { enterIdle() }
                    launchPanel.recents = switchBackApps
                    launchPanel.reload()
                    launchPanel.show(near: petRect, edge: edge, screen: f)
                    if !UserDefaults.standard.bool(forKey: Keys.pillHint) {
                        UserDefaults.standard.set(true, forKey: Keys.pillHint)
                        launchPanel.flash("click an app · + adds one · drop files on me", for: 6)
                    }
                }
            }
        } else {
            hoverDwell = 0
            hoverGrace += dt
            if launchPanel.isShown && hoverGrace > 0.45 { launchPanel.hide() }
        }
    }

    private func updateState(dt: TimeInterval, mouse: CGPoint) {
        switch state {
        case .idle:
            if !launchPanel.isShown && !pressed && !typing {
                nextDecisionIn -= dt
                if nextDecisionIn <= 0 { decideNext() }
            }
            updatePeek(dt: dt)
            updateCurious(dt: dt, mouse: mouse)
            // typing focus: after a long steady stretch of typing, get out of the way
            if edge == .bottom && hugEdges && typingFor > typingDiveAfter && !launchPanel.isShown && !pressed {
                startDive(.typing)
            }
            // deep-work autopilot: 15 min in one app, hands on the mouse
            if edge == .bottom && hugEdges && time - frontSince > 900 && keyIdle > 30
                && time - lastAutopilot > 600 && !launchPanel.isShown && !pressed && mouseStillFor < 30 {
                lastAutopilot = time
                startDive(.autopilot)
            }
            if let front = frontBundle, diveApps.contains(front), edge == .bottom, hugEdges, !launchPanel.isShown, !pressed {
                startDive(.app)
            }
        case .wandering:
            if launchPanel.isShown { enterIdle() } else { updateWander(dt: dt) }
        case .napping:
            if stateTime > napDuration { wake() }
        case .poked:
            if stateTime > 0.5 { enterIdle() }
        case .dragging:
            break
        case .diving:
            updateDive(dt: dt)
        case .submerged:
            updateSubmerged(dt: dt, mouse: mouse)
        case .periscope:
            updatePeriscope(dt: dt, mouse: mouse)
        case .surfacing:
            updateSurfacing(dt: dt, mouse: mouse)
        case .landing:
            let p = min(1, stateTime / landDuration)
            let e = 1 - pow(1 - p, 3)
            setOrigin(CGPoint(x: landFrom.x + (landTo.x - landFrom.x) * e,
                              y: landFrom.y + (landTo.y - landFrom.y) * e))
            if p >= 1 {
                setOrigin(landTo)
                enterIdle()
                pulse(amount: edge == .bottom ? -0.16 : 0.08, duration: 0.3)
                savePosition()
            }
        }
    }

    /// On a side edge the shark hides behind the screen edge and peeks out now and then.
    private var peekUntil: TimeInterval = 0
    private func updatePeek(dt: TimeInterval) {
        guard edge == .left || edge == .right else { peek = 1; return }
        let mouse = NSEvent.mouseLocation
        let f = currentScreen.visibleFrame
        let wallX = edge == .left ? f.minX : f.maxX
        let near = abs(mouse.x - wallX) < 240 && abs(mouse.y - bodyCenterOnScreen.y) < 200 && mouseStillFor < 1.5
        // a brief peek now and then (never while typing, never in shy/quiet mode)
        if time > peekUntil {
            peekChangeIn -= dt
            if peekChangeIn <= 0 {
                if let r = periscopeCheckIn, !typing, mouseStillFor < 60 {
                    peekUntil = time + Double.random(in: 1.2...2.5)
                    peekTarget = 0.55
                    blinkT = 0
                }
                peekChangeIn = Double.random(in: 25...70)
            }
        }
        var target: CGFloat
        if near || launchPanel.isShown || pressed || dropHovering { target = 1 }
        else if time < peekUntil { target = peekTarget }
        else if typing { target = 0.02 }
        else { target = 0.14 }
        let old = peek
        peek = approach(peek, target, rate: target > peek ? 3.2 : 1.8, dt: CGFloat(dt))
        if abs(peek - old) > 0.0005 {
            setOrigin(edgeTarget(for: edge, in: f, from: origin))
        }
    }

    /// Nothing outside the usable screen is ever drawn (so a tucked pet never shows over the Dock or a second monitor).
    private func applyScreenClip() {
        guard let view = window.contentView else { return }
        if !view.wantsLayer { view.wantsLayer = true }
        let allowed: CGRect
        if state == .dragging || edge == .free || !hugEdges {
            allowed = currentScreen.frame
        } else {
            allowed = currentScreen.visibleFrame
        }
        let local = CGRect(x: allowed.minX - origin.x, y: allowed.minY - origin.y, width: allowed.width, height: allowed.height)
        let mask = (view.layer?.mask as? CAShapeLayer) ?? CAShapeLayer()
        mask.frame = view.bounds
        let path = CGPath(rect: local.intersection(view.bounds).isNull ? .zero : local.intersection(view.bounds), transform: nil)
        if mask.path == nil || !(mask.path!.boundingBox.equalTo(path.boundingBox)) {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            mask.path = path
            view.layer?.mask = mask
            CATransaction.commit()
        }
    }

    /// A cursor that pauses nearby earns a little head tilt.
    private func updateCurious(dt: TimeInterval, mouse: CGPoint) {
        if curiousT >= 0 {
            curiousT += dt
            if hypot(mouse.x - curiousAnchor.x, mouse.y - curiousAnchor.y) > 40 || curiousT > 5 { curiousT = -1 }
            return
        }
        let c = bodyCenterOnScreen
        let dist = hypot(mouse.x - c.x, mouse.y - c.y)
        if dist > 60, dist < 220, !petContains(mouse), cursorSpeed < 30, !typing, time - lastCurious > curiousCooldown {
            curiousBuild += dt
            if curiousBuild > 0.8 {
                curiousBuild = 0
                curiousT = 0
                curiousAnchor = mouse
                lastCurious = time
            }
        } else { curiousBuild = 0 }
    }

    // MARK: - Under water

    private func startDive(_ reason: DiveReason) {
        guard edge == .bottom, hugEdges, !isUnderwater, state != .dragging else { return }
        let f = currentScreen.visibleFrame
        guard !isSeam(CGPoint(x: bodyCenterOnScreen.x, y: f.minY - 3), of: f) else { return }
        diveReason = reason
        if !saidBrb, reason == .idle || reason == .typing || reason == .autopilot || reason == .app {
            saidBrb = true
            think("brb ~", for: 1.2)
        }
        diveSkipHop = (reason == .drag)
        diveBubbled = false
        diveTurned = false
        if launchPanel.isShown { launchPanel.hide() }
        panelCooldownUntil = time + 1
        curiousT = -1
        state = .diving
        stateTime = 0
    }

    private func updateDive(dt: TimeInterval) {
        let f = currentScreen.visibleFrame
        let g = PetGeometry.self
        let p = stateTime
        let sinkStart: TimeInterval = diveSkipHop ? 0 : 0.15
        if p < sinkStart {
            depth = 0
        } else if p < sinkStart + 0.55 {
            let q = CGFloat((p - sinkStart) / 0.55)
            depth = q * q * divePeak
            if q > 0.4 && !diveBubbled { diveBubbled = true; spawnBubbles(5) }
        } else if p < sinkStart + 1.25 {
            depth = divePeak
        } else if !diveTurned {
            diveTurned = true
            let minX = f.minX - g.bodyCenter.x + g.bodyHalfWidth + 4
            let maxX = f.maxX - g.bodyCenter.x - g.bodyHalfWidth - 4
            var o = origin
            o.x = min(max(o.x + pose.facing * 60, minX), maxX)
            setOrigin(o)
            pose.facing = -pose.facing
            tilt = 0
        } else if p < sinkStart + 1.75 {
            let q = CGFloat((p - sinkStart - 1.25) / 0.5)
            depth = divePeak - (divePeak - 1) * (1 - pow(1 - q, 3))
        } else {
            depth = 1
            beginSubmerged()
        }
        setOrigin(CGPoint(x: origin.x, y: f.minY - g.bodyBottom - depth * g.submergeDepth))
    }

    private func beginSubmerged() {
        cruiseUntil = time + Double.random(in: 120...360)
        resurfaceAfter = Double.random(in: 20...25)
        if let r = periscopeCheckIn { periscopeIn = Double.random(in: r) }
        resumeSubmerged()
        savePosition()
    }

    /// Back to cruising after a periscope peek, without restarting the cruise clock.
    private func resumeSubmerged() {
        state = .submerged
        stateTime = 0
        cruiseDir = pose.facing
        cruiseSpeed = 0
        hitWall = false
        if let r = periscopeCheckIn { periscopeIn = Double.random(in: r) }
        startLeg()
    }

    private func startLeg() {
        legUntil = time + Double.random(in: 6...14)
        targetSpeed = CGFloat.random(in: 14...18)
        pauseUntil = 0
    }

    private func updateSubmerged(dt: TimeInterval, mouse: CGPoint) {
        let f = currentScreen.visibleFrame
        let g = PetGeometry.self
        let dtf = CGFloat(dt)
        let minX = f.minX - g.bodyCenter.x + g.bodyHalfWidth + 4
        let maxX = f.maxX - g.bodyCenter.x - g.bodyHalfWidth - 4

        // legs of slow cruising with lazy pauses and turns
        if time < pauseUntil {
            targetSpeed = 0
        } else if pauseUntil > 0 {
            pauseUntil = 0
            if !hitWall && Double.random(in: 0..<1) < 0.65 { cruiseDir = -cruiseDir; turnUntil = time + 0.8 }
            hitWall = false
            startLeg()
        } else if time > legUntil {
            pauseUntil = time + Double.random(in: 2...5)
        }
        cruiseSpeed = approach(cruiseSpeed, targetSpeed, rate: 1.2, dt: dtf)
        var o = origin
        o.x += cruiseDir * cruiseSpeed * dtf
        if o.x <= minX { o.x = minX; cruiseDir = 1; pauseUntil = time + 1; hitWall = true }
        else if o.x >= maxX { o.x = maxX; cruiseDir = -1; pauseUntil = time + 1; hitWall = true }
        depth = 1 + 0.03 * sin(CGFloat(time) * 1.3)
        o.y = f.minY - g.bodyBottom - depth * g.submergeDepth
        setOrigin(o)
        if cruiseDir != pose.facing { pose.facing = cruiseDir }

        // periscope triggers
        let finX = origin.x + g.bodyCenter.x
        let cursorNear = abs(mouse.x - finX) < 200 && mouse.y < f.minY + 160 && mouse.y >= f.minY - 5
            && cursorSpeed < 120 && mouseStillFor < 1.5
        slowCursorNear = cursorNear ? slowCursorNear + dt : 0
        if time - lastPeriscope > 12 && !typing {
            if slowCursorNear > 0.35 { startPeriscope(); return }
            if periscopeCheckIn != nil && mouseStillFor < 60 && time > shhUntil {
                periscopeIn -= dt
                if periscopeIn <= 0 { startPeriscope(); return }
            }
        }

        if firstRunSurfaceAt > 0 && time > firstRunSurfaceAt {
            firstRunSurfaceAt = -1
            surface(fast: true, openPanel: false)
            thinkLater("hi! ◠‿◠", after: 0.7, for: 2.6)
            thinkLater("rest your mouse on me", after: 3.6, for: 4)
            thinkLater("drop files on me too", after: 8, for: 3.5)
            return
        }
        // coming back up on its own
        let shh = time < shhUntil
        switchTimes.removeAll { time - $0 > 60 }
        switch diveReason {
        case .typing:
            if keyIdle > resurfaceAfter && mouseStillFor < 10 && !shh { surface(fast: false, openPanel: false); return }
            if switchTimes.count >= 3 && !shh { surface(fast: false, openPanel: false); return }
        case .autopilot:
            if switchTimes.count >= 3 && !shh { surface(fast: false, openPanel: false); return }
        case .app:
            if let front = frontBundle, !diveApps.contains(front), !shh { surface(fast: false, openPanel: false); return }
        default:
            break
        }
        if time > cruiseUntil && mouseStillFor < 3 && time - lastSelfSurface > selfSurfaceGap && !typing && !shh {
            surface(fast: false, openPanel: false)
        }
    }

    private func startPeriscope() {
        state = .periscope
        stateTime = 0
        periscopeHold = Double.random(in: 1...2.5)
        periscopeBlinked = false
        lastPeriscope = time
        cruiseSpeed = 0
        spawnBubbles(1)
    }

    private func updatePeriscope(dt: TimeInterval, mouse: CGPoint) {
        let f = currentScreen.visibleFrame
        let g = PetGeometry.self
        let up = 1 - g.periscopeFraction
        if stateTime < 0.35 {
            let q = CGFloat(stateTime / 0.35)
            depth = 1 - up * (1 - pow(1 - q, 3))
        } else if stateTime < 0.35 + periscopeHold {
            depth = g.periscopeFraction
            if stateTime > 0.6 && !periscopeBlinked { periscopeBlinked = true; blinkT = 0 }
        } else if stateTime < 0.35 + periscopeHold + 0.4 {
            let q = CGFloat((stateTime - 0.35 - periscopeHold) / 0.4)
            depth = g.periscopeFraction + up * q * q
        } else {
            depth = 1
            resumeSubmerged()
        }
        setOrigin(CGPoint(x: origin.x, y: f.minY - g.bodyBottom - depth * g.submergeDepth))
        // head + fin count as the shark while peeking
        let headRect = CGRect(x: origin.x + 40, y: f.minY - 2, width: 90, height: 60)
        if headRect.contains(mouse) && cursorSpeed < 200 && stateTime > 0.35 {
            surface(fast: true, openPanel: true)
        }
    }

    private func surface(fast: Bool, openPanel: Bool) {
        guard isUnderwater, state != .surfacing else { return }
        surfaceFrom = origin.y
        surfaceFast = fast
        surfaceOpenPanel = openPanel
        surfaceDropped = false
        surfaceOvershoot = 0.08
        surfaceDuration = fast ? 0.6 : 1.0
        if cursorSpeed > 900 { surfaceDuration = 0.4; surfaceOvershoot = 0.2; think("!", for: 1) }
        if !fast { lastSelfSurface = time }
        state = .surfacing
        stateTime = 0
    }

    private func updateSurfacing(dt: TimeInterval, mouse: CGPoint) {
        let f = currentScreen.visibleFrame
        let g = PetGeometry.self
        let to = f.minY - g.bodyBottom
        let p = CGFloat(min(1, stateTime / surfaceDuration))
        let k: CGFloat
        if surfaceFast {
            if p < 0.7 {
                let q = p / 0.7
                k = (1 - pow(1 - q, 3)) * (1 + surfaceOvershoot)
            } else {
                let q = (p - 0.7) / 0.3
                k = (1 + surfaceOvershoot) - surfaceOvershoot * q * q
            }
        } else {
            k = 1 - pow(1 - p, 3)
        }
        let y = surfaceFrom + (to - surfaceFrom) * k
        setOrigin(CGPoint(x: origin.x, y: y))
        depth = max(0, min(1.1, (to - y) / g.submergeDepth))
        if p > 0.5 && !surfaceDropped { surfaceDropped = true }
        if p >= 1 {
            setOrigin(CGPoint(x: origin.x, y: to))
            depth = 0
            tilt = 0
            enterIdle()
            pulse(amount: -0.12, duration: 0.3)
            savePosition()
            typingFor = 0
            typingDiveAfter = Double.random(in: 60...90)
            if surfaceOpenPanel && petContains(mouse) { hoverDwell = 0.3; panelCooldownUntil = 0 }
            if let target = pendingComeHere { pendingComeHere = nil; glide(to: target) }
        }
    }

    // MARK: - Animation

    private func think(_ glyph: String, for seconds: TimeInterval = 2.4) {
        pose.thought = glyph
        thoughtUntil = time + seconds
    }

    private func thinkLater(_ glyph: String, after delay: TimeInterval, for seconds: TimeInterval) {
        pendingThoughts.append((time + delay, glyph, seconds))
    }

    private func updateAnimation(dt: TimeInterval, mouse: CGPoint) {
        let t = CGFloat(time)
        let dtf = CGFloat(dt)
        let napping = state == .napping
        let yawning = napping && stateTime < 0.9
        let happy = state == .poked || launchPanel.isShown || dropHovering || time < welcomeUntil

        // little passing thoughts while idle (never while typing)
        if state == .idle && !launchPanel.isShown && !typing && !isQuietTime {
            thoughtIn -= dt
            if thoughtIn <= 0 {
                thoughtIn = Double.random(in: thoughtInterval)
                think(["hm", "…", "?", "♪", "◠‿◠", "beep", "ok"].randomElement() ?? "…")
            }
        }
        if let next = pendingThoughts.first, time >= next.0 {
            pendingThoughts.removeFirst()
            think(next.1, for: next.2)
        }
        pose.thoughtAlpha = approach(pose.thoughtAlpha, time < thoughtUntil ? 1 : 0, rate: 6, dt: dtf)

        // music: the disc keeps turning while something plays; a note now and then
        let playing = music.isPlaying && !isUnderwater
        pose.music = approach(pose.music, playing ? 1 : 0, rate: 3, dt: dtf)
        if playing {
            pose.discAngle += dtf * 3.2
            musicNoteIn -= dt
            if musicNoteIn <= 0 && state == .idle && !typing { musicNoteIn = Double.random(in: 40...90); think("♪", for: 1.6) }
        }

        // blinking
        if napping {
            blinkT = -1
        } else if blinkT >= 0 {
            blinkT += dt
            if blinkT > 0.18 { blinkT = -1; blinkIn = Double.random(in: 2.5...6.5) }
        } else {
            blinkIn -= dt
            if blinkIn <= 0 { blinkT = 0 }
        }
        let blinkOpen: CGFloat = blinkT < 0 ? 1 : CGFloat(abs(cos(Double.pi * blinkT / 0.18)))

        // where to look
        let c = bodyCenterOnScreen
        let dx = mouse.x - c.x, dy = mouse.y - (c.y + 8)
        let dist = hypot(dx, dy)
        let proximity: CGFloat = max(0, 1 - dist / 380)
        var lookTarget = CGPoint.zero
        if napping {
            lookTarget = .zero
        } else if state == .dragging {
            lookTarget = CGPoint(x: 0, y: 0.3)
        } else if dist > 0.5 && mouseStillFor < 60 {
            let k = min(1, dist / 140) * (0.45 + 0.55 * max(0, 1 - dist / 1600))
            lookTarget = CGPoint(x: dx / dist * k, y: dy / dist * k)
            if state == .idle, edge == .bottom || edge == .top || edge == .free, abs(dx) > 60, !typing {
                let want: CGFloat = dx > 0 ? 1 : -1
                if want != pose.facing {
                    oppositeSideFor += dt
                    if oppositeSideFor > 0.8 { pose.facing = want; turnT = 0; oppositeSideFor = 0 }
                } else { oppositeSideFor = 0 }
            }
        } else {
            idleLookIn -= dt
            if idleLookIn <= 0 {
                idleLookIn = Double.random(in: 2...6)
                idleLook = Bool.random() ? .zero : CGPoint(x: CGFloat.random(in: -0.6...0.6), y: CGFloat.random(in: -0.3...0.4))
            }
            lookTarget = idleLook
        }
        pose.look.x = approach(pose.look.x, lookTarget.x * pose.facing, rate: 9, dt: dtf)
        pose.look.y = approach(pose.look.y, lookTarget.y, rate: 9, dt: dtf)

        // eyes
        let eyeTarget: CGFloat = yawning ? 0.3 : (napping ? 0 : (state == .dragging ? 1.15 : blinkOpen * (launchPanel.isShown ? 1.08 : 1)))
        pose.eyeOpen = approach(pose.eyeOpen, eyeTarget, rate: napping ? 3 : 30, dt: dtf)
        if state == .poked || dropHovering { pose.eyeStyle = .happy }
        else if napping && pose.eyeOpen < 0.12 { pose.eyeStyle = .closed }
        else { pose.eyeStyle = .open }

        // fin, flippers, mouth, blush, tail
        let curious = curiousT >= 0
        var earTarget: CGFloat = 0.35 + 0.65 * proximity
        if napping { earTarget = 0.05 }
        else if happy || time < finFlickUntil { earTarget = 1 }
        else if state == .dragging { earTarget = 0.2 }
        else if isUnderwater { earTarget = 0.5 }
        else if curious { earTarget = 0.8 }
        pose.earPerk = approach(pose.earPerk, earTarget, rate: 6, dt: dtf)

        // chomp: poke, launch, drop, yawn
        var chompTarget: CGFloat = 0
        var mouth: Mouth = .neutral
        if state == .poked {
            let p = CGFloat(stateTime / 0.5)
            chompTarget = p < 0.18 ? p / 0.18 : max(0, 1 - (p - 0.18) / 0.14)
            mouth = .chomp
        } else if dropHovering {
            chompTarget = 1; mouth = .chomp
        } else if yawning {
            chompTarget = sin(CGFloat(stateTime / 0.9) * .pi) * 0.8; mouth = .chomp
        } else if happy { mouth = .happy }
        else if state == .dragging { mouth = .surprised }
        else if napping { mouth = .sleepy }
        pose.chomp = approach(pose.chomp, chompTarget, rate: mouth == .chomp && chompTarget > pose.chomp ? 40 : 18, dt: dtf)
        pose.mouth = mouth
        pose.smile = approach(pose.smile, happy ? 1 : 0, rate: 10, dt: dtf)
        pose.blush = approach(pose.blush, happy ? 1 : 0.55, rate: 4, dt: dtf)

        pose.tailPhase += dtf * (happy ? 6 : (napping ? 0.7 : (state == .wandering ? 3 : 1.7)))
        let swayTarget: CGFloat = curious ? 4 * (dx > 0 ? 1 : -1) * pose.facing : 0
        pose.finSway = approach(pose.finSway, swayTarget, rate: 5, dt: dtf)
        // napping tail twitch
        if napping && !yawning {
            tailTwitchIn -= dt
            if tailTwitchIn <= 0 { tailTwitchIn = Double.random(in: 4...7); tailTwitchUntil = time + 0.3 }
        }
        pose.tailWag = approach(pose.tailWag, time < tailTwitchUntil ? 2.5 : (napping ? 0.35 : 1), rate: 6, dt: dtf)

        // lying flat while napping
        pose.flop = approach(pose.flop, (napping && !yawning) ? 1 : 0, rate: napping ? 2 : 6, dt: dtf)

        // bob + squash
        var bob: CGFloat = 0, sx: CGFloat = 1, sy: CGFloat = 1
        let onFloor = edge == .bottom
        switch state {
        case .idle:
            if onFloor { sy = 1 + 0.018 * sin(t * 1.9); sx = 1 - 0.01 * sin(t * 1.9) }
            else { bob = 2.4 * sin(t * 1.6) }
        case .wandering:
            if onFloor { bob = abs(sin(t * 9)) * 3.2; sy = 1 + 0.03 * sin(t * 18) }
            else { bob = 2.4 * sin(t * 1.6) + 1.2 * sin(t * 7) }
        case .napping:
            sy = 1 + 0.035 * sin(t * 1.1); sx = 1 - 0.02 * sin(t * 1.1)
            bob = onFloor ? 0 : 1.5 * sin(t)
        case .poked:
            let p = CGFloat(stateTime / 0.5)
            if p > 0.32 && p < 0.44 { sy = 0.86; sx = 1.08 }
            bob = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : max(0, sin(p * .pi)) * 3
        case .dragging:
            sy = 1.06; sx = 0.96
        case .diving:
            if !diveSkipHop && stateTime < 0.15 { bob = 8 * sin(CGFloat(stateTime / 0.15) * .pi) }
        case .submerged, .periscope, .surfacing, .landing:
            bob = 0
        }
        sx *= 1 + 0.32 * pose.flop
        sy *= 1 - 0.38 * pose.flop
        if pulseT >= 0 {
            pulseT += dt
            let q = CGFloat(pulseT / pulseDuration)
            if q >= 1 { pulseT = -1 } else { let s = sin(q * .pi) * pulseAmount; sy *= 1 + s; sx *= 1 - s * 0.6 }
        }
        if turnT >= 0 {
            turnT += dt
            let q = CGFloat(turnT / 0.22)
            if q >= 1 { turnT = -1 } else { sx *= 1 - 0.18 * sin(q * .pi) }
        }
        if spinT >= 0 {
            spinT += dt
            let q = CGFloat(spinT / 0.45)
            if q >= 1 { spinT = -1 } else { sx *= cos(2 * .pi * q) }
        }
        if gulpT >= 0 {
            gulpT += dt
            let q = CGFloat(gulpT / 0.7)
            if q >= 1 { gulpT = -1 } else {
                let s: CGFloat = q < 0.35 ? 0.18 * sin(q / 0.35 * .pi) : -0.15 * sin((q - 0.35) / 0.65 * .pi)
                sy *= 1 + s; sx *= 1 - s * 0.7
            }
        }
        pose.bob = bob; pose.squashX = sx; pose.squashY = sy

        // tilt: dangling while dragged, nose-down when diving, lean while cruising, head tilt when curious
        if state == .dragging {
            let vx = (origin.x - lastDragX) / max(dtf, 0.001)
            lastDragX = origin.x
            dragVelocity = approach(dragVelocity, vx, rate: 10, dt: dtf)
            tilt = approach(tilt, max(-0.32, min(0.32, -dragVelocity * 0.00045)), rate: 8, dt: dtf)
        } else if state == .submerged {
            tilt = approach(tilt, 0, rate: 3, dt: dtf)
        } else if state != .surfacing {
            tilt = approach(tilt, 0, rate: 8, dt: dtf)
        }
        curiousTilt = approach(curiousTilt, curious ? -0.14 * (dx > 0 ? 1 : -1) : 0, rate: 6, dt: dtf)
        pose.tilt = tilt * pose.facing + curiousTilt

        // shadow, water, sleep bubbles, particles
        var shadowTarget: CGFloat = 0
        if onFloor {
            if state == .landing { shadowTarget = CGFloat(min(1, stateTime / landDuration)) }
            else if state != .dragging && !isUnderwater { shadowTarget = 1 }
        }
        pose.shadow = approach(pose.shadow, shadowTarget, rate: 6, dt: dtf)
        pose.submerged = 0   // no waterline drawing; the screen-edge clip (applyScreenClip) hides the tucked part
        pose.waterline = currentScreen.visibleFrame.minY - origin.y
        pose.ceiling = currentScreen.visibleFrame.maxY - origin.y
        pose.zzz = approach(pose.zzz, (napping && !yawning) ? 1 : 0, rate: 2.5, dt: dtf)
        pose.particles = pose.particles.compactMap { particle in
            var q = particle
            q.life -= dtf
            guard q.life > 0 else { return nil }
            if q.glyph == "•" { q.velocity.dy -= 90 * dtf }
            q.position.x += q.velocity.dx * dtf
            q.position.y += q.velocity.dy * dtf
            q.velocity.dx *= 0.98
            return q
        }
        pose.time = t
    }

    // MARK: - Behaviours

    private func enterIdle() {
        state = .idle
        stateTime = 0
        nextDecisionIn = Double.random(in: 6...16)
    }

    private func decideNext() {
        let sinceNap = time - lastNapEnded
        let userAway = mouseStillFor > 150
        let userBusy = mouseStillFor < 20
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let r = Double.random(in: 0..<1)
        var napChance = sinceNap > 120 ? 0.18 : 0.0
        if userAway { napChance = 0.7 }
        if r < napChance { startNap(); return }
        if !userBusy && !reduceMotion {
            if hugEdges && edge == .bottom && r < napChance + idleDiveChance { startDive(.idle); return }
            if hugEdges && edge != .free && r < napChance + idleDiveChance + 0.3 { startWander(); return }
        }
        if Bool.random() { pulse(amount: 0.08, duration: 0.35) } else { finFlickUntil = time + 0.35 }
        nextDecisionIn = Double.random(in: userBusy ? 8...18 : 5...12)
    }

    private func startWander() {
        let f = currentScreen.visibleFrame
        let g = PetGeometry.self
        let o = origin
        let horizontal = (edge == .bottom || edge == .top)
        let lo: CGFloat, hi: CGFloat, cur: CGFloat
        if horizontal {
            lo = f.minX - g.bodyCenter.x + g.bodyHalfWidth + 4
            hi = f.maxX - g.bodyCenter.x - g.bodyHalfWidth - 4
            cur = o.x
        } else {
            lo = f.minY - g.bodyBottom + 10
            hi = f.maxY - g.earTop - 10
            cur = o.y
        }
        guard hi > lo + 60 else { enterIdle(); return }
        var delta = CGFloat.random(in: 110...300) * (Bool.random() ? 1 : -1)
        var target = min(max(cur + delta, lo), hi)
        if abs(target - cur) < 50 { delta = -delta; target = min(max(cur + delta, lo), hi) }
        wanderTarget = target
        wanderDeadline = time + 14
        if horizontal {
            let newFacing: CGFloat = target < cur ? -1 : 1
            if newFacing != pose.facing { pose.facing = newFacing; turnT = 0 }
        }
        state = .wandering
        stateTime = 0
    }

    private func updateWander(dt: TimeInterval) {
        let horizontal = (edge == .bottom || edge == .top)
        let speed: CGFloat = edge == .bottom ? 46 : 32
        var o = origin
        let cur = horizontal ? o.x : o.y
        let d = wanderTarget - cur
        let step = min(abs(d), speed * CGFloat(dt)) * (d < 0 ? -1 : 1)
        if horizontal { o.x += step } else { o.y += step }
        setOrigin(o)
        if abs(d) < 1.5 || time > wanderDeadline || typing {
            enterIdle()
            savePosition()
        }
    }

    private func startNap() {
        napDuration = Double.random(in: 25...60)
        state = .napping
        stateTime = 0
        tailTwitchIn = Double.random(in: 4...7)
        curiousT = -1
        if launchPanel.isShown { launchPanel.hide() }
    }

    private func wake() {
        lastNapEnded = time
        enterIdle()
        pulse(amount: 0.14, duration: 0.4)
        spawnDroplets(3)
    }

    private func pulse(amount: CGFloat, duration: TimeInterval) {
        pulseAmount = amount
        pulseDuration = duration
        pulseT = 0
    }

    private func poke() {
        if time - lastPoke < 1.6 { pokeCount += 1 } else { pokeCount = 1 }
        lastPoke = time
        if state == .napping { lastNapEnded = time }
        state = .poked
        stateTime = 0
        curiousT = -1
        if pokeCount >= 2 && pokeCount < 4 { spawnParticles("♥", count: pokeCount - 1) }
        if pokeCount == 1 && Bool.random() { think(["!", "hi", "♥", "?"].randomElement() ?? "!", for: 1.4) }
        if pokeCount >= 4 { spinT = 0; think("@_@", for: 2) }
    }

    private func release() {
        let f = currentScreen.visibleFrame
        depth = 0
        if hugEdges && origin.y + PetGeometry.bodyBottom < f.minY - 10
            && !isSeam(CGPoint(x: bodyCenterOnScreen.x, y: f.minY - 3), of: f) {
            // dropped below the edge: dive
            edge = .bottom
            let x = edgeTarget(for: .bottom, in: f, from: origin).x
            setOrigin(CGPoint(x: x, y: f.minY - PetGeometry.bodyBottom))
            state = .idle
            startDive(.drag)
            return
        }
        // stay wherever it was dropped unless it's close to an edge; then tuck into that edge
        let c = bodyCenterOnScreen
        let edgeDistance = min(c.y - f.minY, f.maxY - c.y, c.x - f.minX, f.maxX - c.x)
        edge = (hugEdges && edgeDistance < 150) ? nearestEdge(in: f) : .free
        var from = origin
        if edge == .bottom || edge == .top || edge == .free {
            let toss = max(-250, min(250, dragVelocity * 0.25))
            from.x += toss
            if abs(toss) > 40 { pose.facing = toss > 0 ? 1 : -1 }
        }
        landTo = edgeTarget(for: edge, in: f, from: from)
        landFrom = origin
        if edge == .left { pose.facing = 1 } else if edge == .right { pose.facing = -1 }
        peek = 1; peekTarget = 1; peekChangeIn = Double.random(in: 25...70); peekUntil = time + 3
        let dist = hypot(landTo.x - landFrom.x, landTo.y - landFrom.y)
        if dist < 1 {
            enterIdle()
            pulse(amount: -0.12, duration: 0.25)
            savePosition()
            return
        }
        landDuration = min(max(Double(dist) / 1500, 0.22), 0.65)
        state = .landing
        stateTime = 0
    }

    private func spawnParticles(_ glyph: String, count: Int) {
        let c = PetGeometry.bodyCenter
        for _ in 0..<count {
            let life = CGFloat.random(in: 0.9...1.3)
            pose.particles.append(Particle(
                position: CGPoint(x: c.x + CGFloat.random(in: -20...20), y: pose.bodyTopNow + CGFloat.random(in: 0...10)),
                velocity: CGVector(dx: CGFloat.random(in: -18...18), dy: CGFloat.random(in: 28...48)),
                life: life, maxLife: life, glyph: glyph))
        }
    }

    private func spawnBubbles(_ count: Int) {}   // no water effects for the robot

    private func spawnDroplets(_ count: Int) {}   // no water effects for the robot

    private func launch(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard error != nil else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.think("?", for: 2)
                self.turnT = 0
                if !FileManager.default.fileExists(atPath: url.path) {
                    self.store.remove(url)
                    self.launchPanel.reload()
                }
                self.think("can't open it", for: 2.5)
            }
        }
        launchPanel.hide()
        panelCooldownUntil = time + 0.8
        state = .poked
        stateTime = 0
        pokeCount = 0
        spawnBubbles(3)
    }

    // MARK: - Drops and clipboard (stash)

    func dragHover(_ inside: Bool) {
        dropHovering = inside
        if inside {
            if state == .napping { wake() }
            if isUnderwater { surface(fast: true, openPanel: false) }
            think("give?", for: 3)
        } else {
            thoughtUntil = 0
        }
    }

    func acceptDrop(_ pb: NSPasteboard) -> Bool {
        let store = StashStore.shared
        if store.hasFiles(pb) {
            // big files are copied off the main thread so the shark never freezes
            let urls = store.fileURLs(pb)
            think("…", for: 30)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = store.saveFiles(urls)
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let what = result { self.gulp(what) } else { self.think("?", for: 1.5) }
                }
            }
            return true
        }
        guard let what = store.save(from: pb) else { think("?", for: 1.5); return false }
        gulp(what)
        return true
    }

    private func gulp(_ what: String) {
        gulpT = 0
        think("kept \(what) ✓", for: 2.5)
        spawnBubbles(3)
    }

    func keepClipboard() {
        let store = StashStore.shared
        let pb = NSPasteboard.general
        if store.hasFiles(pb) {
            let urls = store.fileURLs(pb)
            think("…", for: 30)
            launchPanel.flash("keeping…", for: 30)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = store.saveFiles(urls)
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let what = result { self.gulp(what); self.launchPanel.flash("kept \(what)") }
                    else { self.think("?", for: 1.5); self.launchPanel.flash("couldn't keep that") }
                }
            }
            return
        }
        if let what = store.save(from: pb) {
            gulp(what)
            launchPanel.flash("kept \(what)")
        } else {
            think("empty?", for: 1.5)
            launchPanel.flash("clipboard is empty")
        }
    }

    // MARK: - Mouse (from PetView)

    func petMouseDown(at p: CGPoint) {
        pressed = true
        pressStart = p
        pressOrigin = origin
        lastDragX = origin.x
        dragVelocity = 0
        if state == .submerged || state == .periscope { surface(fast: true, openPanel: false) }
    }

    func petMouseDragged(to p: CGPoint) {
        guard pressed else { return }
        if state != .dragging {
            if hypot(p.x - pressStart.x, p.y - pressStart.y) < 4 { return }
            if state == .napping { lastNapEnded = time }
            state = .dragging
            stateTime = 0
            depth = 0
            curiousT = -1
            if launchPanel.isShown { launchPanel.hide() }
            panelCooldownUntil = time + 0.6
        }
        setOrigin(CGPoint(x: pressOrigin.x + (p.x - pressStart.x), y: pressOrigin.y + (p.y - pressStart.y)))
    }

    func petMouseUp(at p: CGPoint) {
        guard pressed else { return }
        pressed = false
        if state == .dragging { release() }
        else if state == .surfacing || state == .diving { return }
        else { poke() }
    }

    // MARK: - Menu

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.addItem(withTitle: "Add app shortcut…", action: #selector(addShortcutAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Manage apps…", action: #selector(manageApps), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Keep clipboard in stash", action: #selector(keepClipboardAction), keyEquivalent: "").target = self
        let n = StashStore.shared.count
        menu.addItem(withTitle: n == 0 ? "Open stash (empty — drop things on the shark)" : "Open stash (\(n))",
                     action: #selector(openStash), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide for a bit (peek out now and then)", action: #selector(swimNow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Nap now", action: #selector(napNow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Come here", action: #selector(comeHere), keyEquivalent: "").target = self
        menu.addItem(withTitle: time < shhUntil ? "Shh for an hour ✓ (tap to end)" : "Shh for an hour",
                     action: #selector(shhHour), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let skinItem = NSMenuItem(title: "Skin", action: nil, keyEquivalent: "")
        let skinMenu = NSMenu()
        for coat in Coat.allCases {
            let item = NSMenuItem(title: coat.title, action: #selector(pickCoat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = coat.rawValue
            item.state = pose.coat == coat ? .on : .off
            skinMenu.addItem(item)
        }
        skinItem.submenu = skinMenu
        menu.addItem(skinItem)

        let moodItem = NSMenuItem(title: "Mood", action: nil, keyEquivalent: "")
        let moodMenu = NSMenu()
        for m in Mood.allCases {
            let item = NSMenuItem(title: m.title, action: #selector(pickMood(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.rawValue
            item.state = mood == m ? .on : .off
            moodMenu.addItem(item)
        }
        moodMenu.addItem(.separator())
        let quiet = moodMenu.addItem(withTitle: "Quiet hours (22:00–08:00)", action: #selector(toggleQuiet), keyEquivalent: "")
        quiet.target = self
        quiet.state = quietHours ? .on : .off
        moodItem.submenu = moodMenu
        menu.addItem(moodItem)

        if let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier,
           id != Bundle.main.bundleIdentifier, let name = front.localizedName {
            let item = menu.addItem(withTitle: "Dive while \(name) is in front", action: #selector(toggleDiveApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = diveApps.contains(id) ? .on : .off
        }
        menu.addItem(.separator())
        let hug = menu.addItem(withTitle: "Hug screen edges", action: #selector(toggleHug), keyEquivalent: "")
        hug.target = self
        hug.state = hugEdges ? .on : .off
        let share = menu.addItem(withTitle: "Hide from screenshots & screen sharing", action: #selector(toggleSharing), keyEquivalent: "")
        share.target = self
        share.state = hideFromSharing ? .on : .off
        if Bundle.main.bundleIdentifier != nil, Bundle.main.bundlePath.hasSuffix(".app") {
            let login = menu.addItem(withTitle: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pet", action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc private func addShortcutAction() { addShortcut() }
    @objc private func manageApps() {
        launchPanel.hide()
        let controller = ManageAppsWindowController.shared
        controller.onChange = { [weak self] in self?.launchPanel.reload() }
        controller.show()
    }
    @objc private func keepClipboardAction() { keepClipboard() }
    @objc private func openStash() { StashStore.shared.reveal() }

    func addShortcut() {
        launchPanel.hide()
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.message = "Pick apps to keep in your shark's pocket"
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { [weak self] response in
            if let previous, previous.bundleIdentifier != Bundle.main.bundleIdentifier {
                if #available(macOS 14.0, *) { NSApp.yieldActivation(to: previous) }
                previous.activate(options: [])
            }
            guard let self, response == .OK else { return }
            for url in panel.urls { self.store.add(url) }
            self.launchPanel.reload()
            self.spawnParticles("♥", count: 2)
        }
    }

    @objc private func pickCoat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let coat = Coat(rawValue: raw) else { return }
        pose.coat = coat
        UserDefaults.standard.set(raw, forKey: Keys.coat)
        pulse(amount: 0.12, duration: 0.35)
        spawnBubbles(2)
    }

    @objc private func pickMood(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let m = Mood(rawValue: raw) else { return }
        mood = m
        UserDefaults.standard.set(raw, forKey: Keys.mood)
        think(m == .chatty ? "yay" : (m == .shy ? "…" : "ok"), for: 1.5)
    }

    @objc private func toggleQuiet() {
        quietHours.toggle()
        UserDefaults.standard.set(quietHours, forKey: Keys.quiet)
    }

    @objc private func shhHour() {
        if time < shhUntil {
            shhUntil = 0
            if isUnderwater { surface(fast: false, openPanel: false) }
            return
        }
        shhUntil = time + 3600
        if launchPanel.isShown { launchPanel.hide() }
        if edge == .bottom && hugEdges { startDive(.shh) } else if state == .idle { startNap() }
    }

    @objc private func toggleDiveApp(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        if diveApps.contains(id) { diveApps.remove(id) } else { diveApps.insert(id) }
        UserDefaults.standard.set(Array(diveApps), forKey: Keys.diveApps)
    }

    @objc private func swimNow() {
        if edge != .bottom || !hugEdges {
            hugEdges = true
            UserDefaults.standard.set(true, forKey: Keys.hugEdges)
            edge = .bottom
            depth = 0
            setOrigin(edgeTarget(for: .bottom, in: currentScreen.visibleFrame, from: origin))
        }
        if state == .napping { wake() }
        startDive(.menu)
    }

    @objc private func napNow() {
        if launchPanel.isShown { launchPanel.hide() }
        if isUnderwater { surface(fast: false, openPanel: false); return }
        startNap()
    }

    @objc func comeHere() {
        let mouse = NSEvent.mouseLocation
        if isUnderwater {
            pendingComeHere = mouse
            surface(fast: true, openPanel: false)
            return
        }
        glide(to: mouse)
    }

    private func glide(to mouse: CGPoint) {
        let f = screen(containing: mouse).visibleFrame
        landFrom = origin
        depth = 0
        edge = hugEdges ? nearestEdge(in: f, at: mouse) : .free
        if edge == .left { pose.facing = 1 } else if edge == .right { pose.facing = -1 }
        peek = 1
        let want = CGPoint(x: mouse.x - PetGeometry.bodyCenter.x, y: mouse.y - PetGeometry.bodyCenter.y)
        landTo = edgeTarget(for: edge, in: f, from: want)
        let dist = hypot(landTo.x - landFrom.x, landTo.y - landFrom.y)
        landDuration = min(max(Double(dist) / 1800, 0.3), 0.8)
        if launchPanel.isShown { launchPanel.hide() }
        state = .landing
        stateTime = 0
    }

    @objc private func toggleHug() {
        hugEdges.toggle()
        UserDefaults.standard.set(hugEdges, forKey: Keys.hugEdges)
        if hugEdges {
            release()
        } else {
            if isUnderwater { depth = 0; setOrigin(edgeTarget(for: .bottom, in: currentScreen.visibleFrame, from: origin)); enterIdle() }
            edge = .free
            savePosition()
        }
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                think("ok", for: 2)
            case .requiresApproval:
                think("allow me in Login Items", for: 4)
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval {
                    think("allow me in Login Items", for: 4)
                    SMAppService.openSystemSettingsLoginItems()
                } else {
                    think("see you tomorrow", for: 2)
                }
            }
        } catch {
            think("hm? couldn't", for: 2.5)
        }
    }

    @objc private func toggleSharing() {
        hideFromSharing.toggle()
        UserDefaults.standard.set(hideFromSharing, forKey: Keys.sharing)
        applySharing()
    }

    @objc private func quit() {
        savePosition()
        NSApp.terminate(nil)
    }

    // MARK: - Headless self-test (run with `Pet --selftest`)

    func selfTest() -> Bool {
        var failures: [String] = []
        func step(_ seconds: Double) {
            for _ in 0..<Int(seconds * 60) {
                lastTick = CACurrentMediaTime() - 1.0 / 60
                tick()
            }
        }
        func expect(_ cond: @autoclosure () -> Bool, _ msg: String) {
            if !cond() { failures.append("\(msg) (state=\(state), depth=\(depth), origin=\(origin))") }
        }
        let f = currentScreen.visibleFrame
        selfTesting = true
        hugEdges = true; edge = .bottom; depth = 0
        firstRunSurfaceAt = -1
        pendingThoughts.removeAll()
        setOrigin(edgeTarget(for: .bottom, in: f, from: CGPoint(x: f.midX, y: 0)))
        enterIdle()
        print("selftest: screen", f)

        startDive(.menu); step(3)
        expect(state == .submerged, "dive should end submerged")
        expect(abs(depth - 1) < 0.05, "cruising depth ~1")
        expect(origin.y + PetGeometry.earTop - 10 < f.minY + 30, "only the fin above the edge")
        startPeriscope(); step(0.5)
        expect(state == .periscope, "periscope entered")
        step(4)
        expect(state == .submerged, "periscope returns to cruising")
        surface(fast: true, openPanel: false); step(2)
        expect(state == .idle, "surface ends idle")
        expect(abs(origin.y - (f.minY - PetGeometry.bodyBottom)) < 0.5, "standing on the edge after surfacing")

        startNap(); step(2); expect(state == .napping, "napping")
        expect(pose.flop > 0.5, "flopped while napping")
        wake(); step(1); expect(state == .idle && pose.flop < 0.2, "wake returns idle and un-flops")

        poke(); step(1); expect(state == .idle, "poke ends idle")
        for _ in 0..<4 { poke() }; step(1); expect(state == .idle, "dizzy pokes end idle")

        // drag it below the edge: should dive
        let c = bodyCenterOnScreen
        petMouseDown(at: c); petMouseDragged(to: CGPoint(x: c.x + 60, y: c.y - 90)); step(0.2)
        expect(state == .dragging, "dragging")
        petMouseUp(at: CGPoint(x: c.x + 60, y: c.y - 90)); step(3)
        expect(state == .submerged, "drop below the edge dives")

        // come here from under water surfaces first, then glides
        comeHere(); step(4)
        expect(state == .idle, "come here from under water ends idle")

        // drag to the left edge and back to the bottom
        petMouseDown(at: bodyCenterOnScreen)
        petMouseDragged(to: CGPoint(x: f.minX + 40, y: f.midY)); step(0.2)
        petMouseUp(at: CGPoint(x: f.minX + 40, y: f.midY)); step(2)
        expect(state == .idle && edge == .left, "released near the left edge → left edge")
        step(20)
        expect(origin.x < f.minX - 20, "tucked behind the left edge")
        petMouseDown(at: bodyCenterOnScreen)
        let dropY = f.minY + (PetGeometry.bodyCenter.y - PetGeometry.bodyBottom) + 24
        petMouseDragged(to: CGPoint(x: f.midX, y: dropY)); step(0.2)
        petMouseUp(at: CGPoint(x: f.midX, y: dropY)); step(2)
        expect(state == .idle && edge == .bottom, "released near the bottom → bottom edge")

        startWander(); step(0.5); expect(state == .wandering, "wander starts")
        step(15); expect(state != .wandering || stateTime < 14, "a wander never outlives its deadline")

        // a long unattended stretch: random decisions, no crash, ends in a sane state
        var seen: Set<String> = []
        for _ in 0..<60 { step(10); seen.insert("\(state)") }
        expect([State.idle, .napping, .submerged, .periscope, .wandering, .diving, .surfacing].contains(state), "sane state after 10 min")
        print("selftest: states seen in 10 min:", seen.sorted())
        toggleHug(); step(2); toggleHug(); step(3)
        expect(state != .dragging, "hug toggle round trip")
        edge = .bottom; depth = 0
        setOrigin(edgeTarget(for: .bottom, in: f, from: CGPoint(x: f.midX, y: 0))); enterIdle(); step(0.5)
        shhHour(); step(4); expect(isUnderwater, "shh dives"); shhHour(); step(3); expect(!isUnderwater, "shh off surfaces")

        if failures.isEmpty { print("selftest: OK") } else { print("selftest: FAILED\n - " + failures.joined(separator: "\n - ")) }
        return failures.isEmpty
    }
}
