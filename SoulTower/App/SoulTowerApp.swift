import SwiftUI
import SwiftData
import UserNotifications

@main
struct SoulTowerApp: App {
    private let container = AppModelContainer.shared
    @StateObject private var appState = AppState()
    @StateObject private var securityManager = AppSecurityManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isLockEnabled && !securityManager.isUnlocked && !AppModelContainer.usesTemporaryTestStore {
                    AppLockView()
                } else {
                    RootView()
                }
            }
                .environmentObject(appState)
                .environmentObject(securityManager)
                .task {
                    UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
                    do {
                        #if DEBUG
                        if AppModelContainer.usesTemporaryTestStore {
                            appState.migrationStatus = "V\(AppMigrationService.currentVersion)，临时界面测试数据"
                            try SeedService.seedServiceCatalogIfNeeded(context: container.mainContext)
                            if ProcessInfo.processInfo.arguments.contains("--ui-testing-v06") {
                                try SeedService.insertV06UITestData(context: container.mainContext)
                            }
                            if ProcessInfo.processInfo.arguments.contains("--ui-testing-v07") {
                                try SeedService.insertV07UITestData(context: container.mainContext)
                            }
                        } else {
                            appState.migrationStatus = try AppMigrationService.run(context: container.mainContext)
                            try SeedService.seedServiceCatalogIfNeeded(context: container.mainContext)
                        }
                        #else
                        appState.migrationStatus = try AppMigrationService.run(context: container.mainContext)
                        try SeedService.seedServiceCatalogIfNeeded(context: container.mainContext)
                        #endif
                    } catch {
                        appState.migrationStatus = "数据升级失败：\(error.localizedDescription)"
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        securityManager.lock()
                    }
                }
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            Group {
                if securityManager.isLockEnabled && !securityManager.isUnlocked && !AppModelContainer.usesTemporaryTestStore {
                    AppLockView()
                } else {
                    SettingsView()
                }
            }
            .environmentObject(appState)
            .environmentObject(securityManager)
            .modelContainer(container)
            .frame(minWidth: 680, minHeight: 560)
        }
        #endif
    }
}
