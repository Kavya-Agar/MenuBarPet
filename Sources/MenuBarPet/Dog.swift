import AppKit

enum Weather { case none, rain, cold, hot }

/// Rough time-of-day mood: peppy in the morning, calm in the evening, asleep at night.
enum DayPhase {
    case morning, day, evening, night

    init(hour: Int) {
        switch hour {
        case 7..<11: self = .morning
        case 11..<17: self = .day
        case 17..<23: self = .evening
        default: self = .night
        }
    }

    var statusEmoji: String {
        switch self {
        case .morning: return "☀️"
        case .day: return "🌤️"
        case .evening: return "🌇"
        case .night: return "🌙"
        }
    }

    var statusText: String {
        switch self {
        case .morning: return "Morning · extra zoomy"
        case .day: return "Daytime · business as usual"
        case .evening: return "Evening · winding down"
        case .night: return "Night · fast asleep"
        }
    }

    var speedFactor: CGFloat {
        switch self {
        case .morning: return 1.25
        case .evening: return 0.75
        default: return 1
        }
    }
}

struct Ball {
    static let flightTicks = 14
    var startX: CGFloat
    var landX: CGFloat
    var t = 0
    var landed: Bool { t >= Ball.flightTicks }
}

/// What a visitor is and how it behaves. Sprites are `sprites/visitors/<name>_<i>.png`.
struct VisitorKind {
    enum Motion {
        case walk          // along the floor
        case fly(CGFloat)  // bobbing at a height
        case bounce        // hopping ball-style
        case hop           // small hops
        case leap          // arcing leaps
        case sit(CGFloat)  // waits at a height until caught or it times out
        case fall          // drops from the top, then sits
    }
    /// What happens when the pet reaches it.
    enum Catch { case startle, eat, collect, hatch }

    let name: String
    let motion: Motion
    let speed: CGFloat
    let catching: Catch
    var chased = true       // false: the pet ignores it
    var dithers = false     // wanders back and forth while crossing
    var takesOff = false    // lifts off when startled
    var joy: Double = 3     // cheer when caught
    var weight = 1.0        // spawn likelihood
    var lifetime = 240      // ticks a stationary visitor waits before leaving

    var isStationary: Bool {
        switch motion { case .sit, .fall: return true; default: return false }
    }

    /// The midday treat: a bone for the dogs, a tomato for Kirby, a melon for Yoshi.
    static func lunch(for skin: Skin) -> VisitorKind {
        let name = skin == .kirby ? "tomato" : skin == .yoshi ? "melon" : "bone"
        return VisitorKind(name: name, motion: .sit(1), speed: 0, catching: .eat, joy: 8, lifetime: 1200)
    }

    private static let dogBase = [
        VisitorKind(name: "butterfly", motion: .fly(7), speed: 1.6, catching: .startle, dithers: true, takesOff: true),
        VisitorKind(name: "squirrel", motion: .walk, speed: 4, catching: .startle),
        VisitorKind(name: "cat", motion: .walk, speed: 3, catching: .startle),
        VisitorKind(name: "rabbit", motion: .hop, speed: 3.5, catching: .startle),
        VisitorKind(name: "mailman", motion: .walk, speed: 2, catching: .startle),
        VisitorKind(name: "ball", motion: .bounce, speed: 2.5, catching: .collect, joy: 8),
    ]

    static func pool(for skin: Skin) -> [VisitorKind] {
        switch skin {
        case .blue, .wolf, .black:
            return dogBase
        case .akita:
            return dogBase + [
                VisitorKind(name: "koi", motion: .leap, speed: 2.5, catching: .startle),
                VisitorKind(name: "crane", motion: .walk, speed: 2.5, catching: .startle, takesOff: true),
            ]
        case .kirby:
            return [
                VisitorKind(name: "waddledee", motion: .walk, speed: 2, catching: .eat),
                VisitorKind(name: "waddledoo", motion: .walk, speed: 2.5, catching: .eat),
                VisitorKind(name: "gordo", motion: .bounce, speed: 2.5, catching: .startle, chased: false, weight: 0.6),
                VisitorKind(name: "warpstar", motion: .fly(8), speed: 2.5, catching: .collect, joy: 12, weight: 0.4),
                VisitorKind(name: "tomato", motion: .sit(1), speed: 0, catching: .collect, joy: 10, weight: 0.5),
                VisitorKind(name: "scarfy", motion: .fly(9), speed: 2, catching: .startle, takesOff: true),
                VisitorKind(name: "bronto", motion: .fly(10), speed: 3.5, catching: .startle, takesOff: true),
                VisitorKind(name: "apple", motion: .fall, speed: 0, catching: .eat, joy: 4),
            ]
        case .yoshi:
            return [
                VisitorKind(name: "koopa", motion: .walk, speed: 1.6, catching: .eat),
                VisitorKind(name: "goomba", motion: .walk, speed: 2.2, catching: .eat),
                VisitorKind(name: "shyguy", motion: .walk, speed: 2.6, catching: .eat),
                VisitorKind(name: "bullet", motion: .fly(9), speed: 8, catching: .startle, chased: false, weight: 0.5),
                VisitorKind(name: "boo", motion: .fly(8), speed: 1.8, catching: .startle, takesOff: true),
                VisitorKind(name: "coin", motion: .sit(7), speed: 0, catching: .collect, joy: 8, weight: 0.6),
                VisitorKind(name: "star", motion: .bounce, speed: 3, catching: .collect, joy: 18, weight: 0.25),
                VisitorKind(name: "egg", motion: .sit(1), speed: 0, catching: .hatch, joy: 8, weight: 0.5),
            ]
        }
    }
}

/// A small guest that crosses the bar. The pet chases it and, depending on the guest, scares it off,
/// eats it, collects it or hatches it.
struct Visitor {
    enum Fate { case free, startled, eaten, collected }
    let kind: VisitorKind
    var x: CGFloat
    var dir: CGFloat
    var t = 0
    var fate = Fate.free
    var fateT = 0           // ticks since the fate changed

    var speed: CGFloat { fate == .startled ? kind.speed * 3 : kind.speed }

    /// Height above the bar's floor.
    var lift: CGFloat {
        let bob = sin(CGFloat(t) * 0.5) * 3
        var base: CGFloat
        switch kind.motion {
        case .walk: base = 1
        case .fly(let h): base = h + bob
        case .bounce: base = 1 + abs(sin(CGFloat(t) * 0.35)) * 8
        case .hop: base = 1 + abs(sin(CGFloat(t) * 0.6)) * 5
        case .leap: base = 2 + abs(sin(CGFloat(t) * 0.18)) * 12
        case .sit(let h): base = h + (h > 2 ? bob * 0.5 : 0)
        case .fall: base = max(1, 36 - CGFloat(t) * 4)
        }
        if fate == .startled, kind.takesOff { base += min(14, CGFloat(fateT) * 1.5) }
        return base
    }
}

/// Animation + behaviour, modeled on vscode-pets: idle, walk, walk fast, run, lie down.
/// Priorities: eating > fetch > alert > follow cursor > sleep/sad > wander.
final class Dog {
    enum Mode { case idle, walk, walkFast, run, lie }

    static let fps = 8.0

    let pet: Pet
    var width: CGFloat = 800
    var followEnabled = true
    var weather: Weather = .none
    var weatherGlyph: String?
    /// Cursor x in strip coordinates, nil when the cursor is outside the menu bar.
    var mac = MacState()
    var cursorX: CGFloat?
    /// Quiet mode (Do Not Disturb): no barks or reminders, no cursor chasing, mostly resting.
    var quiet = false
    var onPet: (() -> Void)?
    var onFetchDone: (() -> Void)?

    private(set) var mode: Mode = .idle
    private var x: CGFloat = 200
    private var dir: CGFloat = 1
    private var frame = 0
    private var ticksLeft = 16

    private var eatTicks = 0
    /// The current meal is a caught visitor, not food: no 🍖, and the visitor is pulled into the mouth.
    private var eatingVisitor = false
    private var heartTicks = 0
    private var hoverTicks = 0
    private var petCooldown = 0
    private var belly = false
    private var bellyTicks = 0
    private var lastPhase = DayPhase(hour: Calendar.current.component(.hour, from: Date()))

    private(set) var ball: Ball?
    private var carrying = false

    private var alertText: String?
    private var alertUntil = Date.distantPast

    init(pet: Pet) { self.pet = pet }

    // MARK: events

    /// The Pet button: same reward as hovering over the dog.
    func petNow() {
        heartTicks = 14
        pet.cheer(4)
        pet.timesPetted += 1
        pet.save()
    }

    func celebrate() { heartTicks = 20; pet.cheer(2) }

    static let eatDuration = 22
    func startEating() { eatTicks = Self.eatDuration; heartTicks = 0 }

    func throwBall(from originX: CGFloat) {
        guard ball == nil, !carrying else { return }
        var land = originX + CGFloat.random(in: 150...500) * (Bool.random() ? 1 : -1)
        land = min(max(land, 30), width - 30)
        ball = Ball(startX: originX, landX: land)
    }

    func alert(_ text: String, seconds: Double) {
        guard !quiet else { return }
        alertText = text
        alertUntil = Date().addingTimeInterval(seconds)
    }

    var isAlerting: Bool { alertText != nil && Date() < alertUntil }

    // MARK: geometry

    private var phase: DayPhase { DayPhase(hour: Calendar.current.component(.hour, from: Date())) }
    private var isNight: Bool { phase == .night }

    private var animKey: String { animKey(mode) }

    private func animKey(_ mode: Mode) -> String {
        switch mode {
        case .idle: return "idle"
        case .walk: return "walk"
        case .walkFast: return "walk_fast"
        case .run: return "run"
        case .lie: return "lie"
        }
    }

    /// Kirby and Yoshi have an eating animation; other skins have no such animation and just stand.
    private var isInhaling: Bool { eatTicks > 0 && !(Sprites.frames[pet.skin]?["inhale"] ?? []).isEmpty }
    private var images: [NSImage] { Sprites.frames[pet.skin]?[isInhaling ? "inhale" : animKey] ?? [] }
    private var scale: CGFloat { pet.stageScale }
    private var spriteWidth: CGFloat { (images.first?.size.width ?? 24) * scale }
    private var centerX: CGFloat { x + spriteWidth / 2 }

    private func speed(_ m: Mode) -> CGFloat {
        switch m {
        case .walk: return 3 * phase.speedFactor
        case .walkFast: return 5 * phase.speedFactor
        case .run: return 9 * phase.speedFactor
        default: return 0
        }
    }

    // MARK: behaviour

    /// Head toward `target`, returns true on arrival.
    @discardableResult
    private func steer(to target: CGFloat, stop: CGFloat = 10) -> Bool {
        let d = target - centerX
        if abs(d) <= stop {
            mode = .idle
            return true
        }
        dir = d > 0 ? 1 : -1
        let a = abs(d)
        mode = a > 250 ? .run : a > 90 ? .walkFast : .walk
        return false
    }

    private func wander() {
        ticksLeft -= 1
        if ticksLeft > 0 { return }
        var table: [(Mode, Int)]
        if pet.isSad || weather == .hot || mac.batteryLow {
            table = [(.lie, 70), (.idle, 20), (.walk, 10)]
        } else if mac.cpuHot {
            table = [(.idle, 60), (.walk, 25), (.lie, 15)]   // fanning himself instead of lying down
        } else if mac.charging {
            table = [(.lie, 75), (.idle, 25)]                // naps while the Mac charges
        } else if quiet {
            table = [(.lie, 60), (.idle, 30), (.walk, 10)]
        } else if mac.typing {
            table = [(.idle, 100)]
        } else if mac.musicPlaying {
            table = [(.idle, 85), (.walk, 15)]
        } else if weather == .rain {
            table = [(.idle, 40), (.walk, 30), (.lie, 25), (.walkFast, 5)]
        } else {
            switch phase {
            case .morning: table = [(.idle, 15), (.walk, 30), (.walkFast, 25), (.run, 22), (.lie, 8)]
            case .evening: table = [(.idle, 30), (.walk, 40), (.walkFast, 5), (.run, 2), (.lie, 23)]
            default: table = [(.idle, 25), (.walk, 40), (.walkFast, 12), (.run, 8), (.lie, 15)]
            }
        }
        var roll = Int.random(in: 0..<table.reduce(0) { $0 + $1.1 })
        for (m, w) in table {
            if roll < w { mode = m; break }
            roll -= w
        }
        if speed(mode) > 0, Bool.random() { dir = -dir }
        ticksLeft = Int.random(in: 24...80)
        if mode == .lie { ticksLeft = Int.random(in: 48...140) }
        if mode == .run { ticksLeft = Int.random(in: 16...40) }
    }

    func tick() {
        frame += 1
        if heartTicks > 0 { heartTicks -= 1 }
        if petCooldown > 0 { petCooldown -= 1 }

        let now = phase
        if now != lastPhase {
            if lastPhase == .night, now == .morning { alert("Good morning! ☀️", seconds: 8) }
            lastPhase = now
        }

        if var b = ball, !b.landed { b.t += 1; ball = b }
        updateVisitor()
        updateLunch()
        updatePrints()

        if eatTicks > 0 {
            eatTicks -= 1
            mode = .idle
            if eatTicks == 0, eatingVisitor { eatingVisitor = false; visitor = nil }
        } else if let b = ball {
            steer(to: b.landX)
            if b.landed && abs(b.landX - centerX) <= 12 {
                ball = nil
                carrying = true
                // `landX` was the pickup spot; bring it back to where it was thrown from.
                returnX = b.startX
            }
        } else if carrying {
            if steer(to: returnX, stop: 14) {
                carrying = false
                heartTicks = 20
                pet.cheer(15)
                onFetchDone?()
            }
        } else if isAlerting {
            steer(to: width / 2)
        } else if let v = visitor, v.fate == .free, v.kind.chased, canChase {
            if steer(to: v.x, stop: 14) { catchVisitor(v) }
        } else if followEnabled, !quiet, !pet.isSad, !isNight, !mac.batteryLow, !mac.cpuHot, let cx = cursorX, abs(cx - centerX) < 700 {
            steer(to: cx, stop: 10)
        } else if isNight || pet.isSad || mac.batteryLow {
            if mode != .lie { mode = .lie }
        } else {
            wander()
        }

        // Sit up and watch the screen while you type.
        if mac.typing, mode == .idle, eatTicks == 0 { dir = width / 2 > centerX ? 1 : -1 }

        updatePetting()
        move()
    }

    private var returnX: CGFloat = 0

    // MARK: visitors

    private(set) var visitor: Visitor?

    /// Also callable from the menu ("Call a visitor").
    func spawnVisitor() {
        guard visitor == nil else { return }
        let pool = VisitorKind.pool(for: pet.skin)
        var pick = Double.random(in: 0..<pool.reduce(0) { $0 + $1.weight })
        var kind = pool[0]
        for k in pool { if pick < k.weight { kind = k; break }; pick -= k.weight }
        spawn(kind)
    }

    private func spawn(_ kind: VisitorKind) {
        let fromLeft = Bool.random()
        let x = kind.isStationary ? CGFloat.random(in: 60...max(61, width - 60)) : (fromLeft ? -10 : width + 10)
        visitor = Visitor(kind: kind, x: x, dir: fromLeft ? 1 : -1)
    }

    /// Once a day around noon a treat turns up on the bar.
    private func updateLunch() {
        guard frame % 16 == 0, visitor == nil, canChase else { return }
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        guard c.hour == 12, (c.minute ?? 0) < 30 else { return }
        let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        guard UserDefaults.standard.string(forKey: "lastLunch") != key else { return }
        UserDefaults.standard.set(key, forKey: "lastLunch")
        spawn(VisitorKind.lunch(for: pet.skin))
        alert("Lunch time!", seconds: 8)
    }

    private var canChase: Bool {
        !quiet && !isNight && !pet.isSad && !mac.batteryLow && !mac.cpuHot
    }

    /// The pet reached a visitor.
    private func catchVisitor(_ v: Visitor) {
        heartTicks = 14
        pet.cheer(v.kind.joy)
        visitor?.fateT = 0
        switch v.kind.catching {
        case .startle:
            visitor?.fate = .startled
        case .eat:
            visitor?.fate = .eaten
            startEating()
            eatingVisitor = true
            heartTicks = 14
        case .collect, .hatch:
            visitor?.fate = .collected
        }
    }

    private func updateVisitor() {
        guard var v = visitor else {
            // About one visitor every ~90s on average.
            if canChase, Int.random(in: 0..<Int(Dog.fps * 90)) == 0 { spawnVisitor() }
            return
        }
        v.t += 1
        v.fateT += 1
        switch v.fate {
        case .eaten:
            break   // held in place; the eating timer removes it
        case .collected:
            // Gone at once, except a hatching egg which cracks open for a moment first.
            if v.kind.catching != .hatch || v.fateT > 8 { visitor = nil; return }
        default:
            if v.kind.isStationary {
                if v.t >= v.kind.lifetime { visitor = nil; return }
            } else {
                v.x += v.dir * v.speed
                // Butterflies dawdle and change direction; others just cross.
                if v.kind.dithers, v.fate == .free, v.t < 200, Int.random(in: 0..<40) == 0 { v.dir = -v.dir }
                if v.t >= 200, v.fate == .free { v.dir = v.x > width / 2 ? 1 : -1 }
                if v.x < -24 || v.x > width + 24 { visitor = nil; return }
            }
        }
        visitor = v
    }

    /// Hovering the cursor over the dog pets it; keep hovering and it rolls over for a belly rub.
    private func updatePetting() {
        if let cx = cursorX, cx >= x - 2, cx <= x + spriteWidth + 2 {
            hoverTicks += 1
        } else {
            hoverTicks = 0
        }
        let free = eatTicks == 0 && ball == nil && !carrying
        if hoverTicks >= 8, free {
            // Hold still while being petted.
            if mode != .lie { mode = .idle }
            ticksLeft = max(ticksLeft, 10)
        }
        if hoverTicks >= 8, petCooldown == 0, free {
            heartTicks = 14
            petCooldown = 48
            pet.cheer(4)
            pet.timesPetted += 1
            onPet?()
        }

        if hoverTicks >= 30, free {
            if !belly {
                belly = true
                bellyTicks = 0
                pet.bellyRubs += 1
                onPet?()
            }
            mode = .lie
            ticksLeft = max(ticksLeft, 10)
            bellyTicks += 1
            if bellyTicks % 16 == 0 { pet.cheer(3) }
        } else {
            belly = false
        }
    }

    private func move() {
        x += dir * speed(mode)
        let maxX = width - spriteWidth
        if x <= 0 { x = 0; dir = 1 }
        if x >= maxX { x = max(0, maxX); dir = -1 }
    }

    // MARK: footprints

    struct Footprint { var x: CGFloat; var floorY: CGFloat?; var age = 0; var low: Bool }
    private var prints: [Footprint] = []
    private var stepDistance: CGFloat = 0
    private var stepLow = false
    private static let printLife = 28

    private func updatePrints() {
        for i in prints.indices { prints[i].age += 1 }
        prints.removeAll { $0.age >= Self.printLife }
        let v = speed(mode)
        guard v > 0, eatTicks == 0 else { stepDistance = 0; return }
        stepDistance += v
        if stepDistance >= 14 {
            stepDistance = 0
            stepLow.toggle()
            prints.append(Footprint(x: centerX - dir * spriteWidth * 0.18, floorY: nil, low: stepLow))
        }
    }

    private var printColor: NSColor {
        switch pet.skin {
        case .blue: return NSColor(red: 0.16, green: 0.36, blue: 0.68, alpha: 1)
        case .wolf: return NSColor(white: 0.35, alpha: 1)
        case .black: return NSColor(white: 0.1, alpha: 1)
        case .akita: return NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        case .kirby: return NSColor(red: 0.9, green: 0.4, blue: 0.6, alpha: 1)
        case .yoshi: return NSColor(red: 0.25, green: 0.6, blue: 0.2, alpha: 1)
        }
    }

    private func drawPrints(floorY: CGFloat) {
        for i in prints.indices {
            if prints[i].floorY == nil { prints[i].floorY = floorY }
            let p = prints[i]
            let fade = 1 - CGFloat(p.age) / CGFloat(Self.printLife)
            printColor.withAlphaComponent(fade * 0.65).setFill()
            let px = p.x.rounded(), py = ((p.floorY ?? floorY) + (p.low ? 0 : 2)).rounded()
            if pet.skin == .kirby || pet.skin == .yoshi {
                NSRect(x: px - 2, y: py, width: 4, height: 2).fill()      // a foot
            } else {
                NSRect(x: px - 1, y: py, width: 3, height: 2).fill()      // paw pad
                for (dx, dy) in [(-2, 2), (-1, 3), (1, 3), (2, 2)] {      // toes
                    NSRect(x: px + CGFloat(dx), y: py + CGFloat(dy), width: 1, height: 1).fill()
                }
            }
        }
    }

    // MARK: dance and watching

    private var isDancing: Bool { mac.musicPlaying && mode == .idle && eatTicks == 0 && !belly }
    private var isWatching: Bool { mac.typing && !mac.musicPlaying && mode == .idle && eatTicks == 0 && !belly }

    private struct Pose { var dx: CGFloat = 0, dy: CGFloat = 0, rot: CGFloat = 0, stretch: CGFloat = 1, flipped = false }

    /// Each track gets its own tempo (about 96-160 BPM) and move order, changing every eight beats.
    /// The app can't hear the audio, so the track name decides.
    private func pose() -> Pose {
        var p = Pose()
        if isDancing {
            var h: UInt32 = 5381
            for b in (mac.track ?? "music").utf8 { h = h &* 33 &+ UInt32(b) }
            let beat = 3 + Int(h % 3)
            let beatIndex = frame / beat
            let phase = CGFloat(frame % beat) / CGFloat(beat)
            let pulse = abs(sin(.pi * phase))
            switch (Int(h / 7) + beatIndex / 8) % 5 {
            case 0: p.dy = pulse * 3                                                   // bounce
            case 1: p.rot = sin(CGFloat(frame) * .pi / CGFloat(beat)) * 0.17; p.dy = pulse   // sway
            case 2: p.flipped = beatIndex % 2 == 1; p.dy = pulse * 2                    // turn on the beat
            case 3: p.dy = pulse * 6; p.stretch = 1 + 0.1 * pulse                       // big hop
            default:
                p.dx = sin(CGFloat(frame) * 1.9) * 1.6                                  // shimmy
                p.rot = sin(CGFloat(frame) * 1.9) * 0.05
            }
        } else if isWatching {
            p.stretch = 1.08                                                            // sitting up
            p.rot = (frame / 10) % 2 == 0 ? 0.08 : -0.08                                // curious head tilt
        }
        return p
    }

    // MARK: drawing

    func draw(in bounds: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.imageInterpolation = .none

        let imgs = images
        guard !imgs.isEmpty else { return }
        let idx = isInhaling ? min(imgs.count - 1, (Self.eatDuration - eatTicks) * imgs.count / Self.eatDuration)
                             : frame % imgs.count
        let img = imgs[idx]
        let w = img.size.width, h = img.size.height
        let floorY = max(1, (bounds.height - h * scale) / 2)
        let pz = pose()
        let y = floorY + pz.dy
        drawPrints(floorY: floorY)

        let cg = ctx.cgContext
        cg.saveGState()
        cg.translateBy(x: x + pz.dx, y: y)
        if pz.rot != 0 || pz.stretch != 1 {
            // Tilt and stretch about the feet.
            cg.translateBy(x: w * scale / 2, y: 0)
            cg.rotate(by: pz.rot)
            cg.scaleBy(x: 1, y: pz.stretch)
            cg.translateBy(x: -w * scale / 2, y: 0)
        }
        if belly {
            // Belly up.
            cg.translateBy(x: 0, y: h * scale)
            cg.scaleBy(x: 1, y: -1)
        }
        if (dir < 0) != pz.flipped {
            cg.translateBy(x: w * scale, y: 0)
            cg.scaleBy(x: -1, y: 1)
        }
        cg.scaleBy(x: scale, y: scale)
        img.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        drawAccessories(w: w, h: h, img: img, key: "\(pet.skin.rawValue)/\(isInhaling ? "inhale" : animKey)/\(idx)")
        cg.restoreGState()

        drawBall(barHeight: bounds.height, y: y)
        drawVisitor(barHeight: bounds.height)
        drawGlyph(y: y, h: h * scale)
        drawBubble(barHeight: bounds.height)
    }

    /// Where hats and props go: the top of the head and the neck, per skin and frame.
    private func anchors(w: CGFloat, h: CGFloat, img: NSImage, key: String) -> (head: NSPoint, neck: NSPoint) {
        let lying = mode == .lie
        var head = NSPoint(x: w * 0.74, y: lying ? h * 0.72 : h * 0.97)
        var neck = NSPoint(x: w * 0.6, y: lying ? h * 0.3 : h * 0.45)
        if pet.skin == .yoshi {
            // Hats ride the top of the head; the scarf wraps the neck below it.
            let top = Sprites.headTop(img, key: key)
            head = NSPoint(x: top.x, y: top.y - 0.5)
            neck = NSPoint(x: top.x - 1, y: max(top.y - 9, h * 0.25))
        } else if pet.skin == .wolf {
            // Ears and head are on the right; ignore the tail, which can be the highest point on the left.
            let top = Sprites.headTop(img, key: key, fromX: w * 0.6)
            head = NSPoint(x: top.x, y: top.y - 1)
            neck = NSPoint(x: top.x - 4, y: top.y - 5)
        } else if pet.skin == .kirby {
            // Round body, no neck: hats ride the top of the head, the scarf sits low on the front.
            let top = Sprites.headTop(img, key: key)
            head = NSPoint(x: top.x + 1, y: top.y - 0.5)
            neck = NSPoint(x: top.x + 2, y: h * 0.27)
        }
        return (head, neck)
    }

    private func prop(_ name: String, _ index: Int = 0, centerX cx: CGFloat, bottom y: CGFloat) {
        guard let frames = Sprites.props[name], !frames.isEmpty else { return }
        let img = frames[index % frames.count]
        img.draw(in: NSRect(x: (cx - img.size.width / 2).rounded(), y: y.rounded(),
                            width: img.size.width, height: img.size.height))
    }

    /// Weather, night and Mac-state props, drawn on the pet.
    private func drawProps(head: NSPoint, neck: NSPoint) {
        if isNight {
            prop("sleepcap", centerX: head.x, bottom: head.y - 1)
        } else if weather == .rain {
            prop("umbrella", centerX: head.x, bottom: head.y - 1)
        }
        if weather == .cold { prop("scarf", centerX: neck.x, bottom: neck.y - 2) }
        if mac.cpuHot {
            for k in 0..<2 {
                let t = (frame * 2 + k * 5) % 10
                if t < 8 { prop("sweat", centerX: head.x + (k == 0 ? -4 : 4), bottom: head.y - 2 - CGFloat(t)) }
            }
            prop("fan", frame / 2, centerX: head.x + 7, bottom: head.y - 6)
        }
        if mode == .lie, mac.charging, (frame / 4) % 2 == 0 {
            prop("bolt", centerX: head.x + 2, bottom: head.y + 1)
        }
    }

    private func drawAccessories(w: CGFloat, h: CGFloat, img: NSImage, key: String) {
        let (head, neck) = anchors(w: w, h: h, img: img, key: key)
        drawProps(head: head, neck: neck)
        let headBusy = isNight || weather == .rain
        if pet.hasPartyHat, !headBusy {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: head.x - 2.5, y: head.y))
            p.line(to: NSPoint(x: head.x + 2.5, y: head.y))
            p.line(to: NSPoint(x: head.x, y: head.y + 6))
            p.close()
            NSColor.systemPink.setFill()
            p.fill()
            NSColor.systemYellow.setFill()
            NSRect(x: head.x - 0.5, y: head.y + 5.5, width: 1.5, height: 1.5).fill()
        }
        if pet.hasCrown, !headBusy {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: head.x - 3, y: head.y))
            p.line(to: NSPoint(x: head.x - 3, y: head.y + 4))
            p.line(to: NSPoint(x: head.x - 1.5, y: head.y + 2))
            p.line(to: NSPoint(x: head.x, y: head.y + 4.5))
            p.line(to: NSPoint(x: head.x + 1.5, y: head.y + 2))
            p.line(to: NSPoint(x: head.x + 3, y: head.y + 4))
            p.line(to: NSPoint(x: head.x + 3, y: head.y))
            p.close()
            NSColor.systemYellow.setFill()
            p.fill()
        }
    }

    private func drawVisitor(barHeight: CGFloat) {
        guard let v = visitor, let frames = Sprites.visitors[v.kind.name], !frames.isEmpty else { return }
        let hatched = v.fate == .collected && v.kind.catching == .hatch
        let img = hatched ? frames[frames.count - 1] : frames[(v.t / 2) % frames.count]
        let w = img.size.width, h = img.size.height
        var cx = v.x
        if v.fate == .eaten {
            // Pulled into the mouth, gone once swallowed.
            let mouth = dir > 0 ? x + spriteWidth * 0.62 : x + spriteWidth * 0.38
            let progress = CGFloat(v.fateT) / (CGFloat(Self.eatDuration) * 0.6)
            if progress >= 1 { return }
            cx = v.x + (mouth - v.x) * progress
        }
        let y = min(barHeight - h - 1, 1 + v.lift)
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: cx - w / 2, y: y)
        if v.dir < 0, !v.kind.isStationary {
            cg.translateBy(x: w, y: 0)
            cg.scaleBy(x: -1, y: 1)
        }
        img.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        cg.restoreGState()
    }

    private func drawBall(barHeight: CGFloat, y: CGFloat) {
        let font: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
        if carrying {
            let bx = dir > 0 ? x + spriteWidth - 3 : x - 6
            ("🎾" as NSString).draw(at: NSPoint(x: bx, y: y), withAttributes: font)
        } else if let b = ball {
            if b.landed {
                ("🎾" as NSString).draw(at: NSPoint(x: b.landX - 4, y: 2), withAttributes: font)
            } else {
                let f = CGFloat(b.t) / CGFloat(Ball.flightTicks)
                let bx = b.startX + (b.landX - b.startX) * f
                let by = 2 + sin(f * .pi) * 10
                ("🎾" as NSString).draw(at: NSPoint(x: bx - 4, y: by), withAttributes: font)
            }
        }
    }

    private var glyph: String? {
        if eatTicks > 0 { return eatingVisitor ? nil : "🍖" }
        if belly { return "🥰" }
        if heartTicks > 0 { return "❤️" }
        if let t = mac.pluggedInAt, Date().timeIntervalSince(t) < 5 { return "⚡️" }
        if mac.batteryLow { return "🪫" }
        if mac.musicPlaying { return "🎵" }
        if mac.typing { return "⌨️" }
        if pet.isSad { return "💧" }
        if isNight && mode == .lie { return "💤" }
        if quiet { return "🔕" }
        return weather == .hot ? weatherGlyph : nil
    }

    private func drawGlyph(y: CGFloat, h: CGFloat) {
        guard let g = glyph else { return }
        var bounce: CGFloat = 0
        if eatTicks > 0 { bounce = CGFloat(abs(sin(Double(eatTicks) * 0.7))) * 3 }
        if heartTicks > 0 { bounce = CGFloat(heartTicks % 6) * 0.6 }
        if g == "💤" { bounce = CGFloat(frame % 12) * 0.35 }
        var gx = dir > 0 ? x + spriteWidth + 1 : x - 12
        if isInhaling {
            // Sucked toward the mouth, gone once swallowed.
            if eatTicks < 8 { return }
            let slide = CGFloat(eatTicks - 8) / CGFloat(Self.eatDuration - 8) * 10
            gx = dir > 0 ? x + spriteWidth - 3 + slide : x - 7 - slide
        }
        ( g as NSString).draw(at: NSPoint(x: gx, y: y + bounce), withAttributes: [.font: NSFont.systemFont(ofSize: 10)])
    }

    private func drawBubble(barHeight: CGFloat) {
        guard isAlerting, let text = alertText else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = NSRect(x: x + spriteWidth + 14, y: (barHeight - size.height) / 2 - 1,
                          width: size.width + 12, height: size.height + 2)
        let r = (x + spriteWidth + 14 + rect.width > width)
            ? rect.offsetBy(dx: -(rect.width + spriteWidth + 28), dy: 0) : rect
        NSColor.white.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).fill()
        (text as NSString).draw(at: NSPoint(x: r.minX + 6, y: r.minY + 1), withAttributes: attrs)
    }
}
