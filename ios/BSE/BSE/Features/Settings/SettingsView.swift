import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

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
                    Picker("Sposób odczytu", selection: binding(\.readingOutput)) {
                        ForEach(ReadingOutputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if settingsStore.settings.readingOutput == .aria {
                        NumericSettingRow(
                            title: "Odstęp między aktualizacjami",
                            valueText: secondsText(settingsStore.settings.readingInterval),
                            decrementLabel: "Skróć odstęp między aktualizacjami",
                            incrementLabel: "Wydłuż odstęp między aktualizacjami",
                            hint: "Zakres od 1 do 45 sekund.",
                            onDecrement: { update(\.readingInterval, by: -1, range: 1...45) },
                            onIncrement: { update(\.readingInterval, by: 1, range: 1...45) }
                        )
                    } else {
                        NumericSettingRow(
                            title: "Głośność odczytu",
                            valueText: percentText(settingsStore.settings.readingVolume),
                            decrementLabel: "Zmniejsz głośność odczytu",
                            incrementLabel: "Zwiększ głośność odczytu",
                            hint: "Zakres od 0 do 100 procent.",
                            onDecrement: { update(\.readingVolume, by: -5, range: 0...100) },
                            onIncrement: { update(\.readingVolume, by: 5, range: 0...100) }
                        )

                        NumericSettingRow(
                            title: "Odstęp między odczytami",
                            valueText: secondsText(settingsStore.settings.readingDelay),
                            decrementLabel: "Skróć odstęp między odczytami",
                            incrementLabel: "Wydłuż odstęp między odczytami",
                            hint: "Zakres od 0 do 30 sekund.",
                            onDecrement: { update(\.readingDelay, by: -0.5, range: 0...30) },
                            onIncrement: { update(\.readingDelay, by: 0.5, range: 0...30) }
                        )

                        NumericSettingRow(
                            title: "Prędkość odczytu",
                            valueText: percentText(settingsStore.settings.readingRate),
                            decrementLabel: "Zmniejsz prędkość odczytu",
                            incrementLabel: "Zwiększ prędkość odczytu",
                            hint: "Zakres od 50 do 400 procent.",
                            onDecrement: { update(\.readingRate, by: -10, range: 50...400) },
                            onIncrement: { update(\.readingRate, by: 10, range: 50...400) }
                        )

                        Picker("Głos", selection: voiceBinding) {
                            Text("Domyślny").tag("")
                            ForEach(settingsStore.availableVoices()) { voice in
                                Text(voice.title).tag(voice.id)
                            }
                        }
                    }
                } header: {
                    Text("Odczyt")
                } footer: {
                    Text("Tryb czytnika ekranu najlepiej działa z aktywnym VoiceOver.")
                }

                Section("Sygnały dźwiękowe") {
                    Toggle("Odtwarzaj sygnały dźwiękowe", isOn: binding(\.soundSignalsEnabled))
                    Toggle("Odtwarzaj ton referencyjny", isOn: binding(\.referenceTone))
                    Toggle("Odtwarzaj ton na zadanym kursie", isOn: binding(\.toneOnCourse))
                    Toggle("Szeroka rozpiętość tonów", isOn: binding(\.broadTonalSpread))

                    Picker("Typ dźwięku", selection: binding(\.toneType)) {
                        ForEach(ToneWaveform.allCases) { waveform in
                            Text(waveform.title).tag(waveform)
                        }
                    }

                    NumericSettingRow(
                        title: "Głośność sygnałów",
                        valueText: percentText(settingsStore.settings.toneVolume),
                        decrementLabel: "Zmniejsz głośność sygnałów",
                        incrementLabel: "Zwiększ głośność sygnałów",
                        hint: "Zakres od 0 do 100 procent.",
                        onDecrement: { update(\.toneVolume, by: -5, range: 0...100) },
                        onIncrement: { update(\.toneVolume, by: 5, range: 0...100) }
                    )

                    NumericSettingRow(
                        title: "Odstęp między sygnałami",
                        valueText: secondsText(settingsStore.settings.toneDelay),
                        decrementLabel: "Skróć odstęp między sygnałami",
                        incrementLabel: "Wydłuż odstęp między sygnałami",
                        hint: "Zakres od 0,5 do 5 sekund.",
                        onDecrement: { update(\.toneDelay, by: -0.1, range: 0.5...5) },
                        onIncrement: { update(\.toneDelay, by: 0.1, range: 0.5...5) }
                    )

                    NumericSettingRow(
                        title: "Bazowy odstęp od tonu na kursie",
                        valueText: decimalText(settingsStore.settings.toneBaseOffset),
                        decrementLabel: "Zmniejsz bazowy odstęp",
                        incrementLabel: "Zwiększ bazowy odstęp",
                        hint: "Zakres od 0 do 6 półtonów.",
                        onDecrement: { update(\.toneBaseOffset, by: -1, range: 0...6) },
                        onIncrement: { update(\.toneBaseOffset, by: 1, range: 0...6) }
                    )

                    NumericSettingRow(
                        title: "Dozwolona odchyłka",
                        valueText: degreesText(settingsStore.settings.errorThreshold),
                        decrementLabel: "Zmniejsz dozwoloną odchyłkę",
                        incrementLabel: "Zwiększ dozwoloną odchyłkę",
                        hint: "Zakres od 1 do 15 stopni.",
                        onDecrement: { update(\.errorThreshold, by: -0.5, range: 1...15) },
                        onIncrement: { update(\.errorThreshold, by: 0.5, range: 1...15) }
                    )

                    NumericSettingRow(
                        title: "Zakres sygnalizowanej odchyłki",
                        valueText: degreesText(settingsStore.settings.errorRange),
                        decrementLabel: "Zmniejsz zakres sygnalizacji",
                        incrementLabel: "Zwiększ zakres sygnalizacji",
                        hint: "Zakres od 15 do 60 stopni.",
                        onDecrement: { update(\.errorRange, by: -1, range: 15...60) },
                        onIncrement: { update(\.errorRange, by: 1, range: 15...60) }
                    )

                    if settingsStore.settings.readingOutput != .aria {
                        Toggle("Unikaj sygnalizowania w trakcie odczytu", isOn: binding(\.avoidSignalsOverlap))
                    }
                }

                Section("Źródło danych") {
                    Picker("Źródło kursu", selection: binding(\.courseSource)) {
                        ForEach(CourseSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }

                    NumericSettingRow(
                        title: "Okno uśredniania",
                        valueText: "\(settingsStore.settings.averageWindow) s",
                        decrementLabel: "Zmniejsz okno uśredniania",
                        incrementLabel: "Zwiększ okno uśredniania",
                        hint: "Zakres od 1 do 5 sekund.",
                        onDecrement: { updateInt(\.averageWindow, by: -1, range: 1...5) },
                        onIncrement: { updateInt(\.averageWindow, by: 1, range: 1...5) }
                    )
                }

                Section("Ustawienia pomocnicze") {
                    Toggle("Odwróć wychylenie steru", isOn: binding(\.invertRudderAngle))

                    NumericSettingRow(
                        title: "Poprawka wychylenia steru",
                        valueText: degreesText(settingsStore.settings.rudderAngleCorrection),
                        decrementLabel: "Zmniejsz poprawkę wychylenia steru",
                        incrementLabel: "Zwiększ poprawkę wychylenia steru",
                        hint: "Zakres od minus 90 do 90 stopni.",
                        onDecrement: { update(\.rudderAngleCorrection, by: -1, range: -90...90) },
                        onIncrement: { update(\.rudderAngleCorrection, by: 1, range: -90...90) }
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

    private var voiceBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.readingVoiceIdentifier ?? "" },
            set: { newValue in
                settingsStore.update { settings in
                    settings.readingVoiceIdentifier = newValue.isEmpty ? nil : newValue
                }
            }
        )
    }

    private func update(
        _ keyPath: WritableKeyPath<AppSettings, Double>,
        by step: Double,
        range: ClosedRange<Double>
    ) {
        settingsStore.update { settings in
            settings[keyPath: keyPath] = min(max(settings[keyPath: keyPath] + step, range.lowerBound), range.upperBound)
        }
    }

    private func updateInt(
        _ keyPath: WritableKeyPath<AppSettings, Int>,
        by step: Int,
        range: ClosedRange<Int>
    ) {
        settingsStore.update { settings in
            settings[keyPath: keyPath] = min(max(settings[keyPath: keyPath] + step, range.lowerBound), range.upperBound)
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
