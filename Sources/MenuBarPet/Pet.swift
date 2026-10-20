import Foundation

enum Skin: String, CaseIterable, Codable, Identifiable {
    case blue, wolf, black, akita, kirby, yoshi
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// A saved skin that no longer exists falls back to blue instead of failing the whole saved state;
    /// the white dog became the wolf.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "white" ? .wolf : (Skin(rawValue: raw) ?? .blue)
    }
}

/// Persistent pet state. Hunger runs 0 (full) ... 100 (starving); joy 0...100.
/// The dog never dies, it just gets sad.
final class Pet: ObservableObject {
    static let hungryThreshold = 65.0
    static let sadJoy = 20.0
    private static let key = "petState.v2"
    private static let legacyKey = "petState.v1"
    private static let hungerPerHour = 6.0

    static let accessoryUnlocks: [(feedings: Int, name: String)] = [
        (50, "Party hat"), (100, "Crown"),
    ]

    @Published var name: String { didSet { save() } }
    @Published var skin: Skin { didSet { save() } }
    @Published var hunger: Double
    @Published var joy: Double
    @Published var timesFed: Int
    @Published var feedsByDay: [String: Int]
    @Published var timesPetted: Int
    @Published var bellyRubs: Int

    var isSad: Bool { hunger >= Pet.hungryThreshold || joy <= Pet.sadJoy }
    var fullness: Double { 100 - hunger }

    var mood: String {
        if isSad { return "Sad" }
        switch joy {
        case 70...: return "Happy"
        case 45...: return "Content"
        default: return "Meh"
        }
    }

    // MARK: growth
    var stageName: String { timesFed < 10 ? "Puppy" : timesFed < 30 ? "Young dog" : "Adult dog" }
    var stageScale: CGFloat { timesFed < 10 ? 0.7 : timesFed < 30 ? 0.85 : 1.0 }
    var nextStageIn: Int? {
        if timesFed < 10 { return 10 - timesFed }
        if timesFed < 30 { return 30 - timesFed }
        return nil
    }
    var hasPartyHat: Bool { timesFed >= 50 && timesFed < 100 }
    var hasCrown: Bool { timesFed >= 100 }

    // MARK: stats
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static func dayKey(_ d: Date) -> String { dayFormatter.string(from: d) }

    var streak: Int {
        let cal = Calendar.current
        var d = Date()
        if feedsByDay[Pet.dayKey(d)] == nil { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while (feedsByDay[Pet.dayKey(d)] ?? 0) > 0 {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    /// Last 7 days, oldest first.
    var lastWeek: [(label: String, count: Int)] {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let d = cal.date(byAdding: .day, value: -back, to: Date())!
            return (f.string(from: d), feedsByDay[Pet.dayKey(d)] ?? 0)
        }
    }

    private struct Saved: Codable {
        var name: String
        var hunger: Double
        var timesFed: Int
        var lastSeen: Date
        var joy: Double?
        var skin: Skin?
        var feedsByDay: [String: Int]?
        var timesPetted: Int?
        var bellyRubs: Int?
    }

    init() {
        let defaults = UserDefaults.standard
        let data = defaults.data(forKey: Pet.key) ?? defaults.data(forKey: Pet.legacyKey)
        if let data, let s = try? JSONDecoder().decode(Saved.self, from: data) {
            name = s.name
            skin = s.skin ?? .blue
            timesFed = s.timesFed
            feedsByDay = s.feedsByDay ?? [:]
            timesPetted = s.timesPetted ?? 0
            bellyRubs = s.bellyRubs ?? 0
            // Catch up on time away, capped so the dog is sad rather than ruined.
            let hours = min(max(0, Date().timeIntervalSince(s.lastSeen)) / 3600, 12)
            hunger = min(90, s.hunger + hours * Pet.hungerPerHour * 0.5)
            joy = max(25, (s.joy ?? 70) - hours * 2)
        } else {
            name = "Buddy"
            skin = .blue
            hunger = 20
            joy = 70
            timesFed = 0
            feedsByDay = [:]
            timesPetted = 0
            bellyRubs = 0
        }
    }

    func advance(seconds: Double) {
        hunger = min(100, hunger + seconds / 3600 * Pet.hungerPerHour)
        joy = max(0, joy - seconds / 3600 * (hunger >= Pet.hungryThreshold ? 8 : 4))
    }

    func feed() {
        hunger = max(0, hunger - 35)
        joy = min(100, joy + 8)
        timesFed += 1
        feedsByDay[Pet.dayKey(Date()), default: 0] += 1
        // keep only ~30 days of history
        if feedsByDay.count > 30 {
            for k in feedsByDay.keys.sorted().dropLast(30) { feedsByDay[k] = nil }
        }
        save()
    }

    func cheer(_ amount: Double) { joy = min(100, joy + amount) }

    func save() {
        let s = Saved(name: name, hunger: hunger, timesFed: timesFed, lastSeen: Date(),
                      joy: joy, skin: skin, feedsByDay: feedsByDay,
                      timesPetted: timesPetted, bellyRubs: bellyRubs)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Pet.key)
        }
    }
}
