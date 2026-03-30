import SwiftUI

struct AdministrationView: View {
    @EnvironmentObject private var monitor: HelmMonitor
    @State private var pendingAction: AdministrationAction?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Na podstawie danych z repo aplikacja wspiera także akcje administracyjne urządzenia. Testowy mock może tych endpointów nie udostępniać.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Akcje urządzenia") {
                    Button("Skalibruj żyroskop") {
                        pendingAction = .calibrate
                    }
                    .disabled(monitor.isBusy)

                    Button("Restartuj urządzenie", role: .destructive) {
                        pendingAction = .reboot
                    }
                    .disabled(monitor.isBusy)
                }

                Section("Status") {
                    if let message = monitor.adminMessage {
                        Text(message)
                    } else {
                        Text("Brak ostatniego komunikatu administracyjnego.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Administracja")
            .alert("Potwierdzenie", isPresented: alertIsPresented) {
                Button("Anuluj", role: .cancel) {
                    pendingAction = nil
                }
                Button(confirmButtonTitle, role: pendingAction == .reboot ? .destructive : nil) {
                    guard let pendingAction else { return }
                    Task {
                        await monitor.runAdministrationAction(pendingAction)
                        self.pendingAction = nil
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { pendingAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingAction = nil
                }
            }
        )
    }

    private var confirmButtonTitle: String {
        switch pendingAction {
        case .calibrate:
            return "Uruchom kalibrację"
        case .reboot:
            return "Restartuj"
        case nil:
            return "OK"
        }
    }

    private var alertMessage: String {
        switch pendingAction {
        case .calibrate:
            return "Kalibracja może chwilowo zatrzymać odczyty. Kontynuować?"
        case .reboot:
            return "Urządzenie zostanie zrestartowane. Kontynuować?"
        case nil:
            return ""
        }
    }
}
