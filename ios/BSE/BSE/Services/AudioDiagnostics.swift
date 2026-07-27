import Foundation

/// Liczniki diagnostyczne odtwarzania sygnałów dźwiękowych. Cel: TWARDO zmierzyć,
/// dlaczego próbka odchyłki „czasem gra, czasem nie” — zamiast zgadywać. Wszystkie
/// ścieżki audio (SamplePlayer, HelmMonitor, widok) są @MainActor, więc trzymamy
/// proste statyczne pola bez blokad. Odczyt prezentuje panel „Diagnostyka dźwięku”
/// w Ustawieniach (dostępny VoiceOverem) — użytkownik po sesji odsłuchu czyta,
/// która ścieżka rośnie, i to wskazuje przyczynę.
@MainActor
enum AudioDiagnostics {
    // Ile razy HelmMonitor faktycznie zażądał zagrania sygnału (wszedł w gałąź
    // odtwarzania po wszystkich warunkach).
    static var requested = 0
    // Ile żądań sygnału POMINIĘTO, bo poprzednie odtwarzanie było jeszcze w toku
    // (isSignalInProgress). Wysoka wartość = sygnały nakładają się szybciej niż
    // zdąży ruszyć odtwarzacz.
    static var skippedInProgress = 0
    // Ile żądań odpadło na warunkach (brak wartości, poniżej progu, tryb) — to
    // normalne, ale pomaga odróżnić „nie miało grać” od „miało, a nie zagrało”.
    static var skippedByGuard = 0

    // Ścieżki w samym SamplePlayer.play:
    static var attempted = 0          // wywołań SamplePlayer.play
    static var missingResource = 0    // brak pliku WAV w bundlu
    static var prepareFailed = 0      // prepareForPlayback rzucił
    static var initFailed = 0         // AVAudioPlayer(data:) rzucił
    static var playReturnedFalse = 0  // player.play() zwrócił false (nie ruszył)
    static var succeeded = 0          // play() zwrócił true

    static var lastEvent = "—"        // ostatnie zdarzenie z opisem

    // Rozbicie per sygnał — KLUCZOWE dla „na kursie cisza”: pokazuje, czy gałąź
    // center jest w ogóle wywoływana, czy zawsze leci left/right (kurs drga, więc
    // delta rzadko = 0). Plus kontekst decyzji z HelmMonitor.playSignal.
    static var playedCenter = 0
    static var playedLeft = 0
    static var playedRight = 0
    static var lastMode = "—"          // tryb odczytu (target)
    static var lastToneOnCourse = "—"  // stan ustawienia „ton na zadanym kursie”
    static var lastDelta = "—"         // ostatnia policzona odchyłka

    static func reset() {
        requested = 0; skippedInProgress = 0; skippedByGuard = 0
        attempted = 0; missingResource = 0; prepareFailed = 0
        initFailed = 0; playReturnedFalse = 0
        succeeded = 0; lastEvent = "—"
        playedCenter = 0; playedLeft = 0; playedRight = 0
        lastMode = "—"; lastToneOnCourse = "—"; lastDelta = "—"
    }

    /// Wielolinijkowy, czytelny raport dla panelu diagnostycznego.
    static func report() -> String {
        """
        Zażądano sygnałów: \(requested)
        Pominięto (poprzedni w toku): \(skippedInProgress)
        Pominięto (warunki): \(skippedByGuard)
        Prób odtworzenia: \(attempted)
        Odtworzono poprawnie: \(succeeded)
        Zagrano na kursie (center): \(playedCenter)
        Zagrano lewiej (left): \(playedLeft)
        Zagrano prawiej (right): \(playedRight)
        Tryb odczytu: \(lastMode)
        Ton na kursie włączony: \(lastToneOnCourse)
        Ostatnia odchyłka: \(lastDelta)
        Brak pliku próbki: \(missingResource)
        Błąd sesji audio: \(prepareFailed)
        Błąd utworzenia odtwarzacza: \(initFailed)
        play() nie ruszył: \(playReturnedFalse)
        Ostatnie zdarzenie: \(lastEvent)
        """
    }
}
