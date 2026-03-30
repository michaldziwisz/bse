import SwiftUI

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
        }
    }
}
