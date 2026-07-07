import AVFoundation
import Foundation

@MainActor
final class AudioSessionController {
    private let session = AVAudioSession.sharedInstance()
    private var keepAliveEngine = AVAudioEngine()
    private var keepAlivePlayer = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private(set) var isKeepAliveEnabled = false

    init() {
        buildEngine()
        observeAudioLifecycle()
    }

    func prepareForPlayback() throws {
        // BEZ .mixWithOthers: aplikacja jest GŁÓWNYM odtwarzaczem, dzięki czemu
        // iOS pokazuje Now Playing na ekranie blokady i najmocniej chroni proces
        // przed ubiciem w tle (dźwięk mieszany/ambientowy leci jako pierwszy pod
        // presją pamięci i nie dostaje sterowania na blokadzie). Kompromis:
        // włączenie odczytu wyciszy inne audio (muzyka/nawigacja) — na łódce
        // priorytetem jest, by odczyt steru nie milkł.
        try session.setCategory(.playback, mode: .voicePrompt)
        try session.setActive(true)
    }

    func startKeepAlive() throws {
        try prepareForPlayback()
        try startEngineAndLoop()
        isKeepAliveEnabled = true
    }

    func stopKeepAlive() {
        keepAlivePlayer.stop()
        keepAliveEngine.pause()
        isKeepAliveEnabled = false
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            return
        }
    }

    /// Watchdog: wywoływane cyklicznie z pętli monitora. Jeśli podtrzymanie
    /// powinno działać, a silnik/odtwarzacz z jakiegokolwiek powodu zamilkł
    /// (reset mediaserverd, zmiana konfiguracji, uśpienie), wskrzesza dźwięk.
    /// Dzięki temu apka nie milknie na trwałe po wielu godzinach pracy.
    func ensureKeepAliveRunning() {
        guard isKeepAliveEnabled else { return }
        if keepAliveEngine.isRunning && keepAlivePlayer.isPlaying {
            return
        }
        do {
            try prepareForPlayback()
            try startEngineAndLoop()
        } catch {
            // Silnik mógł zostać unieważniony (np. mediaServicesWereReset) -
            // odbuduj go od zera i spróbuj ponownie.
            rebuildEngine()
            do {
                try prepareForPlayback()
                try startEngineAndLoop()
            } catch {
                return
            }
        }
    }

    // MARK: - Silnik podtrzymania

    private func buildEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        keepAliveEngine.attach(keepAlivePlayer)
        keepAliveEngine.connect(keepAlivePlayer, to: keepAliveEngine.mainMixerNode, format: format)
    }

    /// Po resecie serwera mediów wszystkie obiekty audio są martwe - trzeba je
    /// stworzyć na nowo, inaczej engine.start() nie przywróci dźwięku.
    private func rebuildEngine() {
        keepAlivePlayer.stop()
        keepAliveEngine.stop()
        keepAliveEngine = AVAudioEngine()
        keepAlivePlayer = AVAudioPlayerNode()
        keepAliveBuffer = nil
        buildEngine()
    }

    private func startEngineAndLoop() throws {
        if !keepAliveEngine.isRunning {
            try keepAliveEngine.start()
        }

        let buffer = try makeKeepAliveBuffer()
        keepAlivePlayer.stop()
        keepAlivePlayer.volume = 1
        keepAlivePlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        keepAlivePlayer.play()
    }

    private func makeKeepAliveBuffer() throws -> AVAudioPCMBuffer {
        if let keepAliveBuffer {
            return keepAliveBuffer
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioSessionError.bufferCreationFailed
        }

        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            let totalFrames = Int(frameCount)
            for frame in 0..<totalFrames {
                let time = Double(frame) / sampleRate
                // Amplituda ~0.004 (~-48 dB): niesłyszalna dla użytkownika, ale
                // wystarczająco realna, by iOS uznał to za AKTYWNE odtwarzanie i
                // nie ubijał procesu w tle (sinus na 0.0001 ≈ -80 dB system
                // traktował jak ciszę i proces stawał się kandydatem do ubicia).
                channel[frame] = Float(sin(2 * .pi * 220 * time) * 0.004)
            }
        }

        keepAliveBuffer = buffer
        return buffer
    }

    // MARK: - Reakcja na zdarzenia systemowe audio

    private func observeAudioLifecycle() {
        observe(AVAudioSession.interruptionNotification) { [weak self] notification in
            await self?.handleInterruption(notification)
        }
        observe(AVAudioSession.mediaServicesWereResetNotification) { [weak self] _ in
            await self?.handleMediaServicesReset()
        }
        observe(AVAudioSession.routeChangeNotification) { [weak self] _ in
            await self?.recoverKeepAliveIfNeeded()
        }
        observe(.AVAudioEngineConfigurationChange) { [weak self] _ in
            await self?.recoverKeepAliveIfNeeded()
        }
    }

    private func observe(
        _ name: Notification.Name,
        handler: @escaping (Notification) async -> Void
    ) {
        Task {
            for await notification in NotificationCenter.default.notifications(named: name) {
                await handler(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) async {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        guard type == .ended else { return }
        await recoverKeepAliveIfNeeded()
    }

    /// Reset mediaserverd unieważnia CAŁY stos audio - odbuduj silnik i wznów.
    private func handleMediaServicesReset() async {
        rebuildEngine()
        await recoverKeepAliveIfNeeded()
    }

    private func recoverKeepAliveIfNeeded() async {
        if isKeepAliveEnabled {
            ensureKeepAliveRunning()
        } else {
            try? prepareForPlayback()
        }
    }
}

enum AudioSessionError: LocalizedError {
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Nie udało się przygotować bufora audio."
        }
    }
}
