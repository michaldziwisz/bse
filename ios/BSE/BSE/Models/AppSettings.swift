import AVFoundation
import Foundation
import UIKit

enum CourseSource: String, CaseIterable, Codable, Identifiable {
    case cgfa
    case coga
    case hdga
    case cgf
    case cog
    case hdg

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cgfa:
            return "Uśredniony kurs filtrowany"
        case .coga:
            return "Uśredniony kurs nad ziemią"
        case .hdga:
            return "Uśredniony kurs kompasowy"
        case .cgf:
            return "Kurs filtrowany"
        case .cog:
            return "Kurs nad ziemią"
        case .hdg:
            return "Kurs kompasowy"
        }
    }
}

enum ReadingOutputMode: String, CaseIterable, Codable, Identifiable {
    case tts
    case aria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tts:
            return "Synteza mowy"
        case .aria:
            return "Czytnik ekranu"
        }
    }
}

enum ToneWaveform: String, CaseIterable, Codable, Identifiable {
    case sine
    case triangle
    case sawtooth
    case square

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sine:
            return "Sinusoidalny"
        case .triangle:
            return "Trójkątny"
        case .sawtooth:
            return "Piłokształtny"
        case .square:
            return "Prostokątny"
        }
    }
}

enum TargetMode: String, CaseIterable, Codable, Identifiable {
    case none
    case course

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Kurs"
        case .course:
            return "Odchyłka od zadanego kursu"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var averageWindow: Int = 3
    var avoidSignalsOverlap: Bool = false
    var courseSource: CourseSource = .cgfa
    var readingDelay: Double = 3
    var readingInterval: Double = 5
    var readingOutput: ReadingOutputMode = .aria
    var readingRate: Double = 150
    var readingVoiceIdentifier: String?
    var readingVolume: Double = 100
    var soundSignalsEnabled: Bool = true
    var toneDelay: Double = 1
    var referenceTone: Bool = true
    var toneBaseOffset: Double = 2
    var toneOnCourse: Bool = true
    var toneType: ToneWaveform = .triangle
    var toneVolume: Double = 25
    var broadTonalSpread: Bool = false
    var target: TargetMode = .none
    var targetCourse: Double?
    var errorThreshold: Double = 1
    var errorRange: Double = 30
    var invertRudderAngle: Bool = false
    var rudderAngleCorrection: Double = 0

    static let `default` = AppSettings()

    static func resolvedDefault() -> AppSettings {
        var settings = AppSettings()
        #if os(iOS)
        settings.readingOutput = UIAccessibility.isVoiceOverRunning ? .aria : .tts
        #endif
        if let preferredVoice = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language.hasPrefix("pl") }) {
            settings.readingVoiceIdentifier = preferredVoice.identifier
        }
        return settings
    }

    mutating func clampValues() {
        averageWindow = min(max(averageWindow, 1), 5)
        readingDelay = min(max(readingDelay, 0), 30)
        readingInterval = min(max(readingInterval, 1), 45)
        readingRate = min(max(readingRate, 50), 400)
        readingVolume = min(max(readingVolume, 0), 100)
        toneDelay = min(max(toneDelay, 0.5), 5)
        toneBaseOffset = min(max(toneBaseOffset, 0), 6)
        toneVolume = min(max(toneVolume, 0), 100)
        errorThreshold = min(max(errorThreshold, 1), 15)
        errorRange = min(max(errorRange, 15), 60)
        rudderAngleCorrection = min(max(rudderAngleCorrection, -90), 90)
        if let targetCourse {
            self.targetCourse = ((targetCourse.rounded().truncatingRemainder(dividingBy: 360)) + 360)
                .truncatingRemainder(dividingBy: 360)
        }
    }
}

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String

    var title: String {
        "\(name) (\(language))"
    }
}
