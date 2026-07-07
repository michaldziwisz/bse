import Foundation
import MediaPlayer

/// Rejestruje aplikację w systemie jako aktywny odtwarzacz dźwięku. Dzięki temu
/// iOS traktuje ją jak YouTube/foobar (Now Playing + zdalne sterowanie) i znacznie
/// rzadziej ubija proces w tle pod presją pamięci. To atakuje przyczynę „cichnięcia
/// po godzinach” u źródła, zamiast łatać skutki.
@MainActor
final class NowPlayingController {
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var isConfigured = false

    /// Wywoływane, gdy system/urządzenie zewnętrzne (blokada ekranu, słuchawki)
    /// żąda włączenia lub wyłączenia odtwarzania. Mapujemy to na odczyt steru.
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?

    func configureCommandsIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onToggle?()
            return .success
        }

        // Komendy nieużywane — wyłączone, by system nie pokazywał zbędnych przycisków.
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    /// Ogłasza systemowi, że trwa odtwarzanie (odczyt steru aktywny).
    func markPlaying() {
        configureCommandsIfNeeded()
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Odczyt steru"
        info[MPMediaItemPropertyArtist] = "BlueSeaEye"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        infoCenter.nowPlayingInfo = info
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .playing
        }
    }

    /// Ogłasza systemowi, że odtwarzanie ustało (odczyt wyłączony).
    func markStopped() {
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .stopped
        }
        infoCenter.nowPlayingInfo = nil
    }
}
