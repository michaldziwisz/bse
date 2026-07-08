import AVFoundation
import Foundation

/// Podtrzymuje aktywną sesję audio, aby odczyt steru (mowa i tony) działał
/// nieprzerwanie także przy zgaszonym ekranie i w tle.
///
/// UWAGA PROJEKTOWA: świadomie NIE używamy AVAudioEngine. Po wielu godzinach
/// pracy AVAudioEngine potrafi — przy zmianie trasy audio, zmianie konfiguracji
/// lub resecie serwera mediów — rzucić wyjątek Objective-C, którego w Swift NIE
/// da się przechwycić przez try/catch, co kończy się TWARDYM crashem całej
/// aplikacji. To był najprawdopodobniejszy powód, dla którego aplikacja „wywalała
/// się” po godzinie–trzech. Zamiast tego gramy zapętlony, bardzo cichy bufor przez
/// zwykły AVAudioPlayer, który jest odporny na te sytuacje (tak robią stabilne
/// odtwarzacze działające godzinami).
@MainActor
final class AudioSessionController {
    private let session = AVAudioSession.sharedInstance()
    private let sampleRate = 44_100
    private var keepAlivePlayer: AVAudioPlayer?
    private var keepAliveData: Data?
    private(set) var isKeepAliveEnabled = false

    init() {
        observeAudioLifecycle()
    }

    func prepareForPlayback() throws {
        // BEZ .mixWithOthers: aplikacja jest GŁÓWNYM odtwarzaczem, dzięki czemu
        // iOS pokazuje Now Playing na ekranie blokady i najmocniej chroni proces
        // przed ubiciem w tle. Kompromis: włączenie odczytu wyciszy inne audio
        // (muzyka/nawigacja) — na łódce priorytetem jest, by odczyt steru nie milkł.
        try session.setCategory(.playback, mode: .voicePrompt)
        try session.setActive(true)
    }

    func startKeepAlive() throws {
        try prepareForPlayback()
        try startLoopingTone()
        isKeepAliveEnabled = true
    }

    func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        isKeepAliveEnabled = false
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            return
        }
    }

    /// Watchdog wołany cyklicznie z pętli monitora. Jeśli podtrzymanie powinno
    /// działać, a odtwarzacz z jakiegokolwiek powodu przestał grać, wznawia go.
    /// AVAudioPlayer nie unieważnia się jak AVAudioEngine, więc zwykle wystarcza
    /// samo `play()`, a w razie potrzeby odtwarzacz jest tworzony od nowa.
    func ensureKeepAliveRunning() {
        guard isKeepAliveEnabled else { return }
        if let player = keepAlivePlayer, player.isPlaying {
            return
        }
        do {
            try prepareForPlayback()
            if let player = keepAlivePlayer {
                player.play()
                if player.isPlaying { return }
            }
            try startLoopingTone()
        } catch {
            return
        }
    }

    // MARK: - Zapętlony cichy ton (AVAudioPlayer)

    private func startLoopingTone() throws {
        let data = try keepAliveToneData()
        // Odtwórz od nowa: nowy odtwarzacz jest tani i całkowicie unika stanów
        // pośrednich starego (pauza/uszkodzony bufor).
        keepAlivePlayer?.stop()
        let player = try AVAudioPlayer(data: data)
        player.numberOfLoops = -1 // nieskończona pętla
        player.volume = 1
        player.prepareToPlay()
        keepAlivePlayer = player
        player.play()
    }

    private func keepAliveToneData() throws -> Data {
        if let keepAliveData {
            return keepAliveData
        }

        // 1 sekunda cichego sinusa 220 Hz. Amplituda ~0.004 (~-48 dB): niesłyszalna
        // dla użytkownika, ale „realna” dla systemu, więc iOS traktuje aplikację
        // jako aktywnie odtwarzającą.
        let frameCount = sampleRate
        var pcm = Data(capacity: frameCount * MemoryLayout<Int16>.size)
        let amplitude = 0.004
        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let value = sin(2 * .pi * 220 * time) * amplitude
            var sample = Int16(max(min(value * Double(Int16.max), Double(Int16.max)), Double(Int16.min)))
                .littleEndian
            pcm.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
        }

        let data = makeWaveFile(fromPCM: pcm, channels: 1, sampleRate: sampleRate, bitsPerSample: 16)
        keepAliveData = data
        return data
    }

    private func makeWaveFile(
        fromPCM pcmData: Data,
        channels: UInt16,
        sampleRate: Int,
        bitsPerSample: UInt16
    ) -> Data {
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let riffSize = 36 + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        append(riffSize, to: &data)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(channels, to: &data)
        append(UInt32(sampleRate), to: &data)
        append(byteRate, to: &data)
        append(blockAlign, to: &data)
        append(bitsPerSample, to: &data)
        data.append("data".data(using: .ascii)!)
        append(dataSize, to: &data)
        data.append(pcmData)
        return data
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        data.append(Data(bytes: &littleEndian, count: MemoryLayout<T>.size))
    }

    // MARK: - Reakcja na zdarzenia systemowe audio

    private func observeAudioLifecycle() {
        observe(AVAudioSession.interruptionNotification) { [weak self] notification in
            await self?.handleInterruption(notification)
        }
        observe(AVAudioSession.mediaServicesWereResetNotification) { [weak self] _ in
            await self?.recoverKeepAliveIfNeeded()
        }
        observe(AVAudioSession.routeChangeNotification) { [weak self] _ in
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

    private func recoverKeepAliveIfNeeded() async {
        if isKeepAliveEnabled {
            do {
                try prepareForPlayback()
                try startLoopingTone()
            } catch {
                return
            }
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
