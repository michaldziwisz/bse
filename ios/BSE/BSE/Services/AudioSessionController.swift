import AVFoundation
import Foundation

@MainActor
final class AudioSessionController {
    private let session = AVAudioSession.sharedInstance()
    private let keepAliveEngine = AVAudioEngine()
    private let keepAlivePlayer = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private(set) var isKeepAliveEnabled = false

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        keepAliveEngine.attach(keepAlivePlayer)
        keepAliveEngine.connect(keepAlivePlayer, to: keepAliveEngine.mainMixerNode, format: format)

        Task { [weak self] in
            guard let self else { return }
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            ) {
                await self.handleInterruption(notification)
            }
        }
    }

    func prepareForPlayback() throws {
        try session.setCategory(
            .playback,
            mode: .voicePrompt,
            options: [.mixWithOthers, .interruptSpokenAudioAndMixWithOthers]
        )
        try session.setActive(true)
    }

    func startKeepAlive() throws {
        try prepareForPlayback()
        if !keepAliveEngine.isRunning {
            try keepAliveEngine.start()
        }

        let buffer = try makeKeepAliveBuffer()
        keepAlivePlayer.stop()
        keepAlivePlayer.volume = 1
        keepAlivePlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        keepAlivePlayer.play()
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
                channel[frame] = Float(sin(2 * .pi * 220 * time) * 0.0001)
            }
        }

        keepAliveBuffer = buffer
        return buffer
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

        do {
            if isKeepAliveEnabled {
                try startKeepAlive()
            } else {
                try prepareForPlayback()
            }
        } catch {
            return
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
