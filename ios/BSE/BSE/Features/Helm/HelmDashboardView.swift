import SwiftUI
import UIKit

struct HelmDashboardView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var monitor: HelmMonitor
    @Environment(\.openURL) private var openURL
    @State private var crashReasonCopied = false

    private var settings: AppSettings { settingsStore.settings }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let crashReason = monitor.lastCrashReason {
                        crashReportSection(crashReason)
                    }
                    if monitor.isConnectionLost {
                        connectionWarningSection
                    }
                    connectionStatusLine
                    statusSection
                    controlsSection
                }
                .padding()
            }
            .navigationTitle("Ster")
            .toolbar(.hidden, for: .navigationBar)
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
        // Bieżący stan — sam kafelek z odczytem (bez nagłówka, opisu i czasu).
        CompassCardView(snapshot: monitor.snapshot, settings: settings)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionStatusLine: some View {
        let connected = monitor.snapshot != nil && !monitor.isConnectionLost
        let text: String
        switch (settings.demoMode, connected) {
        case (true, true): text = "Połączony z serwerem demo"
        case (true, false): text = "Brak połączenia z serwerem demo"
        case (false, true): text = "Połączony z siecią BlueSeaEye"
        case (false, false): text = "Brak połączenia z siecią BlueSeaEye"
        }
        return Text(text)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                (connected ? Color.green.opacity(0.15) : Color.red.opacity(0.15)),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(connected ? Color.green : Color.red)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func crashReportSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aplikacja zakończyła się niespodziewanie")
                .font(.headline)
            Text("Powód (do diagnozy): \(reason)")
                .font(.footnote)
                .textSelection(.enabled)
            HStack(spacing: 12) {
                Button("Kopiuj do schowka") {
                    UIPasteboard.general.string = reason
                    crashReasonCopied = true
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Skopiowano opis błędu do schowka."
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Kopiuje pełny opis błędu, aby wkleić go w wiadomości.")

                Button("OK, ukryj") {
                    monitor.lastCrashReason = nil
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Ukrywa informację o poprzednim zamknięciu aplikacji.")
            }
            if crashReasonCopied {
                Text("Skopiowano do schowka.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aplikacja zakończyła się niespodziewanie. Powód: \(reason)")
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
            Button(action: monitor.toggleReading) {
                Label(
                    monitor.isReadingEnabled ? "Stop" : "Czytaj",
                    systemImage: monitor.isReadingEnabled ? "pause.circle.fill" : "play.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Włącza lub wyłącza komunikaty głosowe oraz sygnały.")

            Picker("Tryb odczytu", selection: targetBinding) {
                ForEach([TargetMode.none, TargetMode.course]) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Wybiera, czy aplikacja ma czytać aktualny czy zadany kurs.")

            if settings.target == .course {
                VStack(alignment: .leading, spacing: 12) {
                    // Kurs prezentujemy jako 1–360 (360 = północ); wewnętrznie
                    // trzymamy 0–359 (0 = północ), więc 360 zapisujemy jako 0,
                    // a zapisane 0 pokazujemy jako 360.
                    AdjustableSettingRow(
                        title: "Zadany kurs",
                        value: (settings.targetCourse ?? 0) == 0 ? 360 : (settings.targetCourse ?? 0),
                        minValue: 1,
                        maxValue: 360,
                        step: 1,
                        valueLabel: { degreesPolish(Int($0)) },
                        onChange: { setTargetCourse($0 >= 360 ? 0 : $0) },
                        wrap: true,
                        allowKeyboardInput: true
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

    private var targetBinding: Binding<TargetMode> {
        Binding(
            get: { settingsStore.settings.target },
            set: { newValue in
                settingsStore.update { settings in
                    settings.target = newValue
                    switch newValue {
                    case .none:
                        settings.targetCourse = nil
                        settings.targetWind = nil
                    case .course:
                        if settings.targetCourse == nil {
                            settings.targetCourse = HelmMath.normalizedCourse(monitor.snapshot?.course ?? 0)
                        }
                    case .wind:
                        if settings.targetWind == nil {
                            settings.targetWind = HelmMath.normalizedCourse(monitor.snapshot?.wind ?? 0)
                        }
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

    private func setTargetCourse(_ value: Double) {
        settingsStore.update { settings in
            settings.targetCourse = HelmMath.normalizedCourse(value)
        }
    }
}

/// Liczba stopni z polską odmianą rzeczownika: 1 stopień, 2 stopnie, 20 stopni.
func degreesPolish(_ n: Int) -> String {
    let a = abs(n)
    let mod100 = a % 100
    let mod10 = a % 10
    let word: String
    if a == 1 {
        word = "stopień"
    } else if (12...14).contains(mod100) {
        word = "stopni"
    } else if (2...4).contains(mod10) {
        word = "stopnie"
    } else {
        word = "stopni"
    }
    return "\(n) \(word)"
}
