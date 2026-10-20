import AppKit
import IOKit.ps
import EventKit

/// What the Mac is doing right now, as far as the dog is concerned.
struct MacState {
    var batteryLow = false
    var pluggedInAt: Date?
    var cpuHot = false
    var musicPlaying = false
    var typing = false
    var charging = false
    /// Name of the current Music/Spotify track; each track gets its own dance.
    var track: String?
}

/// Permission-free signals: battery, CPU load, Music/Spotify playback, typing.
final class MacReactions {
    private(set) var state = MacState()

    private var lastPower: String?
    private var lastBatteryPoll = Date.distantPast
    private var lastCPUPoll = Date.distantPast
    private var prevTicks: (busy: UInt64, total: UInt64)?
    private var cpuEMA = 0.0
    private var typingStart: Date?

    init() {
        let center = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo",
                     "com.spotify.client.PlaybackStateChanged"] {
            center.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] n in
                let s = n.userInfo?["Player State"] as? String
                self?.state.musicPlaying = (s == "Playing")
                self?.state.track = n.userInfo?["Name"] as? String
            }
        }
    }

    func reset() { state = MacState(); typingStart = nil }

    func poll(now: Date) {
        if now.timeIntervalSince(lastBatteryPoll) > 10 { lastBatteryPoll = now; pollBattery(now) }
        if now.timeIntervalSince(lastCPUPoll) > 2 { lastCPUPoll = now; pollCPU() }
        pollTyping(now)
    }

    private func pollBattery(_ now: Date) {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let capacity = d[kIOPSCurrentCapacityKey] as? Int,
                  let power = d[kIOPSPowerSourceStateKey] as? String else { continue }
            let onBattery = power == kIOPSBatteryPowerValue
            state.batteryLow = onBattery && capacity <= 20
            state.charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
            if let last = lastPower, last == kIOPSBatteryPowerValue, !onBattery { state.pluggedInAt = now }
            lastPower = power
            return
        }
    }

    private func pollCPU() {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let t = info.cpu_ticks
        let busy = UInt64(t.0) + UInt64(t.1) + UInt64(t.3)
        let total = busy + UInt64(t.2)
        defer { prevTicks = (busy, total) }
        guard let prev = prevTicks, total > prev.total else { return }
        let usage = Double(busy - prev.busy) / Double(total - prev.total)
        cpuEMA = cpuEMA * 0.7 + usage * 0.3
        if cpuEMA > 0.6 { state.cpuHot = true } else if cpuEMA < 0.4 { state.cpuHot = false }
    }

    private func pollTyping(_ now: Date) {
        let since = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        if since < 0.7 {
            if typingStart == nil { typingStart = now }
            state.typing = now.timeIntervalSince(typingStart!) >= 8
        } else {
            typingStart = nil
            state.typing = false
        }
    }
}

/// Opt-in: asks for calendar access, then reports events starting within ~3 minutes.
final class CalendarWatcher {
    private let store = EKEventStore()
    private var alerted = Set<String>()

    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Title of an upcoming timed event we haven't announced yet.
    func nextUpcoming() -> String? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(180), calendars: nil)
        for e in store.events(matching: predicate) where !e.isAllDay {
            let id = "\(e.eventIdentifier ?? e.title ?? "")-\(e.startDate.timeIntervalSince1970)"
            if alerted.insert(id).inserted { return e.title ?? "Event" }
        }
        return nil
    }
}
