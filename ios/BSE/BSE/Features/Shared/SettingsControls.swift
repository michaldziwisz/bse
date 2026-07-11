import SwiftUI

struct NumericSettingRow: View {
    let title: String
    let valueText: String
    let decrementLabel: String
    let incrementLabel: String
    let hint: String?
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text(valueText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Button(action: onDecrement) {
                    Label(decrementLabel, systemImage: "minus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityLabel(decrementLabel)

                Button(action: onIncrement) {
                    Label(incrementLabel, systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityLabel(incrementLabel)

                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(hint ?? "")
    }
}

struct SectionHeaderText: View {
    let title: String
    let description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// „Wybieracz" wartości: pojedynczy element regulowany VoiceOver. Gest jednym
/// palcem góra/dół zmienia wartość o jeden krok (`step`) — idiomatyczny
/// odpowiednik androidowego suwaka. Widocznie prezentuje nazwę i bieżącą wartość;
/// dla VoiceOver ma rolę „adjustable" i sam ogłasza nową wartość po zmianie.
struct AdjustableSettingRow: View {
    let title: String
    let value: Double
    let minValue: Double
    let maxValue: Double
    let step: Double
    let valueLabel: (Double) -> String
    let onChange: (Double) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(valueLabel(value))
                .font(.headline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueLabel(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(min(value + step, maxValue))
            case .decrement:
                onChange(max(value - step, minValue))
            @unknown default:
                break
            }
        }
    }
}
