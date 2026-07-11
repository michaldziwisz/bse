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
///
/// `wrap` = zawijanie przez granicę zakresu (359 + 1 → 0, 0 − 1 → 359).
/// `allowKeyboardInput` = dwukrotne stuknięcie otwiera pole do wpisania wartości.
struct AdjustableSettingRow: View {
    let title: String
    let value: Double
    let minValue: Double
    let maxValue: Double
    let step: Double
    let valueLabel: (Double) -> String
    let onChange: (Double) -> Void
    var wrap: Bool = false
    var allowKeyboardInput: Bool = false

    @State private var showKeyboardEntry = false
    @State private var entryText = ""

    private func stepped(_ forward: Bool) -> Double {
        let delta = forward ? step : -step
        var next = value + delta
        if wrap {
            if next > maxValue { next = minValue }
            else if next < minValue { next = maxValue }
        } else {
            next = Swift.min(Swift.max(next, minValue), maxValue)
        }
        return next
    }

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
                onChange(stepped(true))
            case .decrement:
                onChange(stepped(false))
            @unknown default:
                break
            }
        }
        .modifier(KeyboardEntryModifier(
            enabled: allowKeyboardInput,
            onActivate: {
                entryText = String(Int(value.rounded()))
                showKeyboardEntry = true
            }
        ))
        .alert(title, isPresented: $showKeyboardEntry) {
            TextField("Wartość", text: $entryText)
                .keyboardType(.numberPad)
            Button("Ustaw") {
                if let entered = Int(entryText.trimmingCharacters(in: .whitespaces)) {
                    let clamped = Swift.min(Swift.max(Double(entered), minValue), maxValue)
                    onChange(clamped)
                }
            }
            Button("Anuluj", role: .cancel) { }
        } message: {
            Text("Wpisz wartość z zakresu \(Int(minValue))–\(Int(maxValue)).")
        }
    }
}

/// Dodaje akcję aktywacji (dwukrotne stuknięcie VoiceOver / tap) tylko gdy
/// `enabled`; inaczej element pozostaje bez zmian.
private struct KeyboardEntryModifier: ViewModifier {
    let enabled: Bool
    let onActivate: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .accessibilityAction(.default, onActivate)
                .onTapGesture(count: 2, perform: onActivate)
        } else {
            content
        }
    }
}
