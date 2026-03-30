import SwiftUI

struct HelmDashboardView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var monitor: HelmMonitor

    private var settings: AppSettings { settingsStore.settings }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    controlsSection
                    latestAnnouncementSection
                    endpointSection
                }
                .padding()
            }
            .navigationTitle("Ster")
            .toolbarTitleDisplayMode(.large)
            .alert("Błąd połączenia", isPresented: errorIsPresented) {
                Button("OK") {
                    monitor.clearError()
                }
            } message: {
                Text(monitor.errorMessage ?? "")
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderText(
                title: "Bieżący status",
                description: "Widok stale odświeża dane z testowego endpointu."
            )
            CompassCardView(snapshot: monitor.snapshot, settings: settings)

            if let snapshot = monitor.snapshot {
                Text("Ostatnia aktualizacja: \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "Ostatnia aktualizacja \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))"
                    )
            } else {
                ContentUnavailableView(
                    "Brak odczytów",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Sprawdź dostępność `https://blueseaeye.eu/api/helm`.")
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderText(
                title: "Sterowanie odczytem",
                description: "Możesz czytać pełny kurs albo odchyłkę od zapamiętanego kursu."
            )

            Button(action: monitor.toggleReading) {
                Label(
                    monitor.isReadingEnabled ? "Zatrzymaj odczyt" : "Uruchom odczyt",
                    systemImage: monitor.isReadingEnabled ? "pause.circle.fill" : "play.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Włącza lub wyłącza komunikaty głosowe oraz sygnały.")

            Picker("Tryb odczytu", selection: targetBinding) {
                ForEach(TargetMode.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Wybiera, czy aplikacja ma czytać kurs czy odchyłkę.")

            if settings.target == .course {
                VStack(alignment: .leading, spacing: 12) {
                    NumericSettingRow(
                        title: "Zadany kurs",
                        valueText: targetCourseText,
                        decrementLabel: "Zmniejsz zadany kurs",
                        incrementLabel: "Zwiększ zadany kurs",
                        hint: "Zmiana co 1 stopień.",
                        onDecrement: { updateTargetCourse(by: -1) },
                        onIncrement: { updateTargetCourse(by: 1) }
                    )

                    Button("Ustaw aktualny kurs") {
                        monitor.holdCurrentCourse()
                    }
                    .buttonStyle(.bordered)
                    .disabled(monitor.snapshot?.course == nil)
                    .accessibilityHint("Zapisuje aktualny kurs jako docelowy.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var latestAnnouncementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderText(
                title: "Ostatni komunikat",
                description: settings.readingOutput == .aria
                    ? "Treść komunikatu jest wysyłana jako ogłoszenie dla VoiceOver."
                    : "Treść odpowiada ostatniemu odczytowi wypowiedzianemu przez syntezator."
            )
            Text(monitor.lastAnnouncement.isEmpty ? "Brak komunikatu." : monitor.lastAnnouncement)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(
                    monitor.lastAnnouncement.isEmpty
                        ? "Brak ostatniego komunikatu"
                        : "Ostatni komunikat: \(monitor.lastAnnouncement)"
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderText(
                title: "Endpoint testowy",
                description: "Mock zwraca dane kursu i wychylenia steru, ale nie odwzorowuje wszystkich zachowań urządzenia."
            )
            Text("https://blueseaeye.eu/api/helm")
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var targetCourseText: String {
        String(format: "%03.0f°", settings.targetCourse ?? 0)
    }

    private var targetBinding: Binding<TargetMode> {
        Binding(
            get: { settingsStore.settings.target },
            set: { newValue in
                settingsStore.update { settings in
                    settings.target = newValue
                    if newValue == .none {
                        settings.targetCourse = nil
                    } else if settings.targetCourse == nil {
                        settings.targetCourse = HelmMath.normalizedCourse(monitor.snapshot?.course ?? 0)
                    }
                }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { monitor.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    monitor.clearError()
                }
            }
        )
    }

    private func updateTargetCourse(by delta: Double) {
        settingsStore.update { settings in
            let current = settings.targetCourse ?? HelmMath.normalizedCourse(monitor.snapshot?.course ?? 0)
            settings.targetCourse = HelmMath.normalizedCourse(current + delta)
        }
    }
}
