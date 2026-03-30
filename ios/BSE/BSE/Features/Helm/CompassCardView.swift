import SwiftUI

struct CompassCardView: View {
    let snapshot: HelmSnapshot?
    let settings: AppSettings

    private var displayedValue: String {
        if let value = snapshot?.displayedValue(using: settings) {
            return String(format: "%03d", abs(value))
        }
        return "?"
    }

    private var prefix: String {
        if let value = snapshot?.displayedValue(using: settings), value < 0 {
            return "-"
        }
        return ""
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(uiColor: .systemBackground), Color.blue.opacity(0.12)],
                        center: .center,
                        startRadius: 24,
                        endRadius: 180
                    )
                )

            ForEach(0..<36, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 3) ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: index.isMultiple(of: 3) ? 3 : 1, height: index.isMultiple(of: 3) ? 24 : 12)
                    .offset(y: -150)
                    .rotationEffect(.degrees(Double(index) * 10))
                    .accessibilityHidden(true)
            }

            Image(systemName: "arrow.up")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(-(snapshot?.course ?? 0)))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("\(prefix)\(displayedValue)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let rudder = snapshot?.rudder {
                    Text("Ster \(abs(Int(rudder.rounded())))° \(rudder >= 0 ? "prawo" : "lewo")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ster nieznany")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                if let wind = snapshot?.wind {
                    Text("Wiatr \(Int(wind.rounded()))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: Circle())
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot?.accessibilitySummary(using: settings) ?? "Brak bieżących odczytów")
    }
}
