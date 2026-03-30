import AVFoundation
import UIKit

@MainActor
final class SpeechService: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private var synthesizer: AVSpeechSynthesizer
    private var continuation: CheckedContinuation<SpeechOutcome, Never>?
    private var timeoutTask: Task<Void, Never>?
    private let audioSessionController: AudioSessionController

    init(audioSessionController: AudioSessionController) {
        self.audioSessionController = audioSessionController
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        configureSynthesizer()
    }

    func announce(_ text: String, settings: AppSettings) async {
        let shouldUseAccessibilityAnnouncement = settings.readingOutput == .aria
            && UIApplication.shared.applicationState == .active

        if shouldUseAccessibilityAnnouncement {
            UIAccessibility.post(notification: .announcement, argument: text)
        } else {
            await speakWithRecovery(text, settings: settings)
        }
    }

    func announceCritical(_ text: String, settings: AppSettings) async {
        await speakWithRecovery(text, settings: settings)
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        completeCurrentSpeech(with: .cancelled)
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        rebuildSynthesizer()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        completeCurrentSpeech(with: .finished)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        completeCurrentSpeech(with: .cancelled)
    }

    private func speakWithRecovery(_ text: String, settings: AppSettings) async {
        let outcome = await speakOnce(text, settings: settings)
        if outcome == .timedOut {
            rebuildSynthesizer()
            _ = await speakOnce(text, settings: settings)
        }
    }

    private func speakOnce(_ text: String, settings: AppSettings) async -> SpeechOutcome {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
            rebuildSynthesizer()
        }

        do {
            try audioSessionController.prepareForPlayback()
        } catch {
            return .cancelled
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: settings.readingVoiceIdentifier)
        utterance.volume = Float(settings.readingVolume / 100)
        utterance.rate = mapRate(fromPercent: settings.readingRate)
        utterance.prefersAssistiveTechnologySettings = true

        let timeout = speechTimeout(for: text, settings: settings)

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            scheduleTimeout(after: timeout)
            synthesizer.speak(utterance)
        }
    }

    private func voice(for identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let selectedVoice = AVSpeechSynthesisVoice(identifier: identifier) {
            return selectedVoice
        }
        return AVSpeechSynthesisVoice(language: "pl-PL")
            ?? AVSpeechSynthesisVoice.speechVoices().first
    }

    private func mapRate(fromPercent percent: Double) -> Float {
        let normalized = min(max(percent, 50), 400)
        let scaled = 0.28 + ((normalized - 50) / 350) * 0.36
        return Float(scaled)
    }

    private func configureSynthesizer() {
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    private func rebuildSynthesizer() {
        timeoutTask?.cancel()
        timeoutTask = nil
        synthesizer.delegate = nil
        synthesizer = AVSpeechSynthesizer()
        configureSynthesizer()
    }

    private func scheduleTimeout(after seconds: TimeInterval) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                guard self.continuation != nil else { return }
                self.completeCurrentSpeech(with: .timedOut)
                if self.synthesizer.isSpeaking || self.synthesizer.isPaused {
                    self.synthesizer.stopSpeaking(at: .immediate)
                }
                self.rebuildSynthesizer()
            }
        }
    }

    private func completeCurrentSpeech(with outcome: SpeechOutcome) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let pendingContinuation = continuation
        continuation = nil
        pendingContinuation?.resume(returning: outcome)
    }

    private func speechTimeout(for text: String, settings: AppSettings) -> TimeInterval {
        let baseDuration = max(6, Double(text.count) / 7 + 4)
        let rateFactor = max(settings.readingRate / 150, 0.5)
        return min(max(baseDuration / rateFactor, 4), 20)
    }
}

private enum SpeechOutcome {
    case finished
    case cancelled
    case timedOut
}
