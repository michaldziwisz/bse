import AVFoundation
import Foundation

/// Odtwarzacz sygnałów odchyłki oparty o GOTOWE próbki dźwiękowe (te same
/// nagrania co w wersji Android: wariant1 → 0/l1/r1), zamiast syntezowanego tonu.
///
/// Trzy sygnały:
///  - ``Signal/center`` (sig_center) — na kursie,
///  - ``Signal/left``   (sig_left)   — odchyłka w lewo („lewiej”),
///  - ``Signal/right``  (sig_right)  — odchyłka w prawo („prawiej”).
///
/// Wysokość dźwięku rośnie wraz z wielkością odchyłki — dokładnie tak, jak
/// wcześniej robił to generator tonów, i tak jak robi to teraz Android. Na
/// Androidzie podniesienie wysokości BEZ zmiany długości realizuje systemowy
/// time-stretch (Sonic). iOS jego odpowiednik (AVAudioUnitTimePitch) wymaga
/// AVAudioEngine, który w tej aplikacji był udokumentowanym źródłem twardych
/// crashy po godzinach pracy (rzuca niełapalny wyjątek Objective-C). Dlatego
/// wysokości NIE zmieniamy w czasie działania: warianty półtonowe (0–24) są
/// wyrenderowane OFFLINE z zachowaniem długości i dołączone do aplikacji jako
/// osobne pliki WAV. W runtime gramy gotowy plik zwykłym, odpornym
/// ``AVAudioPlayer`` — zero AVAudioEngine, brzmienie 1:1 z Androidem.
///
/// Panorama: mono próbka trafia do obu kanałów, a ``AVAudioPlayer/pan``
/// przesuwa ją w bok (−1 = lewo, +1 = prawo). Dzięki temu z podłączonymi obiema
/// słuchawkami sygnał „lewy” słychać bardziej po lewej, a „prawy” po prawej.
@MainActor
final class SamplePlayer {
    enum Signal {
        case center
        case left
        case right
    }

    /// Najwyższy dostępny wariant półtonowy (pliki sig_left_00…sig_left_24).
    /// Zgodne z zakresem wysokości z Androida: pitchRatio jest tam docinany do
    /// 4.0, co odpowiada 24 półtonom (dwie oktawy).
    private static let maxSemitone = 24

    private let audioSessionController: AudioSessionController
    private var activePlayer: AVAudioPlayer?
    /// Zdekodowane dane WAV trzymamy w pamięci po pierwszym użyciu — próbek jest
    /// mało i są krótkie, a to eliminuje dostęp do dysku na gorącej ścieżce.
    private var cache: [String: Data] = [:]

    init(audioSessionController: AudioSessionController) {
        self.audioSessionController = audioSessionController
    }

    func stop() {
        activePlayer?.stop()
        activePlayer = nil
    }

    /// Odtwarza sygnał [signal] z wysokością odpowiadającą [semitone] półtonom
    /// w górę (0 = naturalna wysokość próbki), głośnością [volume] (0…1) oraz
    /// panoramą [pan] (−1 = lewo, 0 = środek, +1 = prawo).
    func play(signal: Signal, semitone: Int, volume: Double, pan: Double) async {
        AudioDiagnostics.attempted += 1
        let name = resourceName(for: signal, semitone: semitone)
        guard let data = loadData(named: name) else {
            AudioDiagnostics.missingResource += 1
            AudioDiagnostics.lastEvent = "brak zasobu \(name)"
            CrashReporter.breadcrumb("sample: brak zasobu \(name)")
            return
        }
        do {
            try audioSessionController.prepareForPlayback()
        } catch {
            AudioDiagnostics.prepareFailed += 1
            AudioDiagnostics.lastEvent = "błąd sesji: \(error.localizedDescription)"
            return
        }
        stop()

        CrashReporter.breadcrumb("sample: play \(name) pan \(String(format: "%.2f", pan))")
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = Float(min(max(volume, 0), 1))
            player.pan = Float(min(max(pan, -1), 1))
            player.prepareToPlay()
            guard player.play() else {
                AudioDiagnostics.playReturnedFalse += 1
                AudioDiagnostics.lastEvent = "play() zwrócił false: \(name)"
                return
            }
            AudioDiagnostics.succeeded += 1
            AudioDiagnostics.lastEvent = "OK \(name) pan \(String(format: "%.2f", pan))"
            activePlayer = player
            // NIE zwalniamy odtwarzacza z opóźnionego Taska (patrz TonePlayer):
            // zwolnienie AVAudioPlayer, gdy jego wewnętrzny timer jest jeszcze
            // zaplanowany na głównej pętli, powodowało SIGSEGV. Odtwarzacz gra
            // swój krótki bufor i zostaje zwolniony przy następnym play()/stop().
        } catch {
            AudioDiagnostics.initFailed += 1
            AudioDiagnostics.lastEvent = "błąd odtwarzacza: \(error.localizedDescription)"
            return
        }
    }

    // MARK: - Zasoby

    /// Nazwa pliku dla sygnału i wysokości. Środek ma tylko jeden wariant
    /// (naturalna wysokość); lewo/prawo mają warianty półtonowe 00…24.
    private func resourceName(for signal: Signal, semitone: Int) -> String {
        switch signal {
        case .center:
            return "sig_center"
        case .left, .right:
            let side = signal == .left ? "left" : "right"
            let clamped = min(max(semitone, 0), Self.maxSemitone)
            return String(format: "sig_%@_%02d", side, clamped)
        }
    }

    private func loadData(named name: String) -> Data? {
        if let cached = cache[name] {
            return cached
        }
        // Zasoby mogą trafić do katalogu „Signals” (folder reference) albo do
        // korzenia paczki (grupa) — szukamy w obu miejscach, żeby być odpornym
        // na sposób spakowania przez xcodegen.
        let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Signals")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url, let data = try? Data(contentsOf: url) else {
            return nil
        }
        cache[name] = data
        return data
    }
}
