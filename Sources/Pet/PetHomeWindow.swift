import AppKit

/// The friendly home for Pet's settings. It keeps the character visible while the user
/// changes appearance and puts the existing app, Stash and behaviour controls in one place.
final class PetHomeWindowController: NSWindowController, NSWindowDelegate {
    private weak var petController: PetController?
    private let room = PetRoomView()
    private let sizeSlider = NSSlider(value: 1, minValue: 0.85, maxValue: 1.15, target: nil, action: nil)
    private let sizeValue = NSTextField(labelWithString: "100%")
    private let appIcons = AppIconStrip()
    private let moodControl = NSSegmentedControl(labels: ["Shy", "Normal", "Chatty"], trackingMode: .selectOne, target: nil, action: nil)
    private let quietSwitch = NSButton(checkboxWithTitle: "Quiet hours · 10 PM–8 AM", target: nil, action: nil)
    private let edgesSwitch = NSButton(checkboxWithTitle: "Hug screen edges", target: nil, action: nil)
    private let sharingSwitch = NSButton(checkboxWithTitle: "Hide from screenshots & sharing", target: nil, action: nil)
    private let loginSwitch = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private var skinButtons: [SkinButton] = []
    private var previousApp: NSRunningApplication?

    init(controller: PetController) {
        petController = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Pet"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1000, height: 740)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        guard let window else { return }
        if !window.isVisible {
            let front = NSWorkspace.shared.frontmostApplication
            if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
            window.center()
        }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        room.pause()
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            if #available(macOS 14.0, *) { NSApp.yieldActivation(to: previousApp) }
            previousApp.activate(options: [])
        }
        previousApp = nil
    }

    func windowDidBecomeKey(_ notification: Notification) { room.resume() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let header = makeHeader()
        let left = makePreviewColumn()
        let right = makeSettingsColumn()
        let divider = NSBox()
        divider.boxType = .separator
        for view in [header, left, right, divider] { view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(view) }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            header.heightAnchor.constraint(equalToConstant: 58),

            left.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            left.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            left.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            left.widthAnchor.constraint(greaterThanOrEqualToConstant: 500),

            divider.topAnchor.constraint(equalTo: left.topAnchor),
            divider.bottomAnchor.constraint(equalTo: left.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 24),
            divider.widthAnchor.constraint(equalToConstant: 1),

            right.topAnchor.constraint(equalTo: left.topAnchor),
            right.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 24),
            right.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            right.bottomAnchor.constraint(equalTo: left.bottomAnchor),
            right.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            left.widthAnchor.constraint(equalTo: right.widthAnchor, multiplier: 1.42),
        ])
    }

    private func makeHeader() -> NSView {
        let view = NSView()
        let title = NSTextField(labelWithString: "Pet")
        title.font = UI.roundedFont(28, .bold)
        let subtitle = NSTextField(labelWithString: "Your little desktop friend")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.layer?.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant: 10), dot.heightAnchor.constraint(equalToConstant: 10)])
        let active = NSTextField(labelWithString: "Active on all Spaces")
        active.font = .systemFont(ofSize: 13, weight: .medium)
        let status = NSStackView(views: [dot, active])
        status.orientation = .horizontal
        status.alignment = .centerY
        status.spacing = 7

        for subview in [labels, status] { subview.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(subview) }
        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            labels.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            status.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    private func makePreviewColumn() -> NSView {
        let column = NSView()
        room.translatesAutoresizingMaskIntoConstraints = false
        column.addSubview(room)

        let sizeTitle = NSTextField(labelWithString: "Size")
        sizeTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        let small = NSTextField(labelWithString: "Small")
        let normal = NSTextField(labelWithString: "Default")
        let large = NSTextField(labelWithString: "Large")
        for label in [small, normal, large] { label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor }
        sizeValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        sizeValue.textColor = .secondaryLabelColor

        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged)
        sizeSlider.isContinuous = true
        sizeSlider.numberOfTickMarks = 3
        sizeSlider.allowsTickMarkValuesOnly = false

        let labelRow = NSView()
        for label in [small, normal, large] { label.translatesAutoresizingMaskIntoConstraints = false; labelRow.addSubview(label) }
        NSLayoutConstraint.activate([
            small.leadingAnchor.constraint(equalTo: labelRow.leadingAnchor),
            normal.centerXAnchor.constraint(equalTo: labelRow.centerXAnchor),
            large.trailingAnchor.constraint(equalTo: labelRow.trailingAnchor),
            small.centerYAnchor.constraint(equalTo: labelRow.centerYAnchor),
            normal.centerYAnchor.constraint(equalTo: labelRow.centerYAnchor),
            large.centerYAnchor.constraint(equalTo: labelRow.centerYAnchor),
        ])

        let titleRow = NSView()
        for item in [sizeTitle, sizeValue] { item.translatesAutoresizingMaskIntoConstraints = false; titleRow.addSubview(item) }
        NSLayoutConstraint.activate([
            sizeTitle.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            sizeTitle.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            sizeValue.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            sizeValue.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
        ])

        let sizeArea = NSStackView(views: [titleRow, sizeSlider, labelRow])
        sizeArea.orientation = .vertical
        sizeArea.spacing = 4
        sizeArea.translatesAutoresizingMaskIntoConstraints = false
        column.addSubview(sizeArea)
        NSLayoutConstraint.activate([
            room.topAnchor.constraint(equalTo: column.topAnchor),
            room.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            room.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            room.bottomAnchor.constraint(equalTo: sizeArea.topAnchor, constant: -18),
            sizeArea.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 18),
            sizeArea.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -18),
            sizeArea.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            sizeArea.heightAnchor.constraint(equalToConstant: 76),
            titleRow.heightAnchor.constraint(equalToConstant: 18),
            labelRow.heightAnchor.constraint(equalToConstant: 16),
        ])
        return column
    }

    private func makeSettingsColumn() -> NSView {
        let skin = makeSkinSection()
        let apps = makeAppsSection()
        let behavior = makeBehaviorSection()
        let actions = makeActions()
        let stack = NSStackView(views: [skin, apps, behavior, actions])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.distribution = .fill
        skin.heightAnchor.constraint(equalToConstant: 154).isActive = true
        apps.heightAnchor.constraint(equalToConstant: 124).isActive = true
        behavior.heightAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        actions.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return stack
    }

    private func makeSkinSection() -> NSView {
        let card = CardView()
        let title = sectionTitle("Skin")
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 5
        row.distribution = .fillEqually
        for (index, coat) in Coat.allCases.enumerated() {
            let button = SkinButton(coat: coat)
            button.tag = index
            button.target = self
            button.action = #selector(skinPicked(_:))
            skinButtons.append(button)
            row.addArrangedSubview(button)
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        return card
    }

    private func makeAppsSection() -> NSView {
        let card = CardView()
        let title = sectionTitle("App Ring")
        let subtitle = NSTextField(labelWithString: "Quick access around Pet")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        let edit = NSButton(title: "Edit Apps…", target: self, action: #selector(editApps))
        edit.bezelStyle = .rounded
        edit.controlSize = .small
        for item in [title, subtitle, edit, appIcons] { item.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(item) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            edit.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            edit.centerYAnchor.constraint(equalTo: title.centerYAnchor, constant: 7),
            appIcons.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            appIcons.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            appIcons.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),
            appIcons.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        return card
    }

    private func makeBehaviorSection() -> NSView {
        let card = CardView()
        let title = sectionTitle("Behavior")
        let moodLabel = NSTextField(labelWithString: "Mood")
        moodLabel.font = .systemFont(ofSize: 12, weight: .medium)
        moodControl.target = self
        moodControl.action = #selector(moodChanged)
        moodControl.controlSize = .small

        let moodRow = NSStackView(views: [moodLabel, moodControl])
        moodRow.orientation = .horizontal
        moodRow.alignment = .centerY
        moodRow.spacing = 12
        moodControl.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let visible = statusRow(symbol: "rectangle.on.rectangle", text: "Visible on all Spaces")
        for toggle in [quietSwitch, edgesSwitch, sharingSwitch, loginSwitch] {
            toggle.target = self
            toggle.action = #selector(toggleChanged(_:))
            toggle.controlSize = .small
            toggle.font = .systemFont(ofSize: 12)
        }
        quietSwitch.tag = 1; edgesSwitch.tag = 2; sharingSwitch.tag = 3; loginSwitch.tag = 4

        let stack = NSStackView(views: [title, moodRow, separator(), quietSwitch, edgesSwitch, sharingSwitch, loginSwitch, visible])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(12, after: title)
        stack.setCustomSpacing(10, after: moodRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12),
            moodRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            moodControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
        return card
    }

    private func makeActions() -> NSView {
        let stash = NSButton(title: "Open Stash", target: self, action: #selector(openStash))
        stash.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: nil)
        let permissions = NSButton(title: "Permissions", target: self, action: #selector(openPermissions))
        permissions.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: nil)
        for button in [stash, permissions] { button.bezelStyle = .rounded; button.imagePosition = .imageLeading }
        let row = NSStackView(views: [stash, permissions])
        row.orientation = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func sectionTitle(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    private func statusRow(symbol: String, text: String) -> NSView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        image.contentTintColor = .systemGreen
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [image, label])
        row.orientation = .horizontal
        row.spacing = 7
        image.widthAnchor.constraint(equalToConstant: 15).isActive = true
        image.heightAnchor.constraint(equalToConstant: 15).isActive = true
        return row
    }

    private func refresh() {
        guard let controller = petController else { return }
        room.update(coat: controller.currentCoat, size: controller.petScale)
        sizeSlider.doubleValue = Double(controller.petScale)
        sizeValue.stringValue = "\(Int((controller.petScale * 100).rounded()))%"
        for (index, button) in skinButtons.enumerated() {
            button.setSelected(Coat.allCases[index] == controller.currentCoat)
        }
        appIcons.reload(urls: controller.store.apps)
        moodControl.selectedSegment = Mood.allCases.firstIndex(of: controller.currentMood) ?? 1
        quietSwitch.state = controller.quietHoursEnabled ? .on : .off
        edgesSwitch.state = controller.hugEdges ? .on : .off
        sharingSwitch.state = controller.hidesFromSharing ? .on : .off
        loginSwitch.state = controller.opensAtLogin ? .on : .off
    }

    @objc private func skinPicked(_ sender: SkinButton) {
        guard Coat.allCases.indices.contains(sender.tag) else { return }
        petController?.setCoat(Coat.allCases[sender.tag])
        refresh()
    }

    @objc private func sizeChanged() {
        let value = CGFloat(sizeSlider.doubleValue)
        petController?.setPetScale(value)
        sizeValue.stringValue = "\(Int((value * 100).rounded()))%"
        room.update(coat: petController?.currentCoat ?? .hojiro, size: value)
    }

    @objc private func moodChanged() {
        guard Mood.allCases.indices.contains(moodControl.selectedSegment) else { return }
        petController?.setMood(Mood.allCases[moodControl.selectedSegment])
    }

    @objc private func toggleChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        switch sender.tag {
        case 1: petController?.setQuietHours(enabled)
        case 2: petController?.setHugEdges(enabled)
        case 3: petController?.setHideFromSharing(enabled)
        case 4: petController?.setOpenAtLogin(enabled)
        default: break
        }
        refresh()
    }

    @objc private func editApps() {
        petController?.showManageApps { [weak self] in self?.refresh() }
    }

    @objc private func openStash() { petController?.showStash() }

    @objc private func openPermissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

private final class CardView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .contentBackground
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class SkinButton: NSButton {
    let coat: Coat

    init(coat: Coat) {
        self.coat = coat
        super.init(frame: .zero)
        title = PetHomeWindowController.shortName(for: coat)
        image = PetThumbnail.image(for: coat, size: NSSize(width: 44, height: 48))
        imagePosition = .imageAbove
        imageScaling = .scaleProportionallyDown
        font = .systemFont(ofSize: 9.5, weight: .medium)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 10
        setAccessibilityLabel("\(title) skin")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ selected: Bool) {
        state = selected ? .on : .off
        layer?.backgroundColor = selected ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor : NSColor.clear.cgColor
        layer?.borderWidth = selected ? 1.5 : 0
        layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : nil
        contentTintColor = selected ? .controlAccentColor : .labelColor
    }
}

private extension PetHomeWindowController {
    static func shortName(for coat: Coat) -> String {
        switch coat {
        case .sand: return "Sand"
        case .hojiro: return "Blue"
        case .deep: return "Navy"
        case .sakura: return "Coral"
        case .mint: return "Forest"
        case .charcoal: return "Charcoal"
        }
    }
}

private enum PetThumbnail {
    private static var cache: [Coat: NSImage] = [:]

    static func image(for coat: Coat, size: NSSize) -> NSImage {
        if let cached = cache[coat] { return cached }
        let view = PetView(frame: NSRect(origin: .zero, size: PetGeometry.viewSize))
        var pose = PetPose()
        pose.coat = coat
        pose.shadow = 1
        view.pose = pose
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return NSImage(size: size) }
        view.cacheDisplay(in: view.bounds, to: rep)
        let source = NSImage(size: view.bounds.size)
        source.addRepresentation(rep)
        let output = NSImage(size: size)
        output.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: size), from: view.bounds, operation: .sourceOver, fraction: 1)
        output.unlockFocus()
        cache[coat] = output
        return output
    }
}

private final class AppIconStrip: NSView {
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload(urls: [URL]) {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        for url in urls.prefix(7) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 34, height: 34)
            let image = NSImageView(image: icon)
            image.toolTip = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            image.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: 34), image.heightAnchor.constraint(equalToConstant: 34)])
            stack.addArrangedSubview(image)
        }
        if urls.isEmpty {
            let label = NSTextField(labelWithString: "No apps yet")
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: 12)
            stack.addArrangedSubview(label)
        }
    }
}

private final class PetRoomView: NSView {
    private let pet = PetView(frame: NSRect(origin: .zero, size: PetGeometry.viewSize))
    private var timer: Timer?
    private var coat: Coat = .hojiro
    private var size: CGFloat = 1
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        addSubview(pet)
        resume()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        pet.frame = NSRect(x: bounds.midX - PetGeometry.viewSize.width / 2,
                           y: max(36, bounds.height * 0.18),
                           width: PetGeometry.viewSize.width,
                           height: PetGeometry.viewSize.height)
    }

    func update(coat: Coat, size: CGFloat) {
        self.coat = coat
        self.size = size
        updatePose()
    }

    func pause() { timer?.invalidate(); timer = nil }

    func resume() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.05
            self.updatePose()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func updatePose() {
        var pose = PetPose()
        pose.coat = coat
        pose.displayScale = size
        pose.shadow = 1
        pose.bob = 1.6 * sin(phase * 1.7)
        pose.eyeStyle = Int(phase * 10) % 83 == 0 ? .closed : .open
        pose.time = phase
        pet.pose = pose
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let top = dark ? NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1) : NSColor(red: 0.88, green: 0.93, blue: 0.98, alpha: 1)
        let bottom = dark ? NSColor(red: 0.24, green: 0.22, blue: 0.20, alpha: 1) : NSColor(red: 0.96, green: 0.90, blue: 0.82, alpha: 1)
        NSGradient(starting: top, ending: bottom)?.draw(in: bounds, angle: 90)

        let floorY = bounds.height * 0.42
        let floor = NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: floorY))
        (dark ? NSColor(red: 0.20, green: 0.18, blue: 0.17, alpha: 0.72) : NSColor(red: 0.82, green: 0.70, blue: 0.56, alpha: 0.34)).setFill()
        floor.fill()

        // Window and sun wash.
        let windowRect = NSRect(x: 34, y: bounds.height - 190, width: 125, height: 142)
        let windowPath = NSBezierPath(roundedRect: windowRect, xRadius: 9, yRadius: 9)
        (dark ? NSColor(red: 0.20, green: 0.28, blue: 0.40, alpha: 0.7) : NSColor(red: 0.78, green: 0.91, blue: 1, alpha: 0.9)).setFill()
        windowPath.fill()
        NSColor.white.withAlphaComponent(dark ? 0.18 : 0.72).setStroke()
        windowPath.lineWidth = 5
        windowPath.stroke()
        let muntin = NSBezierPath()
        muntin.move(to: CGPoint(x: windowRect.midX, y: windowRect.minY)); muntin.line(to: CGPoint(x: windowRect.midX, y: windowRect.maxY))
        muntin.move(to: CGPoint(x: windowRect.minX, y: windowRect.midY)); muntin.line(to: CGPoint(x: windowRect.maxX, y: windowRect.midY))
        muntin.lineWidth = 3; muntin.stroke()

        // Shelf, plant and Pet's soft rug.
        let shelf = NSBezierPath(roundedRect: NSRect(x: bounds.width - 190, y: bounds.height - 150, width: 145, height: 9), xRadius: 4, yRadius: 4)
        (dark ? NSColor.systemBrown.withAlphaComponent(0.55) : NSColor.systemBrown.withAlphaComponent(0.44)).setFill(); shelf.fill()
        let pot = NSBezierPath(roundedRect: NSRect(x: bounds.width - 102, y: bounds.height - 141, width: 35, height: 32), xRadius: 7, yRadius: 7)
        NSColor.systemOrange.withAlphaComponent(0.6).setFill(); pot.fill()
        NSColor.systemGreen.withAlphaComponent(0.70).setFill()
        for offset in [CGPoint(x: -14, y: 31), CGPoint(x: 2, y: 39), CGPoint(x: 15, y: 26), CGPoint(x: -2, y: 21)] {
            NSBezierPath(ovalIn: NSRect(x: bounds.width - 84 + offset.x - 11, y: bounds.height - 111 + offset.y - 9, width: 22, height: 18)).fill()
        }
        let rug = NSBezierPath(ovalIn: NSRect(x: bounds.midX - 135, y: 34, width: 270, height: 92))
        (dark ? NSColor.systemBlue.withAlphaComponent(0.16) : NSColor.white.withAlphaComponent(0.60)).setFill(); rug.fill()

        let caption = NSAttributedString(string: "Changes appear on Pet right away", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        caption.draw(at: CGPoint(x: 18, y: 16))
    }
}
