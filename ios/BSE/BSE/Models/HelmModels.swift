import Foundation

struct HelmReadings: Decodable, Equatable {
    let cgfa: Double?
    let cgf: Double?
    let coga: Double?
    let cog: Double?
    let hdga: Double?
    let hdg: Double?
    let rsa: Double?
    let wa: Double?

    enum CodingKeys: String, CodingKey {
        case cgfa
        case cgf
        case coga
        case cog
        case hdga
        case hdg
        case rsa
        case wa
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cgfa = try Self.decodeDouble(for: .cgfa, in: container)
        cgf = try Self.decodeDouble(for: .cgf, in: container)
        coga = try Self.decodeDouble(for: .coga, in: container)
        cog = try Self.decodeDouble(for: .cog, in: container)
        hdga = try Self.decodeDouble(for: .hdga, in: container)
        hdg = try Self.decodeDouble(for: .hdg, in: container)
        rsa = try Self.decodeDouble(for: .rsa, in: container)
        wa = try Self.decodeDouble(for: .wa, in: container)
    }

    func course(for source: CourseSource) -> Double? {
        switch source {
        case .cgfa:
            return cgfa
        case .coga:
            return coga
        case .hdga:
            return hdga
        case .cgf:
            return cgf
        case .cog:
            return cog
        case .hdg:
            return hdg
        }
    }

    private static func decodeDouble(
        for key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Double? {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        if let intValue = try container.decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        return nil
    }
}

struct HelmSnapshot: Equatable {
    let course: Double?
    let rudder: Double?
    let wind: Double?
    let fetchedAt: Date

    func displayedValue(using settings: AppSettings) -> Int? {
        let currentValue = currentValue(using: settings)
        let targetValue = targetValue(using: settings)
        guard let currentValue else { return nil }
        if let targetValue {
            return Int(HelmMath.relativeCourse(course: currentValue, targetCourse: targetValue).rounded())
        }
        return Int(currentValue.rounded())
    }

    func currentValue(using settings: AppSettings) -> Double? {
        switch settings.target {
        case .none, .course:
            return course
        case .wind:
            return wind
        }
    }

    func targetValue(using settings: AppSettings) -> Double? {
        switch settings.target {
        case .none:
            return nil
        case .course:
            return settings.targetCourse
        case .wind:
            return settings.targetWind
        }
    }

    /// Komunikat odczytu składany DOKŁADNIE tak, jak wbudowany frontend
    /// urządzenia BlueSeaEye (main.js): sama liczba głównej wartości (kurs,
    /// odchyłka od kursu albo odchyłka od kąta do wiatru) bez etykiety
    /// słownej, a następnie ster jako „Prawo N" / „Lewo N" (bez słowa „Ster").
    /// Elementy łączone przecinkiem. Zwraca pusty ciąg, gdy nie ma nic do
    /// powiedzenia (np. tryb wiatru bez danych o wietrze) — wywołujący pomija
    /// wtedy wypowiedź.
    ///
    /// Zgodność 1:1 z urządzeniem: przy braku wartości głównej w trybie kursu
    /// i odchyłki od kursu urządzenie mówi „Kurs nieznany" (nie ma osobnego
    /// komunikatu dla odchyłki). W trybie wiatru bez danych — na życzenie
    /// użytkownika NIC nie jest wypowiadane (pomijamy token, zamiast mówić
    /// „Wiatr nieznany").
    func spokenReading(using settings: AppSettings) -> String {
        var parts: [String] = []

        if let value = displayedValue(using: settings) {
            if settings.target == .course {
                // Odchyłka od zadanego kursu. Komenda dla sternika jest w slangu
                // żeglarskim ODWROTNA do strony, z której odzywa się sygnał
                // dźwiękowy: sygnał z prawej (wartość < 0, próbka right) => skręcaj
                // w lewo => „lewiej”; sygnał z lewej (wartość > 0, próbka left) =>
                // skręcaj w prawo => „prawiej”. Zero = na kursie.
                if value < 0 {
                    parts.append("lewiej \(abs(value))")
                } else if value > 0 {
                    parts.append("prawiej \(value)")
                } else {
                    parts.append("0")
                }
            } else {
                parts.append("\(value)")
            }
        } else {
            switch settings.target {
            case .none, .course:
                parts.append("Kurs nieznany")
            case .wind:
                // Tryb wiatru bez danych o wietrze: na życzenie użytkownika NIC
                // nie jest wypowiadane — pomijamy CAŁĄ wypowiedź (także ster).
                return ""
            }
        }

        if settings.announceRudderAngle, let rudder {
            let side = rudder > 0 ? "Prawo" : "Lewo"
            parts.append("\(side) \(abs(Int(rudder.rounded())))")
        }

        return parts.joined(separator: ", ")
    }
}

enum HelmMath {
    static func relativeCourse(course: Double, targetCourse: Double) -> Double {
        var delta = course - targetCourse
        while delta <= -180 {
            delta += 360
        }
        while delta > 180 {
            delta -= 360
        }
        return delta
    }

    static func normalizedCourse(_ course: Double) -> Double {
        ((course.rounded().truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
    }
}
