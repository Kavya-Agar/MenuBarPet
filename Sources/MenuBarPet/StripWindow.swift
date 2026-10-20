import AppKit

/// Transparent, click-through window covering the whole menu bar; the dog walks inside it.
final class StripView: NSView {
    let dog: Dog
    init(dog: Dog) {
        self.dog = dog
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { dog.draw(in: bounds) }
}

final class StripWindow {
    static let frontKey = "walkInFront"

    let window: NSWindow
    let view: StripView

    var inFront: Bool {
        get { UserDefaults.standard.object(forKey: StripWindow.frontKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: StripWindow.frontKey)
            applyLevel()
        }
    }

    init(dog: Dog) {
        view = StripView(dog: dog)
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = view
        applyLevel()
        relayout()
        window.orderFrontRegardless()
    }

    /// Below the menu bar layer the dog walks behind the menu text; above it, in front.
    private func applyLevel() {
        let base = Int(CGWindowLevelForKey(inFront ? .statusWindow : .mainMenuWindow))
        window.level = NSWindow.Level(rawValue: inFront ? base + 1 : base - 1)
    }

    func relayout() {
        guard let screen = NSScreen.screens.first else { return }
        let h = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        window.setFrame(NSRect(x: screen.frame.minX, y: screen.frame.maxY - h,
                               width: screen.frame.width, height: h), display: true)
        view.dog.width = screen.frame.width
    }
}
