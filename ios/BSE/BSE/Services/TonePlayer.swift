import AVFoundation
import Foundation

@MainActor
final class TonePlayer {
    private let sampleRate = 44_100.0
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func stop() {
        player.stop()
        engine.stop()
    }

    func play(
        frequency: Double,
        duration: TimeInterval = 0.1,
        volume: Double,
        waveform: ToneWaveform
    ) async {
        guard duration > 0 else { return }
        do {
            try ensureEngineStarted()
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let frameCount = AVAudioFrameCount(duration * sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }
            buffer.frameLength = frameCount
            let amplitude = min(max(volume, 0), 1)
            let totalFrames = Int(frameCount)

            if let channel = buffer.floatChannelData?[0] {
                for frame in 0..<totalFrames {
                    let time = Double(frame) / sampleRate
                    let progress = Double(frame) / Double(max(totalFrames - 1, 1))
                    let envelope = sin(.pi * progress)
                    let phase = 2 * Double.pi * frequency * time
                    channel[frame] = Float(sample(for: phase, waveform: waveform) * amplitude * envelope)
                }
            }

            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying {
                player.play()
            }

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        } catch {
            return
        }
    }

    private func ensureEngineStarted() throws {
        if engine.isRunning { return }
        try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
        try engine.start()
    }

    private func sample(for phase: Double, waveform: ToneWaveform) -> Double {
        switch waveform {
        case .sine:
            return sin(phase)
        case .triangle:
            return 2 * abs(2 * ((phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)) - 1) - 1
        case .sawtooth:
            return 2 * ((phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)) - 1
        case .square:
            return sin(phase) >= 0 ? 1 : -1
        }
    }
}
