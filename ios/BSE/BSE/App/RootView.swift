import SwiftUI
import UIKit

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

            AdministrationView()
                .tabItem {
                    Label("Administracja", systemImage: "wrench.and.screwdriver")
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
