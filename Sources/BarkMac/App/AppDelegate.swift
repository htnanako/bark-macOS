import AppKit
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    weak var model: AppModel?

    func attach(model: AppModel) {
        self.model = model
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        _ = userInfo
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let options = model?.foregroundPresentationOptions(for: notification.request.content.userInfo) ?? [.banner, .list, .sound]
        completionHandler(options)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let shouldShowMainWindow = model?.handleNotificationResponse(response) ?? false
        if shouldShowMainWindow {
            showMainWindow()
        }
        completionHandler()
    }

    private func registerNotificationCategories() {
        let copyAction = UNNotificationAction(
            identifier: BarkNotificationCategory.copyAction,
            title: "复制",
            options: []
        )
        let openAction = UNNotificationAction(
            identifier: BarkNotificationCategory.openAction,
            title: "打开",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: BarkNotificationCategory.identifier,
            actions: [copyAction, openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @MainActor
    @objc
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor
    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }
}
