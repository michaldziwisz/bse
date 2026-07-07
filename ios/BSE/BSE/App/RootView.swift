import SwiftUI
import UIKit

/// Flagi funkcji aplikacji.
enum FeatureFlags {
    /// Akcje administracyjne (kalibracja / restart) są na razie ukryte: obecny
    /// firmware urządzenia BlueSeaEye zwraca dla nich HTTP 404. Ustaw `true`,
    /// gdy urządzenie zacznie je udostępniać.
    static let administrationEnabled = false
}

struct RootView: View {
    @EnvironmentObject private var monitor: HelmMonitor

    var body: some View {
        TabView {
            HelmDashboardView()
                .tabItem {
                    Label("Ster", systemImage: "safari")
                }

            SettingsView()
                .tabItem {
                    Label("Ustawienia", systemImage: "slider.horizontal.3")
                }

            if FeatureFlags.administrationEnabled {
                AdministrationView()
                    .tabItem {
                        Label("Administracja", systemImage: "wrench.and.screwdriver")
                    }
            }
        }
        .task {
            monitor.start()
            await monitor.prepareSafetyServices()
        }
        .onChange(of: monitor.isReadingEnabled) { isReadingEnabled in
            UIApplication.shared.isIdleTimerDisabled = isReadingEnabled
        }
    }
}
