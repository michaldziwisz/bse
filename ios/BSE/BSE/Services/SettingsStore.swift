import AVFoundation
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            var sanitized = settings
            sanitized.clampValues()
            if sanitized != settings {
                settings = sanitized
                return
            }
            save(settings)
        }
    }

    private let storageKey = "bse.settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.loadInitialSettings(defaults: defaults)
    }

    func update(_ mutation: (inout AppSettings) -> Void) {
        var copy = settings
        mutation(&copy)
        copy.clampValues()
        settings = copy
    }

    func availableVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted {
                if $0.language == $1.language {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.language.localizedCaseInsensitiveCompare($1.language) == .orderedAscending
            }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
                )
            }
    }

    private func save(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private static func loadInitialSettings(defaults: UserDefaults) -> AppSettings {
        let fallback = AppSettings.resolvedDefault()
        guard
            let data = defaults.data(forKey: "bse.settings"),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return fallback
        }
        var sanitized = decoded
        sanitized.clampValues()
        if sanitized.readingVoiceIdentifier == nil {
            sanitized.readingVoiceIdentifier = fallback.readingVoiceIdentifier
        }
        return sanitized
    }
}
