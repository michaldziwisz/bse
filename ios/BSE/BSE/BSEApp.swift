import SwiftUI

@main
struct BSEApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var monitor: HelmMonitor

    init() {
        let settingsStore = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _monitor = StateObject(wrappedValue: HelmMonitor(settingsStore: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .environmentObject(monitor)
        }
    }
}
