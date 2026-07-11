import Foundation
import NetworkExtension

/// Utrzymuje telefon połączony z siecią Wi-Fi urządzenia BlueSeaEye, aby system
/// nie przełączył się w trakcie odczytu ze steru na inną zapamiętaną sieć
/// (np. statkowe Wi-Fi z internetem, które chwilowo ma lepszy zasięg).
///
/// iOS nie daje pełnego odpowiednika androidowego `bindProcessToNetwork` (nie da
/// się „przypiąć" ruchu aplikacji do konkretnego SSID). Najbliższy dostępny
/// mechanizm to `NEHotspotConfiguration`:
///  - `apply` instaluje konfigurację sieci `BlueSeaEye` z `joinOnce = false`,
///    dzięki czemu iOS traktuje ją jako preferowaną i sam do niej dołącza oraz
///    ją utrzymuje, dopóki konfiguracja jest aktywna.
///  - `remove` usuwa konfigurację, gdy odczyt jest wyłączany — telefon wraca do
///    normalnego zarządzania sieciami.
///
/// WAŻNE: `NEHotspotConfiguration` wymaga uprawnienia „Hotspot Configuration"
/// (entitlement) i podpisu aplikacji. Przy niepodpisanej wersji testowej wywołanie
/// może się nie powieść — kod ignoruje wtedy błąd (aplikacja działa dalej,
/// po prostu bez trzymania sieci). Na wersji podpisanej (App Store / TestFlight)
/// mechanizm działa.
@MainActor
final class DeviceWifiController {

    enum Status {
        case inactive
        case joining
        case active
        case unavailable
    }

    private(set) var status: Status = .inactive

    private let ssid: String
    private let passphrase: String

    init(ssid: String, passphrase: String) {
        self.ssid = ssid
        self.passphrase = passphrase
    }

    /// Instaluje konfigurację sieci urządzenia i prosi system o dołączenie.
    /// Bezpieczne do wielokrotnego wołania.
    func start() {
        status = .joining
        let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
        // joinOnce = false => konfiguracja jest trwała: iOS traktuje sieć jako
        // preferowaną i sam ją utrzymuje, dopóki jej nie usuniemy w stop().
        configuration.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let nsError = error as NSError?,
                   nsError.domain == NEHotspotConfigurationErrorDomain,
                   nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    // Już połączeni z tą siecią — traktujemy jako sukces.
                    self.status = .active
                } else if error != nil {
                    self.status = .unavailable
                } else {
                    self.status = .active
                }
            }
        }
    }

    /// Usuwa konfigurację sieci urządzenia — telefon wraca do normalnego
    /// zarządzania sieciami przez system.
    func stop() {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        status = .inactive
    }
}
