import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PetController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = PetController()
        controller.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // a little dorsal fin
            let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                let path = NSBezierPath()
                path.move(to: CGPoint(x: 2, y: 4))
                path.curve(to: CGPoint(x: 12.5, y: 15.5), controlPoint1: CGPoint(x: 3, y: 9), controlPoint2: CGPoint(x: 7.5, y: 14))
                path.curve(to: CGPoint(x: 16, y: 4), controlPoint1: CGPoint(x: 14.5, y: 11), controlPoint2: CGPoint(x: 16, y: 7))
                path.close()
                NSColor.black.setFill()
                path.fill()
                let water = NSBezierPath()
                water.lineWidth = 1.4
                water.lineCapStyle = .round
                water.move(to: CGPoint(x: 1, y: 2.2)); water.line(to: CGPoint(x: 17, y: 2.2))
                NSColor.black.setStroke()
                water.stroke()
                return true
            }
            image.isTemplate = true
            button.image = image
            button.toolTip = "Pet — settings, apps and Stash"
        }
        let menu = NSMenu()
        menu.delegate = controller
        statusItem.menu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.savePosition()
    }

    /// Opening Pet.app again brings up the home/settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.showHome()
        return false
    }
}
