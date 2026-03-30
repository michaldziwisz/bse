import AVFoundation
import UIKit

@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ text: String, settings: AppSettings) async {
        switch settings.readingOutput {
        case .aria:
            UIAccessibility.post(notification: .announcement, argument: text)
        case .tts:
            await speak(text, settings: settings)
        }
    }

    func stop() {
        let pendingContinuation = continuation
        continuation = nil
        pendingContinuation?.resume(returning: ())
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    private func speak(_ text: String, settings: AppSettings) async {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: settings.readingVoiceIdentifier)
        utterance.volume = Float(settings.readingVolume / 100)
        utterance.rate = mapRate(fromPercent: settings.readingRate)

        await withCheckedContinuation { continuation in
            self.continuation = continuation
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
}
