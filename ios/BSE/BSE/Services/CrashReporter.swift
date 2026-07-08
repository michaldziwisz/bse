import Foundation

/// Diagnostyka przyczyny zakończenia aplikacji. Zapisuje do pliku powód
/// nieoczekiwanego zamknięcia — nieprzechwycony wyjątek Objective-C albo sygnał
/// systemowy (np. SIGABRT, SIGSEGV towarzyszące crashowi) — a przy następnym
/// uruchomieniu udostępnia ten powód, aby aplikacja mogła go ODCZYTAĆ GŁOSEM.
/// Dzięki temu, zamiast zgadywać, dlaczego aplikacja „wywala się” po godzinach,
/// mamy twardy dowód prosto z urządzenia Michała.
enum CrashReporter {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bse-last-crash.txt")
    }()

    /// Instaluje przechwytywanie wyjątków i sygnałów. Wołać RAZ, jak najwcześniej.
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let reason = exception.reason ?? "brak opisu"
            let name = exception.name.rawValue
            let stack = exception.callStackSymbols.prefix(8).joined(separator: " | ")
            CrashReporter.write("Wyjątek: \(name) — \(reason). Ślad: \(stack)")
        }

        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(sig) { received in
                // Ślad stosu wskazuje DOKŁADNIE funkcję, w której nastąpił crash —
                // kluczowe przy SIGSEGV (błąd pamięci wewnątrz frameworków audio).
                let stack = Thread.callStackSymbols.prefix(14).joined(separator: "\n")
                CrashReporter.write("Sygnał systemowy nr \(received).\nŚlad stosu:\n\(stack)")
                // Przywróć domyślną obsługę i pozwól procesowi zakończyć się,
                // by nie maskować crasha.
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    /// Odczytuje i USUWA zapisany powód ostatniego zamknięcia (jeśli był).
    static func consumeLastCrashReason() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        try? FileManager.default.removeItem(at: fileURL)
        return text
    }

    /// Zapis z sygnału/handlera musi być minimalny i async-signal-safe na tyle,
    /// na ile to możliwe — używamy niskopoziomowego zapisu deskryptorem pliku.
    private static func write(_ message: String) {
        let full = "[\(Self.timestamp())] \(message)"
        guard let data = full.data(using: .utf8) else { return }
        let path = fileURL.path
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                _ = Foundation.write(fd, base, raw.count)
            }
        }
        close(fd)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date())
    }
}
