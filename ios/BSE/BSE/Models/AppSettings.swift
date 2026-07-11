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
    case wind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Aktualny kurs"
        case .course:
            return "Zadany kurs"
        case .wind:
            return "Odchyłka od kąta do wiatru"
        }
    }
}

/// Zachowanie odczytu po ponownym uruchomieniu aplikacji (np. gdy system iOS
/// ubił proces w tle pod presją pamięci i wznowił go później). Domyślnie
/// aplikacja NIC nie robi sama — czeka na świadome włączenie odczytu przyciskiem.
enum AutoResumeMode: String, CaseIterable, Codable, Identifiable {
    /// Nigdy nie wznawiaj automatycznie (domyślne).
    case never
    /// Wznów tylko, gdy system sam wskrzesił aplikację w tle (bez otwierania jej
    /// przez użytkownika) — po ręcznym otwarciu odczyt czeka na przycisk.
    case backgroundOnly
    /// Wznów zawsze przy starcie, jeśli odczyt był włączony w chwili zamknięcia.
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never:
            return "Nie wznawiaj (domyślnie)"
        case .backgroundOnly:
            return "Tylko po wznowieniu w tle"
        case .always:
            return "Zawsze przy starcie"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var averageWindow: Int = 3
    var avoidSignalsOverlap: Bool = false
    var courseSource: CourseSource = .cgfa
    var deviceHost: String = AppSettings.defaultDeviceHost
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
    var shortTones: Bool = true
    var broadTonalSpread: Bool = false
    var target: TargetMode = .none
    var targetCourse: Double?
    var targetWind: Double?
    var errorThreshold: Double = 1
    var errorRange: Double = 30
    var invertRudderAngle: Bool = false
    var rudderAngleCorrection: Double = 0
    var autoResumeMode: AutoResumeMode = .never
    var demoMode: Bool = false
    var keepDeviceWifi: Bool = true

    /// Domyślny host urządzenia BlueSeaEye w trybie access pointa (brama SoftAP).
    static let defaultDeviceHost = "192.168.4.1"

    /// SSID i hasło access pointa urządzenia BlueSeaEye (tryb SoftAP).
    static let deviceWifiSSID = "BlueSeaEye"
    static let deviceWifiPassphrase = "blueseaeye"

    /// Adres bazowy serwera demonstracyjnego BlueSeaEye. W trybie demo aplikacja
    /// łączy się z nim przez internet zamiast ze sprzętem w sieci lokalnej —
    /// pozwala testować bez łodzi i bez fizycznego urządzenia.
    static let demoBaseURL = URL(string: "https://blueseaeye.eu/api")!

    static let `default` = AppSettings()

    init() {}

    /// Tolerancyjne dekodowanie: brakujące klucze (np. w ustawieniach zapisanych
    /// przez starszą wersję aplikacji, sprzed dodania `deviceHost`) przyjmują
    /// wartości domyślne zamiast unieważniać cały zapis.
    init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        averageWindow = value(.averageWindow, defaults.averageWindow)
        avoidSignalsOverlap = value(.avoidSignalsOverlap, defaults.avoidSignalsOverlap)
        courseSource = value(.courseSource, defaults.courseSource)
        deviceHost = value(.deviceHost, defaults.deviceHost)
        readingDelay = value(.readingDelay, defaults.readingDelay)
        readingInterval = value(.readingInterval, defaults.readingInterval)
        readingOutput = value(.readingOutput, defaults.readingOutput)
        readingRate = value(.readingRate, defaults.readingRate)
        readingVoiceIdentifier = (try? container.decodeIfPresent(String.self, forKey: .readingVoiceIdentifier)) ?? defaults.readingVoiceIdentifier
        readingVolume = value(.readingVolume, defaults.readingVolume)
        soundSignalsEnabled = value(.soundSignalsEnabled, defaults.soundSignalsEnabled)
        toneDelay = value(.toneDelay, defaults.toneDelay)
        referenceTone = value(.referenceTone, defaults.referenceTone)
        toneBaseOffset = value(.toneBaseOffset, defaults.toneBaseOffset)
        toneOnCourse = value(.toneOnCourse, defaults.toneOnCourse)
        toneType = value(.toneType, defaults.toneType)
        toneVolume = value(.toneVolume, defaults.toneVolume)
        shortTones = value(.shortTones, defaults.shortTones)
        broadTonalSpread = value(.broadTonalSpread, defaults.broadTonalSpread)
        target = value(.target, defaults.target)
        targetCourse = (try? container.decodeIfPresent(Double.self, forKey: .targetCourse)) ?? defaults.targetCourse
        targetWind = (try? container.decodeIfPresent(Double.self, forKey: .targetWind)) ?? defaults.targetWind
        errorThreshold = value(.errorThreshold, defaults.errorThreshold)
        errorRange = value(.errorRange, defaults.errorRange)
        invertRudderAngle = value(.invertRudderAngle, defaults.invertRudderAngle)
        rudderAngleCorrection = value(.rudderAngleCorrection, defaults.rudderAngleCorrection)
        autoResumeMode = value(.autoResumeMode, defaults.autoResumeMode)
        demoMode = value(.demoMode, defaults.demoMode)
        keepDeviceWifi = value(.keepDeviceWifi, defaults.keepDeviceWifi)
    }

    /// Adres bazowy API urządzenia zbudowany z `deviceHost`. Akceptuje samo IP
    /// lub nazwę hosta, a także pełny URL wpisany przez użytkownika.
    ///
    /// W trybie demo (`demoMode`) zwraca zawsze serwer demonstracyjny w
    /// internecie zamiast adresu sprzętu w sieci lokalnej — dzięki temu odczyt
    /// i akcje administracyjne działają bez łodzi i bez fizycznego urządzenia.
    func deviceBaseURL() -> URL {
        if demoMode {
            return AppSettings.demoBaseURL
        }
        let trimmed = deviceHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = trimmed.isEmpty ? AppSettings.defaultDeviceHost : trimmed
        if let url = URL(string: host), url.scheme != nil, url.host != nil {
            // Pełny URL podany przez użytkownika – uzupełnij o ścieżkę /api,
            // jeśli jej nie zawiera.
            if url.path.contains("api") {
                return url
            }
            return url.appendingPathComponent("api")
        }
        return URL(string: "http://\(host)/api") ?? AppSettings.fallbackDeviceBaseURL
    }

    static let fallbackDeviceBaseURL = URL(string: "http://192.168.4.1/api")!

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
        if let targetWind {
            self.targetWind = ((targetWind.rounded().truncatingRemainder(dividingBy: 360)) + 360)
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
