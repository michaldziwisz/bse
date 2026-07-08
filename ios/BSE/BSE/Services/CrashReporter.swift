import Foundation
import MachO

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
            let stack = exception.callStackSymbols.prefix(20).joined(separator: "\n")
            CrashReporter.write("Wyjątek: \(name) — \(reason).\n\(CrashReporter.imageInfo())\nOstatnie zdarzenia:\n\(CrashReporter.breadcrumbsSnapshot())\nŚlad stosu:\n\(stack)")
        }

        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(sig) { received in
                // Pełny ślad + adres bazowy obrazu = możliwość offline symbolizacji
                // z dSYM (atos). Bez adresu bazowego same adresy z callStackSymbols
                // są bezużyteczne po restarcie (ASLR). Breadcrumbs pokazują CO
                // aplikacja robiła tuż przed awarią — kluczowe gdy stos to same
                // ramki systemowe bez naszego kodu.
                let stack = Thread.callStackSymbols.prefix(24).joined(separator: "\n")
                CrashReporter.write("Sygnał systemowy nr \(received).\n\(CrashReporter.imageInfo())\nOstatnie zdarzenia:\n\(CrashReporter.breadcrumbsSnapshot())\nŚlad stosu:\n\(stack)")
                // Przywróć domyślną obsługę i pozwól procesowi zakończyć się,
                // by nie maskować crasha.
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    /// Adres załadowania i slide ASLR głównego obrazu (BSE) oraz wersja — bez tego
    /// nie da się przeliczyć adresów ze śladu na linie kodu przy użyciu dSYM.
    private static func imageInfo() -> String {
        var info = "Obraz: nieznany"
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let namePtr = _dyld_get_image_name(i) else { continue }
            let name = String(cString: namePtr)
            if name.hasSuffix("/BSE") || name.hasSuffix(".app/BSE") {
                let slide = _dyld_get_image_vmaddr_slide(i)
                let base = _dyld_get_image_header(i)
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                info = "Obraz BSE: base=\(base) slide=0x\(String(slide, radix: 16)) wersja=\(version) (\(build))"
                break
            }
        }
        return info
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

    // MARK: - Breadcrumbs (ślad ostatnich zdarzeń przed crashem)

    /// Pierścieniowy bufor ostatnich zdarzeń. Po crashu dołączany do raportu, by
    /// pokazać CO aplikacja robiła w chwili awarii — nawet gdy stos zawiera tylko
    /// ramki systemowe (Foundation) bez naszego kodu. To jedyny pewny sposób, by
    /// namierzyć nieregularny crash na wątku głównym.
    private static let breadcrumbLock = NSLock()
    private static var breadcrumbs: [String] = []
    private static let maxBreadcrumbs = 40

    static func breadcrumb(_ event: String) {
        let line = "\(shortTimestamp()) \(event)"
        breadcrumbLock.lock()
        breadcrumbs.append(line)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst(breadcrumbs.count - maxBreadcrumbs)
        }
        breadcrumbLock.unlock()
    }

    private static func breadcrumbsSnapshot() -> String {
        breadcrumbLock.lock()
        let copy = breadcrumbs
        breadcrumbLock.unlock()
        guard !copy.isEmpty else { return "Brak zapisanych zdarzeń." }
        return copy.joined(separator: "\n")
    }

    private static func shortTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
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
