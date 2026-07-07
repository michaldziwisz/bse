import SwiftUI

@main
@MainActor
struct BSEApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var monitor: HelmMonitor

    init() {
        let settingsStore = SettingsStore()
        let audioSessionController = AudioSessionController()
        let notificationController = SafetyNotificationController()
        let nowPlayingController = NowPlayingController()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _monitor = StateObject(
            wrappedValue: HelmMonitor(
                settingsStore: settingsStore,
                audioSessionController: audioSessionController,
                notificationController: notificationController,
                nowPlayingController: nowPlayingController
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .environmentObject(monitor)
        }
    }
}
