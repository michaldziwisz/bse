import AVFoundation
import Foundation

@MainActor
final class TonePlayer {
    private let sampleRate = 44_100
    private let audioSessionController: AudioSessionController
    private var activePlayer: AVAudioPlayer?

    init(audioSessionController: AudioSessionController) {
        self.audioSessionController = audioSessionController
    }

    func stop() {
        activePlayer?.stop()
        activePlayer = nil
    }

    func play(
        frequency: Double,
        duration: TimeInterval = 0.1,
        volume: Double,
        waveform: ToneWaveform
    ) async {
        guard duration > 0 else { return }
        do {
            try audioSessionController.prepareForPlayback()
            stop()

            let toneData = try makeToneData(
                frequency: frequency,
                duration: duration,
                volume: volume,
                waveform: waveform
            )

            let player = try AVAudioPlayer(data: toneData)
            player.volume = 1
            player.prepareToPlay()
            guard player.play() else { return }
            activePlayer = player

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if activePlayer === player {
                activePlayer = nil
            }
        } catch {
            return
        }
    }

    func playAlertPattern(volume: Double, waveform: ToneWaveform) async {
        let alertVolume = max(volume, 0.85)
        let frequencies: [Double] = [1320, 880, 1320]

        for frequency in frequencies {
            await play(
                frequency: frequency,
                duration: 0.22,
                volume: alertVolume,
                waveform: waveform
            )
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func makeToneData(
        frequency: Double,
        duration: TimeInterval,
        volume: Double,
        waveform: ToneWaveform
    ) throws -> Data {
        let frameCount = max(Int(Double(sampleRate) * duration), 1)
        let amplitude = min(max(volume, 0), 1) * 0.9
        var pcmData = Data(capacity: frameCount * MemoryLayout<Int16>.size)

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let envelope = sin(.pi * progress)
            let phase = 2 * Double.pi * frequency * time
            let sampleValue = sample(for: phase, waveform: waveform) * amplitude * envelope
            var sample = Int16(max(min(sampleValue * Double(Int16.max), Double(Int16.max)), Double(Int16.min)))
                .littleEndian
            pcmData.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
        }

        return makeWaveFile(fromPCM: pcmData, channels: 1, sampleRate: sampleRate, bitsPerSample: 16)
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
}
