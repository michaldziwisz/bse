import Foundation
import UIKit

@MainActor
final class HelmMonitor: ObservableObject {
    @Published private(set) var snapshot: HelmSnapshot?
    @Published private(set) var isReadingEnabled = false
    @Published private(set) var isPolling = false
    @Published private(set) var isConnectionLost = false
    @Published private(set) var lastAnnouncement = ""
    @Published var errorMessage: String?
    @Published var adminMessage: String?
    @Published var isBusy = false
    @Published var lastCrashReason: String?

    private let settingsStore: SettingsStore
    private let apiClient: HelmAPIClient
    private let speechService: SpeechService
    private let tonePlayer: TonePlayer
    private let audioSessionController: AudioSessionController
    private let notificationController: SafetyNotificationController
    private let nowPlayingController: NowPlayingController
    private let deviceWifiController: DeviceWifiController

    private let statusInterval: TimeInterval = 0.5
    private let loopDelayNanoseconds: UInt64 = 100_000_000
    private let frequencyMid = 440.0
    private let connectionAlertRepeatInterval: TimeInterval = 20
    private let keepAliveWatchdogInterval: TimeInterval = 3

    private var loopTask: Task<Void, Never>?
    private var lastKeepAliveCheckAt = Date.distantPast
    private var isReadingInProgress = false
    private var isSignalInProgress = false
    private var lastReadAt = Date.distantPast
    private var lastSignalAt = Date.distantPast
    private var lastFetchAt = Date.distantPast
    private var lastSignaledSnapshot: HelmSnapshot?
    private var lastConnectionAlertAt = Date.distantPast
    private var speechGeneration: UInt64 = 0
    private var isSpeechActive = false

    /// Trwały ślad tego, czy odczyt był włączony. Pozwala wznowić pracę po tym,
    /// jak iOS ubił proces w tle (presja pamięci) i wskrzesił go później —
    /// wtedy świeża instancja startuje z isReadingEnabled=false i bez tego
    /// aplikacja milczałaby mimo że użytkownik wcześniej włączył odczyt.
    private let readingWasEnabledKey = "bse.readingWasEnabled"
    private let defaults = UserDefaults.standard

    init(
        settingsStore: SettingsStore,
        apiClient: HelmAPIClient = HelmAPIClient(),
        audioSessionController: AudioSessionController,
        notificationController: SafetyNotificationController,
        nowPlayingController: NowPlayingController
    ) {
        self.settingsStore = settingsStore
        self.apiClient = apiClient
        self.audioSessionController = audioSessionController
        self.notificationController = notificationController
        self.nowPlayingController = nowPlayingController
        self.speechService = SpeechService(audioSessionController: audioSessionController)
        self.tonePlayer = TonePlayer(audioSessionController: audioSessionController)
        self.deviceWifiController = DeviceWifiController(
            ssid: AppSettings.deviceWifiSSID,
            passphrase: AppSettings.deviceWifiPassphrase
        )

        nowPlayingController.onPlay = { [weak self] in
            guard let self, !self.isReadingEnabled else { return }
            self.toggleReading()
        }
        nowPlayingController.onPause = { [weak self] in
            guard let self, self.isReadingEnabled else { return }
            self.toggleReading()
        }
        nowPlayingController.onToggle = { [weak self] in
            self?.toggleReading()
        }
    }

    func start() {
        guard loopTask == nil else { return }
        isPolling = true
        // Połączenie z siecią BlueSeaEye trzymamy OD RAZU po starcie (nie dopiero
        // po włączeniu odczytu), żeby transmisja była pewna od pierwszej chwili.
        applyDeviceWifiPreference()
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isPolling = false
        isReadingEnabled = false
        defaults.set(false, forKey: readingWasEnabledKey)
        speechGeneration += 1
        isSpeechActive = false
        speechService.stop()
        tonePlayer.stop()
        audioSessionController.stopKeepAlive()
        nowPlayingController.markStopped()
        notificationController.clearConnectionLostAlert()
        deviceWifiController.stop()
    }

    func toggleReading() {
        isReadingEnabled.toggle()
        errorMessage = nil
        defaults.set(isReadingEnabled, forKey: readingWasEnabledKey)
        CrashReporter.breadcrumb("reading: toggle -> \(isReadingEnabled ? "ON" : "OFF")")

        if isReadingEnabled {
            do {
                try audioSessionController.startKeepAlive()
                nowPlayingController.markPlaying()
                applyDeviceWifiPreference()
            } catch {
                errorMessage = error.localizedDescription
                isReadingEnabled = false
                defaults.set(false, forKey: readingWasEnabledKey)
            }
        } else {
            speechGeneration += 1
            isSpeechActive = false
            speechService.stop()
            tonePlayer.stop()
            audioSessionController.stopKeepAlive()
            nowPlayingController.markStopped()
            notificationController.clearConnectionLostAlert()
            // Sieć BlueSeaEye trzymamy niezależnie od odczytu (od startu), więc
            // NIE zdejmujemy jej tutaj — patrz applyDeviceWifiPreference().
        }
    }

    /// Wznawia odczyt po ponownym starcie procesu, jeśli był włączony w chwili
    /// zamknięcia i użytkownik na to pozwolił w ustawieniach. `launchedInBackground`
    /// mówi, czy aplikacja wstała bez interakcji użytkownika (wskrzeszenie w tle
    /// przez system po zabiciu procesu) — decyduje o trybie `.backgroundOnly`.
    func resumeIfNeeded(launchedInBackground: Bool) {
        guard !isReadingEnabled else { return }
        guard defaults.bool(forKey: readingWasEnabledKey) else { return }

        switch settingsStore.settings.autoResumeMode {
        case .never:
            return
        case .backgroundOnly:
            guard launchedInBackground else { return }
        case .always:
            break
        }

        isReadingEnabled = true
        do {
            try audioSessionController.startKeepAlive()
            nowPlayingController.markPlaying()
            applyDeviceWifiPreference()
        } catch {
            errorMessage = error.localizedDescription
            isReadingEnabled = false
        }
    }

    /// Ustawia trzymanie sieci Wi-Fi urządzenia BlueSeaEye zgodnie z ustawieniami
    /// (niezależnie od odczytu): włączone gdy `keepDeviceWifi` i nie tryb demo,
    /// inaczej zdejmuje konfigurację. Wołane na starcie oraz po zmianie ustawień.
    func applyDeviceWifiPreference() {
        let settings = settingsStore.settings
        if settings.keepDeviceWifi, !settings.demoMode {
            deviceWifiController.start()
        } else {
            deviceWifiController.stop()
        }
    }

    /// Jeśli poprzednie uruchomienie zakończyło się crashem, udostępnia jego
    /// powód na banerze (do skopiowania). NIE czyta pełnego opisu własnym
    /// syntezatorem — przy aktywnym VoiceOverze taki wymuszony komunikat nakładał
    /// się na czytnik i nie dało się go uciszyć. Zamiast tego krótkie, przerywalne
    /// ogłoszenie VoiceOver (gdy działa); pełny ślad zostaje na ekranie.
    func reportPreviousCrashIfAny() async {
        guard let reason = CrashReporter.consumeLastCrashReason() else { return }
        lastCrashReason = reason
        let notice = "Poprzednim razem aplikacja zamknęła się niespodziewanie. Szczegóły do skopiowania są na ekranie Ster."
        lastAnnouncement = notice
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: notice)
        }
    }

    func holdCurrentCourse() {
        guard let course = snapshot?.course else { return }
        settingsStore.update {
            $0.target = .course
            $0.targetCourse = HelmMath.normalizedCourse(course)
        }
    }

    func holdCurrentWind() {
        guard let wind = snapshot?.wind else { return }
        settingsStore.update {
            $0.target = .wind
            $0.targetWind = HelmMath.normalizedCourse(wind)
        }
    }

    func clearStatusMessage() {
        adminMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func prepareSafetyServices() async {
        await notificationController.requestAuthorizationIfNeeded()
    }

    func runAdministrationAction(_ action: AdministrationAction) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await apiClient.performAdministrationAction(action, settings: settingsStore.settings)
            switch action {
            case .calibrate:
                adminMessage = "Kalibracja uruchomiona."
            case .reboot:
                adminMessage = "Urządzenie rozpoczyna restart."
            }
        } catch {
            adminMessage = error.localizedDescription
        }
    }

    private func runLoop() async {
        while !Task.isCancelled {
            let now = Date()

            if isReadingEnabled, now.timeIntervalSince(lastKeepAliveCheckAt) >= keepAliveWatchdogInterval {
                lastKeepAliveCheckAt = now
                audioSessionController.ensureKeepAliveRunning()
            }

            if now.timeIntervalSince(lastFetchAt) >= statusInterval {
                lastFetchAt = now
                await refreshSnapshot()
            }

            let currentSettings = settingsStore.settings
            if isReadingEnabled, let snapshot {
                let readingDelay = currentSettings.readingOutput == .aria
                    ? currentSettings.readingInterval
                    : currentSettings.readingDelay

                if !isReadingInProgress, now.timeIntervalSince(lastReadAt) >= readingDelay {
                    lastReadAt = now
                    isReadingInProgress = true
                    let capturedSnapshot = snapshot
                    let capturedSettings = currentSettings
                    Task { [weak self] in
                        await self?.readOut(snapshot: capturedSnapshot, settings: capturedSettings)
                    }
                }

                let canSignal = currentSettings.soundSignalsEnabled
                    && (!isReadingInProgress || !currentSettings.avoidSignalsOverlap)
                if canSignal,
                   !isSignalInProgress,
                   now.timeIntervalSince(lastSignalAt) >= currentSettings.toneDelay {
                    lastSignalAt = now
                    isSignalInProgress = true
                    let capturedSnapshot = snapshot
                    let capturedLastSnapshot = lastSignaledSnapshot
                    let capturedSettings = currentSettings
                    lastSignaledSnapshot = snapshot
                    Task { [weak self] in
                        await self?.playSignal(
                            snapshot: capturedSnapshot,
                            previousSnapshot: capturedLastSnapshot,
                            settings: capturedSettings
                        )
                    }
                }
            }

            try? await Task.sleep(nanoseconds: loopDelayNanoseconds)
        }
    }

    private func refreshSnapshot() async {
        do {
            let readings = try await retrying(times: 3) { [self] in
                try await self.apiClient.fetchHelmReadings(settings: self.settingsStore.settings)
            }
            let settings = settingsStore.settings
            let course = readings.course(for: settings.courseSource)
            let rudder: Double? = {
                guard let raw = readings.rsa else { return nil }
                let corrected = raw + settings.rudderAngleCorrection
                return settings.invertRudderAngle ? -corrected : corrected
            }()
            let recovered = isConnectionLost

            snapshot = HelmSnapshot(
                course: course,
                rudder: rudder,
                wind: readings.wa,
                fetchedAt: Date()
            )
            isConnectionLost = false
            errorMessage = nil
            notificationController.clearConnectionLostAlert()

            if recovered, isReadingEnabled {
                CrashReporter.breadcrumb("connection: recovered")
                let recoveryMessage = "Połączenie zostało przywrócone."
                lastAnnouncement = recoveryMessage
                await speakCritical(recoveryMessage, settings: settings)
            }
        } catch {
            let message = "Utracono połączenie z urządzeniem BlueSeaEye. Sprawdź sieć Wi-Fi. Trwa ponawianie transmisji."
            let shouldAlert = !isConnectionLost
                || Date().timeIntervalSince(lastConnectionAlertAt) >= connectionAlertRepeatInterval

            if !isConnectionLost {
                CrashReporter.breadcrumb("connection: lost")
            }
            isConnectionLost = true
            errorMessage = message

            if shouldAlert, isReadingEnabled {
                lastConnectionAlertAt = Date()
                await alertAboutConnectionLoss(message: message)
            }
        }
    }

    private func readOut(snapshot: HelmSnapshot, settings: AppSettings) async {
        defer { isReadingInProgress = false }
        let text = snapshot.spokenReading(using: settings)
        // Pusty komunikat = nie ma nic do powiedzenia (np. tryb wiatru bez
        // danych o wietrze). Zgodnie z decyzją użytkownika NIC wtedy nie mówimy.
        guard !text.isEmpty else { return }
        lastAnnouncement = text
        await speakRegular(text, settings: settings)
    }

    private func alertAboutConnectionLoss(message: String) async {
        lastAnnouncement = message

        if isReadingEnabled {
            let settings = settingsStore.settings
            await tonePlayer.playAlertPattern(
                volume: settings.toneVolume / 100,
                waveform: settings.toneType
            )
            await speakCritical(message, settings: settings)
        }

        await notificationController.scheduleConnectionLostAlert(
            details: "Sprawdź połączenie lub zakłócenia transmisji. Aplikacja nadal ponawia odczyt."
        )
    }

    private func playSignal(
        snapshot: HelmSnapshot,
        previousSnapshot: HelmSnapshot?,
        settings: AppSettings
    ) async {
        defer { isSignalInProgress = false }
        let currentValue: Double?
        let targetValue: Double?
        let previousValue: Double?

        switch settings.target {
        case .none:
            currentValue = snapshot.course
            targetValue = nil
            previousValue = previousSnapshot?.course
        case .course:
            currentValue = snapshot.course
            targetValue = settings.targetCourse
            previousValue = previousSnapshot?.course
        case .wind:
            currentValue = snapshot.wind
            targetValue = settings.targetWind
            previousValue = previousSnapshot?.wind
        }

        // Brak wartości bieżącej (np. tryb wiatru bez czujnika wiatru na tym
        // egzemplarzu urządzenia) => brak sygnału. Zgodne z zachowaniem
        // wbudowanego frontendu urządzenia.
        guard let currentValue else { return }

        let delta: Double
        if let targetValue {
            delta = HelmMath.relativeCourse(course: currentValue, targetCourse: targetValue)
        } else if let previousValue {
            delta = HelmMath.relativeCourse(course: currentValue, targetCourse: previousValue)
        } else {
            return
        }

        let absoluteDelta = abs(delta)
        let errorExceeded = absoluteDelta > settings.errorThreshold
        let onTarget = targetValue != nil

        guard errorExceeded || settings.toneOnCourse || !onTarget else { return }

        // Czasy trwania tonów zależą od ustawienia „Krótsze sygnały" — dokładnie
        // jak w urządzeniu: ton referencyjny 80/160 ms, przerwa 20/40 ms, ton
        // właściwy 100/200 ms.
        let referenceToneDuration: TimeInterval = settings.shortTones ? 0.08 : 0.16
        let referencePause: TimeInterval = settings.shortTones ? 0.02 : 0.04
        let mainToneDuration: TimeInterval = settings.shortTones ? 0.1 : 0.2

        if errorExceeded || (!onTarget && delta != 0) {
            let compensatedDelta = absoluteDelta - (onTarget ? settings.errorThreshold : 0)
            let severity = min(compensatedDelta, settings.errorRange)
            let gain = delta > 0 ? 1.0 : -1.0
            let multiplier = settings.broadTonalSpread ? 2.0 : 1.0
            if settings.referenceTone {
                await tonePlayer.play(
                    frequency: frequencyMid,
                    duration: referenceToneDuration,
                    volume: settings.toneVolume / 100,
                    waveform: settings.toneType
                )
                // play() wraca natychmiast (nie zwalnia już odtwarzacza przez
                // sleep), więc odczekaj pełny czas trwania tonu referencyjnego
                // plus przerwę, ZANIM zagramy ton odchyłki — inaczej kolejny
                // play() wywoła stop() i urwie ton referencyjny (zgłoszone:
                // pierwszy ton był krótszy niż wcześniej).
                try? await Task.sleep(
                    nanoseconds: UInt64((referenceToneDuration + referencePause) * 1_000_000_000)
                )
            }
            let baseOffset = settings.toneBaseOffset / 12
            let frequency = frequencyMid * pow(
                2,
                gain * ((multiplier * severity / settings.errorRange) + baseOffset)
            )
            await tonePlayer.play(
                frequency: frequency,
                duration: mainToneDuration,
                volume: settings.toneVolume / 100,
                waveform: settings.toneType
            )
        } else {
            await tonePlayer.play(
                frequency: frequencyMid,
                duration: mainToneDuration,
                volume: settings.toneVolume / 100,
                waveform: settings.toneType
            )
        }
    }

    private func retrying<T>(
        times: Int,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attemptsLeft = times
        while attemptsLeft > 1 {
            do {
                return try await operation()
            } catch {
                attemptsLeft -= 1
            }
        }
        return try await operation()
    }

    private func speakRegular(_ text: String, settings: AppSettings) async {
        guard !isSpeechActive else { return }

        speechGeneration += 1
        let generation = speechGeneration
        isSpeechActive = true
        CrashReporter.breadcrumb("speak: „\(text)”")
        await speechService.announce(text, settings: settings)

        if speechGeneration == generation {
            isSpeechActive = false
        }
    }

    private func speakCritical(_ text: String, settings: AppSettings) async {
        speechGeneration += 1
        let generation = speechGeneration
        speechService.stop()
        isSpeechActive = true
        await speechService.announceCritical(text, settings: settings)

        if speechGeneration == generation {
            isSpeechActive = false
        }
    }
}
