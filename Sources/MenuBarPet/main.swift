import AppKit
import SwiftUI
import ServiceManagement
import CoreGraphics
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pet = Pet()
    private lazy var dog = Dog(pet: pet)
    private var strip: StripWindow!
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?
    private var lastTick = Date()
    private var saveCounter = 0

    // break reminders
    private var activeSeconds = 0.0
    private var lastReminderMinute = 0
    private var snoozedUntil = Date.distantPast

    private var weatherTimer: Timer?

    // Mac reactions
    private let reactions = MacReactions()
    private let calendar = CalendarWatcher()
    private var calendarTimer: Timer?
    private var lastPlug: Date?
    private var reactionsEnabled = UserDefaults.standard.object(forKey: "reactions") as? Bool ?? true
    private var calendarEnabled = UserDefaults.standard.bool(forKey: "calendar")

    // quiet mode: manual toggle, or macOS Focus when readable (needs Full Disk Access)
    private var manualQuiet = UserDefaults.standard.bool(forKey: "quiet")
    private let controls = Controls()
    private var focusActive = false
    private var lastFocusPoll = Date.distantPast

    // menu bar visibility
    private var shownAlpha: CGFloat = 1
    private var lastInStrip = Date.distantPast
    private var visibilityTarget: CGFloat = 1
    private var lastVisibilityPoll = Date.distantPast
    private var lastReactionsPoll = Date.distantPast
    private var hideDuringVideo = UserDefaults.standard.object(forKey: "hideDuringVideo") as? Bool ?? true
    private var videoPlaying = false
    private var lastVideoPoll = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        dog.followEnabled = UserDefaults.standard.object(forKey: "follow") as? Bool ?? true
        dog.onPet = { [weak self] in self?.pet.save() }

        controls.quiet = manualQuiet
        controls.follow = dog.followEnabled
        controls.reactions = reactionsEnabled
        controls.onChange = { [weak self] key, value in
            guard let self else { return }
            let d = UserDefaults.standard
            switch key {
            case .quiet: self.manualQuiet = value; d.set(value, forKey: "quiet")
            case .follow: self.dog.followEnabled = value; d.set(value, forKey: "follow")
            case .reactions:
                self.reactionsEnabled = value; d.set(value, forKey: "reactions")
                if !value { self.reactions.reset() }
            }
        }

        strip = StripWindow(dog: dog)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.strip.relayout()
        }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.doghouseIcon()
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        let host = NSHostingController(
            rootView: PopoverView(pet: pet, controls: controls,
                                  onFeed: { [weak self] in self?.feed() },
                                  onThrowBall: { [weak self] in self?.throwBall() },
                                  onPet: { [weak self] in self?.dog.petNow() }))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        timer = Timer.scheduledTimer(withTimeInterval: 1 / Dog.fps, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 0.2 / Dog.fps   // lets macOS coalesce our wakeups with other work
        RunLoop.main.add(timer!, forMode: .common)

        if calendarEnabled { startCalendar() }

        fetchWeather()
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }

    /// SF Symbols has no doghouse, so draw one: peaked roof over a box with an arched doorway.
    /// A template image, so the menu bar tints it for light/dark like a symbol.
    static func doghouseIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let roof = NSBezierPath()
            roof.move(to: NSPoint(x: 0.5, y: 9.5))
            roof.line(to: NSPoint(x: 9, y: 17))
            roof.line(to: NSPoint(x: 17.5, y: 9.5))
            roof.close()
            let house = NSBezierPath()
            house.windingRule = .evenOdd
            house.appendRect(NSRect(x: 3, y: 1.5, width: 12, height: 7))
            // Doorway cut-out: a rectangle topped with a half circle.
            house.move(to: NSPoint(x: 6.5, y: 1.5))
            house.line(to: NSPoint(x: 6.5, y: 5.5))
            house.appendArc(withCenter: NSPoint(x: 9, y: 5.5), radius: 2.5, startAngle: 180, endAngle: 0, clockwise: true)
            house.line(to: NSPoint(x: 11.5, y: 1.5))
            house.close()
            NSColor.black.setFill()
            roof.fill()
            house.fill()
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Pet"
        return img
    }

    func applicationWillTerminate(_ notification: Notification) { pet.save() }

    // MARK: URL scheme: `open -g menubarpet://done` lets other tools (e.g. a Claude Code hook) make the dog bark.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "menubarpet" {
            switch url.host ?? "" {
            case "done", "bark":
                dog.alert("Woof! Done 🐾", seconds: 6)
                pet.cheer(3)
            case "walk":
                dog.alert("Walk? 🦮", seconds: 30)
            default: break
            }
        }
    }

    // MARK: tick

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 5)
        lastTick = now
        pet.advance(seconds: dt)
        updateReminders(dt: dt, now: now)

        let mouse = NSEvent.mouseLocation
        let f = strip.window.frame
        dog.cursorX = (mouse.y >= f.minY && mouse.y <= f.maxY && mouse.x >= f.minX && mouse.x <= f.maxX)
            ? mouse.x - f.minX : nil

        if now.timeIntervalSince(lastFocusPoll) > 10 {
            lastFocusPoll = now
            focusActive = Self.isFocusActive()
        }
        dog.quiet = manualQuiet || focusActive

        if reactionsEnabled {
            if now.timeIntervalSince(lastReactionsPoll) >= 1 {
                lastReactionsPoll = now
                reactions.poll(now: now)
            }
            dog.mac = reactions.state
            if let t = reactions.state.pluggedInAt, t != lastPlug {
                lastPlug = t
                dog.celebrate()
            }
        } else {
            dog.mac = MacState()
        }

        dog.tick()
        // The window-list query is the costliest call here: poll it at 4 Hz, or every tick while fading.
        if shownAlpha != visibilityTarget || now.timeIntervalSince(lastVisibilityPoll) >= 0.25 {
            lastVisibilityPoll = now
            if hideDuringVideo, now.timeIntervalSince(lastVideoPoll) >= 2 {
                lastVideoPoll = now
                videoPlaying = Self.isBrowserPlayingVideo()
            }
            visibilityTarget = (hideDuringVideo && videoPlaying) ? 0 : menuBarVisibility(mouse: mouse, now: now)
        }
        let target = visibilityTarget
        shownAlpha += (target - shownAlpha) * 0.4
        if abs(target - shownAlpha) < 0.02 { shownAlpha = target }
        strip.window.alphaValue = shownAlpha
        if shownAlpha > 0 {
            if !strip.window.isVisible { strip.window.orderFrontRegardless() }
            strip.view.needsDisplay = true
        } else if strip.window.isVisible {
            strip.window.orderOut(nil)   // fully hidden: stop WindowServer compositing the strip
        }
        item.button?.toolTip = "\(pet.name): \(pet.mood)"

        saveCounter += 1
        if saveCounter >= Int(Dog.fps) * 30 { saveCounter = 0; pet.save() }
    }

    /// 0...1: how much of the system menu bar is on screen. It drops to 0 when the bar is
    /// auto-hidden or an app is full screen, and animates while it slides in or out.
    private func menuBarVisibility(mouse: NSPoint, now: Date) -> CGFloat {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return 1
        }
        if isFullScreenSpace(list) {
            if UserDefaults.standard.object(forKey: "showInFullScreen") as? Bool ?? true { return 1 }
            // Full screen: the bar only slides in when the pointer goes to the top; it stays while
            // one of its menus is open.
            let barH = strip.window.frame.height
            if mouse.y >= strip.window.frame.minY { lastInStrip = now }
            let menuOpen = list.contains { w in
                guard (w[kCGWindowLayer as String] as? Int) == 101,
                      let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                      let y = b["Y"] else { return false }
                return y >= barH - 3 && y <= barH + 6
            }
            return (menuOpen || now.timeIntervalSince(lastInStrip) < 1.2) ? 1 : 0
        }
        var best: CGFloat = 0
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 24,
                  (w[kCGWindowOwnerName as String] as? String) == "Window Server",
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let y = b["Y"], let h = b["Height"], let x = b["X"], h > 0, abs(x) < 1 else { continue }
            best = max(best, min(1, max(0, (y + h) / h)))
        }
        return best
    }

    /// True when another app fills the screen. On notched Macs a full-screen app starts below the
    /// 33pt menu bar strip (which stays black and registered as on-screen), so a window from the
    /// bar's bottom edge to the screen's bottom edge counts too. With a visible Dock that can't be a
    /// full-screen space, since the Dock has no on-screen window there.
    private func isFullScreenSpace(_ list: [[String: Any]]) -> Bool {
        guard let screen = NSScreen.screens.first else { return false }
        let barH = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        var coversScreen = false
        var dockOnScreen = false
        for w in list {
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Dock" { dockOnScreen = true; continue }
            guard owner != "MenuBarPet", (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let y = b["Y"], let bw = b["Width"], let bh = b["Height"], let x = b["X"] else { continue }
            if abs(x) < 1, bw >= screen.frame.width - 1, y <= barH + 1, y + bh >= screen.frame.height - 1 {
                coversScreen = true
            }
        }
        guard coversScreen else { return false }
        let dockAutohides = UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "autohide") ?? false
        return dockAutohides || !dockOnScreen
    }

    /// Browsers hold a "prevent display sleep" assertion while a video plays (YouTube, Netflix, Prime...).
    /// Also true for video calls in the browser, which is fine: the pet stays out of the way there too.
    private static func isBrowserPlayingVideo() -> Bool {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let byPid = raw?.takeRetainedValue() as? [Int: [[String: Any]]] else { return false }
        // Safari uses the first type; Chrome uses the second ("Video Wake Lock").
        let displayTypes: Set<String> = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]
        let browsers = ["chrome", "safari", "webkit", "firefox", "arc", "brave", "edge", "opera", "vivaldi"]
        for (_, assertions) in byPid {
            for a in assertions {
                guard let type = a["AssertType"] as? String, displayTypes.contains(type) else { continue }
                let name = (a["Process Name"] as? String ?? "").lowercased()
                if browsers.contains(where: name.contains) { return true }
            }
        }
        return false
    }

    private func updateReminders(dt: Double, now: Date) {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: CGEventType(rawValue: ~0)!)
        if idle >= 300 {
            activeSeconds = 0
            lastReminderMinute = 0
            return
        }
        if idle < 120 { activeSeconds += dt }
        let minutes = Int(activeSeconds / 60)
        if minutes >= 90, minutes / 30 > lastReminderMinute / 30, now >= snoozedUntil {
            lastReminderMinute = minutes
            dog.alert("Time for a walk? 🦮", seconds: 60)
        }
    }

    // MARK: actions

    private func feed() {
        pet.feed()
        dog.startEating()
    }

    private var buttonCenterX: CGFloat {
        guard let b = item.button, let w = b.window else { return strip.window.frame.width / 2 }
        return w.frame.midX - strip.window.frame.minX
    }

    private func throwBall() {
        dog.throwBall(from: buttonCenterX)
        popover.performClose(nil)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            item.menu = buildMenu()
            sender.performClick(nil)
            item.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        func header(_ title: String) {
            if #available(macOS 14, *) {
                menu.addItem(NSMenuItem.sectionHeader(title: title))
            } else {
                let mi = menu.addItem(withTitle: title.uppercased(), action: nil, keyEquivalent: "")
                mi.isEnabled = false
            }
        }
        func add(_ title: String, _ symbol: String, _ action: Selector, key: String = "", on: Bool? = nil) {
            let mi = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            mi.target = self
            mi.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            if let on { mi.state = on ? .on : .off }
        }
        header("Care")
        add("Feed \(pet.name)", "fork.knife", #selector(feedMenu), key: "f")
        add("Throw ball", "tennisball.fill", #selector(throwMenu), key: "t")
        add("Call a visitor", "sparkles", #selector(callVisitor))
        add("Rename…", "pencil", #selector(rename))
        menu.addItem(.separator())
        header("Modes")
        add("Quiet mode", "bell.slash.fill", #selector(toggleQuiet), on: manualQuiet || focusActive)
        add("Follow cursor", "cursorarrow.motionlines", #selector(toggleFollow), on: dog.followEnabled)
        add("React to my Mac", "laptopcomputer", #selector(toggleReactions), on: reactionsEnabled)
        add("Calendar reminders", "calendar", #selector(toggleCalendar), on: calendarEnabled)
        menu.addItem(.separator())
        header("Display")
        add("Hide while watching video", "play.slash", #selector(toggleHideVideo), on: hideDuringVideo)
        add("Walk in front of menu text", "macwindow", #selector(toggleFront), on: strip.inFront)
        add("Snooze walk reminders (1 hr)", "alarm", #selector(snooze))
        add("Launch at Login", "power", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        return menu
    }

    @objc private func feedMenu() { feed() }
    @objc private func throwMenu() { throwBall() }
    @objc private func callVisitor() { dog.spawnVisitor() }

    @objc private func toggleQuiet() {
        controls.quiet.toggle()
    }

    /// Best effort: reads the Focus assertions file. Without Full Disk Access it is unreadable
    /// and this stays false, so only the manual toggle applies.
    private static func isFocusActive() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else { return false }
        return entries.contains { !(($0["storeAssertionRecords"] as? [Any]) ?? []).isEmpty }
    }

    @objc private func toggleFollow() {
        controls.follow.toggle()
    }

    @objc private func toggleHideVideo() {
        hideDuringVideo.toggle()
        UserDefaults.standard.set(hideDuringVideo, forKey: "hideDuringVideo")
        if !hideDuringVideo { videoPlaying = false }
    }

    @objc private func toggleFront() { strip.inFront.toggle() }

    @objc private func toggleReactions() {
        controls.reactions.toggle()
    }

    @objc private func toggleCalendar() {
        if calendarEnabled {
            calendarEnabled = false
            calendarTimer?.invalidate()
            UserDefaults.standard.set(false, forKey: "calendar")
            return
        }
        calendar.requestAccess { [weak self] granted in
            guard let self else { return }
            if granted {
                self.calendarEnabled = true
                UserDefaults.standard.set(true, forKey: "calendar")
                self.startCalendar()
            } else {
                let a = NSAlert()
                a.messageText = "Calendar access denied"
                a.informativeText = "Allow MenuBarPet under System Settings > Privacy & Security > Calendars."
                a.runModal()
            }
        }
    }

    private func startCalendar() {
        calendarTimer?.invalidate()
        calendarTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            if let title = self?.calendar.nextUpcoming() {
                self?.dog.alert("\(title) soon 📅", seconds: 25)
            }
        }
    }

    @objc private func snooze() { snoozedUntil = Date().addingTimeInterval(3600) }

    @objc private func rename() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Rename your dog"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = pet.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let n = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty { pet.name = n }
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: weather (IP-based, via wttr.in; fails silently when offline)

    private func fetchWeather() {
        guard let url = URL(string: "https://wttr.in/?format=%C%7C%t") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("curl/8.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            let parts = text.split(separator: "|").map(String.init)
            guard parts.count == 2 else { return }
            let cond = parts[0].lowercased()
            let temp = Int(parts[1].filter { "-0123456789".contains($0) }) ?? 15
            DispatchQueue.main.async {
                guard let self else { return }
                if ["rain", "drizzle", "shower", "thunder"].contains(where: cond.contains) {
                    self.dog.weather = .rain; self.dog.weatherGlyph = "☔"
                } else if ["snow", "sleet", "ice", "blizzard"].contains(where: cond.contains) || temp <= 2 {
                    self.dog.weather = .cold; self.dog.weatherGlyph = "🥶"
                } else if temp >= 30 {
                    self.dog.weather = .hot; self.dog.weatherGlyph = "💦"
                } else {
                    self.dog.weather = .none; self.dog.weatherGlyph = nil
                }
            }
        }.resume()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
