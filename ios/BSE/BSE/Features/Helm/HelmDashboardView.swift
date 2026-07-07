import SwiftUI
import UIKit

struct HelmDashboardView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var monitor: HelmMonitor
    @Environment(\.openURL) private var openURL

    private var settings: AppSettings { settingsStore.settings }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if monitor.isConnectionLost {
                        connectionWarningSection
                    }
                    statusSection
                    controlsSection
                    latestAnnouncementSection
                    deviceSection
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
                description: "Widok stale odświeża dane z urządzenia BlueSeaEye."
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
                    description: Text("Połącz telefon z siecią Wi-Fi „BlueSeaEye” i sprawdź adres urządzenia w Ustawieniach.")
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionWarningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Połączenie utracone")
                        .font(.headline)
                    Text("Aplikacja nadal pracuje w tle, ponawia odczyt i alarmuje użytkownika.")
                        .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Połączenie utracone. Aplikacja ponawia odczyt i alarmuje użytkownika.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Jeśli połączenie nie wraca, sprawdź kolejno:")
                    .font(.subheadline.weight(.semibold))
                Text("1. Telefon jest połączony z siecią Wi-Fi „BlueSeaEye”.")
                    .font(.subheadline)
                Text("2. Aplikacja ma włączony dostęp do sieci lokalnej. Przy pierwszym uruchomieniu system pyta o zgodę – bez niej aplikacja nie odbierze danych z urządzenia.")
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Jeśli połączenie nie wraca, sprawdź: po pierwsze, czy telefon jest połączony z siecią Wi-Fi BlueSeaEye. Po drugie, czy aplikacja ma włączony dostęp do sieci lokalnej. Przy pierwszym uruchomieniu system pyta o zgodę. Bez niej aplikacja nie odbierze danych z urządzenia.")

            Button("Otwórz ustawienia aplikacji") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Otwiera ustawienia systemowe aplikacji, gdzie można włączyć dostęp do sieci lokalnej.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
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

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderText(
                title: "Urządzenie",
                description: "Połącz telefon z siecią Wi-Fi „BlueSeaEye”. Adres urządzenia zmienisz w Ustawieniach."
            )
            Text(settings.deviceBaseURL().absoluteString)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel("Adres urządzenia \(settings.deviceBaseURL().absoluteString)")
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
