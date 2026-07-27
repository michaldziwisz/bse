import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var monitor: HelmMonitor

    /// Rozwijana sekcja „Zaawansowane” — domyślnie zwinięta, bo to rzadko
    /// używane opcje techniczne (odwrócenie i poprawka wychylenia steru).
    @State private var advancedExpanded = false

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Tryb demonstracyjny", isOn: binding(\.demoMode))
                        .accessibilityHint("Gdy włączony, aplikacja łączy się z serwerem demonstracyjnym w internecie zamiast z urządzeniem w sieci Wi-Fi. Pozwala testować bez łodzi i bez sprzętu.")

                    if !settingsStore.settings.demoMode {
                        HStack {
                            Text("Adres urządzenia")
                            Spacer()
                            TextField(
                                AppSettings.defaultDeviceHost,
                                text: deviceHostBinding
                            )
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .submitLabel(.done)
                            .accessibilityLabel("Adres urządzenia BlueSeaEye")
                            .accessibilityHint("Adres IP lub nazwa hosta urządzenia w sieci Wi-Fi. Domyślnie \(AppSettings.defaultDeviceHost).")
                        }

                        Button("Przywróć domyślny adres") {
                            settingsStore.update { $0.deviceHost = AppSettings.defaultDeviceHost }
                        }
                        .disabled(settingsStore.settings.deviceHost == AppSettings.defaultDeviceHost)

                        Toggle("Trzymaj się sieci urządzenia", isOn: binding(\.keepDeviceWifi))
                            .accessibilityHint("Gdy włączone, w trakcie odczytu telefon trzyma się sieci Wi-Fi BlueSeaEye i nie przełącza się na inną sieć, na przykład statkowy internet, gdy ta chwilowo złapie lepszy zasięg. Przy pierwszym użyciu system poprosi o zgodę.")
                    }
                } header: {
                    Text("Urządzenie")
                } footer: {
                    Text(settingsStore.settings.demoMode
                        ? "Tryb demonstracyjny jest włączony. Aplikacja pobiera dane z serwera \(AppSettings.demoBaseURL.absoluteString) przez internet. Wyłącz go, aby łączyć się ze sprzętem w sieci Wi-Fi „BlueSeaEye”."
                        : "Połącz telefon z siecią Wi-Fi „BlueSeaEye” (hasło blueseaeye). Domyślny adres \(AppSettings.defaultDeviceHost) odpowiada urządzeniu w trybie access pointa. Zmień go tylko, jeśli urządzenie pracuje pod innym adresem.")
                }

                Section("Odczyt") {
                    AdjustableSettingRow(
                        title: "Mów co",
                        value: settingsStore.settings.readingInterval,
                        minValue: 1,
                        maxValue: 45,
                        step: 1,
                        valueLabel: { secondsText($0) },
                        onChange: { set(\.readingInterval, to: $0) }
                    )
                }

                Section("Sygnały dźwiękowe") {
                    Toggle("Odtwarzaj sygnały dźwiękowe", isOn: binding(\.soundSignalsEnabled))
                    Toggle("Dźwięki w panoramie", isOn: binding(\.stereoPanning))
                        .accessibilityHint("Gdy włączone i masz podłączone obie słuchawki, sygnał odchyłki w lewo słychać bardziej z lewej strony, a w prawo z prawej (po 50% w bok). Sygnał na kursie pozostaje na środku. Dotyczy tylko dźwięków sygnału, nie mowy.")
                    Toggle("Odtwarzaj ton na zadanym kursie", isOn: binding(\.toneOnCourse))

                    AdjustableSettingRow(
                        title: "Głośność sygnałów",
                        value: settingsStore.settings.toneVolume,
                        minValue: 0,
                        maxValue: 100,
                        step: 5,
                        valueLabel: { percentText($0) },
                        onChange: { set(\.toneVolume, to: $0) }
                    )

                    AdjustableSettingRow(
                        title: "Odstęp między sygnałami",
                        value: settingsStore.settings.toneDelay,
                        minValue: 0.5,
                        maxValue: 5,
                        step: 0.5,
                        valueLabel: { secondsText($0) },
                        onChange: { set(\.toneDelay, to: $0) }
                    )

                    AdjustableSettingRow(
                        title: "Tolerancja zadanego kursu",
                        value: settingsStore.settings.errorThreshold,
                        minValue: 1,
                        maxValue: 5,
                        step: 1,
                        valueLabel: { degreesPolish(Int($0.rounded())) },
                        onChange: { set(\.errorThreshold, to: $0) }
                    )
                }

                // Ustawienia dotyczące wychylenia steru pokazujemy tylko wtedy, gdy
                // urządzenie faktycznie dostarcza dane o wychyleniu płetwy steru
                // (pole rsa) — analogicznie jak przy wietrze. Dodatkowo są schowane
                // pod rozwijaną sekcją „Zaawansowane”, bo to opcje techniczne.
                if monitor.snapshot?.rudder != nil {
                    Section {
                        DisclosureGroup("Zaawansowane", isExpanded: $advancedExpanded) {
                            Toggle("Odczytuj wychylenie steru", isOn: binding(\.announceRudderAngle))
                            Toggle("Odwróć wychylenie steru", isOn: binding(\.invertRudderAngle))

                            AdjustableSettingRow(
                                title: "Poprawka wychylenia steru",
                                value: settingsStore.settings.rudderAngleCorrection,
                                minValue: -90,
                                maxValue: 90,
                                step: 1,
                                valueLabel: { degreesText($0) },
                                onChange: { set(\.rudderAngleCorrection, to: $0) }
                            )
                        }
                    }
                }

                Section("Czynności urządzenia") {
                    ConfirmableActionRow(
                        title: "Kalibracja żyroskopu",
                        warning: "Kalibrację żyroskopu należy przeprowadzić po ostatecznym zamocowaniu urządzenia do stałej części statku i gdy statek jest stabilny. Najlepiej w porcie na cumach.",
                        confirmLabel: "Kalibruj",
                        onConfirm: { Task { await monitor.runAdministrationAction(.calibrate) } }
                    )
                    ConfirmableActionRow(
                        title: "Restart urządzenia",
                        warning: "Urządzenie uruchomi się ponownie. Po restarcie zwykle łączy się z powrotem samo. Jeśli w pobliżu jest inna zapamiętana sieć Wi-Fi, ponownie włącz odczyt na ekranie Ster, aby aplikacja wróciła do sieci „BlueSeaEye”.",
                        confirmLabel: "Restart",
                        onConfirm: { Task { await monitor.runAdministrationAction(.reboot) } }
                    )
                }
            }
            .navigationTitle("Ustawienia")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { newValue in
                settingsStore.update { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var deviceHostBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.deviceHost },
            set: { newValue in
                settingsStore.update { settings in
                    settings.deviceHost = newValue
                }
            }
        )
    }

    private func set(_ keyPath: WritableKeyPath<AppSettings, Double>, to value: Double) {
        settingsStore.update { settings in
            settings[keyPath: keyPath] = value
        }
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func secondsText(_ value: Double) -> String {
        "\(decimalText(value)) s"
    }

    private func degreesText(_ value: Double) -> String {
        "\(decimalText(value))°"
    }

    private func decimalText(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// Wiersz czynności urządzenia: po stuknięciu rozwija ostrzeżenie i przycisk
/// potwierdzenia (kalibracja / restart).
private struct ConfirmableActionRow: View {
    let title: String
    let warning: String
    let confirmLabel: String
    let onConfirm: () -> Void

    @State private var expanded = false

    var body: some View {
        Button(title) {
            withAnimation { expanded.toggle() }
        }
        .accessibilityHint("Pokazuje ostrzeżenie i przycisk potwierdzenia.")

        if expanded {
            Text(warning)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(confirmLabel, role: .destructive) {
                onConfirm()
                expanded = false
            }
            .accessibilityHint(warning)
        }
    }
}
