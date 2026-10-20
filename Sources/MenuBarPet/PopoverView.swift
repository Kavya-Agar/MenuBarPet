import SwiftUI

/// Switches shown in both the popover and the right-click menu. Changes are forwarded to the app.
final class Controls: ObservableObject {
    enum Key { case quiet, follow, reactions }
    var onChange: ((Key, Bool) -> Void)?
    @Published var quiet = false { didSet { if quiet != oldValue { onChange?(.quiet, quiet) } } }
    @Published var follow = true { didSet { if follow != oldValue { onChange?(.follow, follow) } } }
    @Published var reactions = true { didSet { if reactions != oldValue { onChange?(.reactions, reactions) } } }
}

struct PopoverView: View {
    @ObservedObject var pet: Pet
    @ObservedObject var controls: Controls
    var onFeed: () -> Void
    var onThrowBall: () -> Void
    var onPet: () -> Void

    private let pink = Color(red: 1, green: 0.22, blue: 0.37)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusLine
            meter("Fullness", "🍖", pet.fullness, .blue)
            meter("Happiness", "💗", pet.joy, pink)
            actions
            toggles
            coat
            statsCard
            unlocks
        }
        .padding(16)
        .frame(width: 284)
    }

    // MARK: sections

    private var header: some View {
        HStack(spacing: 10) {
            Text("🐶").font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name).font(.system(size: 17, weight: .bold))
                Text("\(pet.stageName) · \(pet.timesFed) feedings")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            let tint: Color = pet.isSad ? .red : pink
            Text("\(pet.isSad ? "😢" : "🥰") \(pet.mood)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(tint.opacity(0.14), in: Capsule())
        }
    }

    private var statusLine: some View {
        let phase = DayPhase(hour: Calendar.current.component(.hour, from: Date()))
        let text = controls.quiet ? "Quiet mode · resting" : phase.statusText
        let emoji = controls.quiet ? "🔕" : phase.statusEmoji
        return HStack(spacing: 6) {
            Text(emoji).font(.system(size: 12))
            Text(text).font(.system(size: 12, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(chipFill, in: RoundedRectangle(cornerRadius: 10))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onFeed) {
                Label("Feed", systemImage: "fork.knife").frame(maxWidth: .infinity)
            }
            .glassProminentButton()
            Button(action: onThrowBall) {
                Label("Fetch", systemImage: "tennisball.fill").frame(maxWidth: .infinity)
            }
            .glassButton()
            Button(action: onPet) {
                Label("Pet", systemImage: "hand.raised.fill").frame(maxWidth: .infinity)
            }
            .glassButton()
        }
        .controlSize(.large)
    }

    private var toggles: some View {
        VStack(spacing: 0) {
            toggleRow("Quiet mode", "🔕", $controls.quiet)
            Divider().opacity(0.5)
            toggleRow("Follow cursor", "👆", $controls.follow)
            Divider().opacity(0.5)
            toggleRow("React to my Mac", "💻", $controls.reactions)
        }
        .background(chipFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private var coat: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COAT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Skin.allCases) { skin in
                    Button { pet.skin = skin } label: {
                        Circle().fill(skin.swatch)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(
                                pet.skin == skin ? Color.accentColor : Color.primary.opacity(0.18),
                                lineWidth: pet.skin == skin ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(skin.label)
                }
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🔥 \(pet.streak)-day streak").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Fed \(pet.timesFed)×").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom) {
                let week = pet.lastWeek
                let peak = max(1, week.map(\.count).max() ?? 1)
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(d.count > 0 ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 22, height: max(3, 28 * CGFloat(d.count) / CGFloat(peak)))
                        Text(d.label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    }
                    if i < week.count - 1 { Spacer(minLength: 0) }
                }
            }
            .frame(height: 44, alignment: .bottom)
            HStack(spacing: 6) {
                chip("🤚 \(pet.timesPetted) pets")
                chip("🥰 \(pet.bellyRubs) belly rubs")
            }
            if let n = pet.nextStageIn {
                Text("Grows up after \(n) more feeding\(n == 1 ? "" : "s")")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(chipFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private var unlocks: some View {
        HStack(spacing: 6) {
            ForEach(Pet.accessoryUnlocks, id: \.name) { a in
                let on = pet.timesFed >= a.feedings
                Text("\(on ? "✅" : "🔒") \(a.name.replacingOccurrences(of: "Red ", with: "").capitalized)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(on ? Color.accentColor : .secondary)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(on ? Color.accentColor.opacity(0.14) : chipFill, in: Capsule())
            }
        }
    }

    // MARK: pieces

    private var chipFill: Color { Color.primary.opacity(0.06) }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(chipFill, in: Capsule())
    }

    private func toggleRow(_ title: String, _ emoji: String, _ on: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 13))
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            Toggle("", isOn: on).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func meter(_ label: String, _ emoji: String, _ value: Double, _ tint: Color) -> some View {
        let v = max(0, min(100, value))
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(v.rounded()))%").font(.system(size: 11, weight: .semibold))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.25))
                    Capsule().fill(tint).frame(width: max(8, g.size.width * v / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

extension Skin {
    var swatch: Color {
        switch self {
        case .blue: return Color(red: 0.29, green: 0.56, blue: 0.89)
        case .wolf: return Color(red: 0.74, green: 0.72, blue: 0.70)
        case .black: return Color(white: 0.17)
        case .akita: return Color(red: 0.85, green: 0.65, blue: 0.42)
        case .kirby: return Color(red: 1, green: 0.69, blue: 0.81)
        case .yoshi: return Color(red: 0.49, green: 0.82, blue: 0.31)
        }
    }
}

// MARK: Liquid Glass (macOS 26+), with plain fallbacks for older systems

private extension View {
    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26, *) { self.buttonStyle(.glass) } else { self.buttonStyle(.bordered) }
    }

    @ViewBuilder func glassProminentButton() -> some View {
        if #available(macOS 26, *) { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.borderedProminent) }
    }
}
