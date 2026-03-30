import Foundation
import UserNotifications

enum BarkNotificationComposer {
    static func makeContent(
        from notification: BarkResolvedNotification,
        includeSystemSound: Bool = true,
        attachments: [UNNotificationAttachment] = []
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notification.title.isEmpty ? "Bark" : notification.title
        content.subtitle = notification.subtitle
        content.body = notification.body
        content.categoryIdentifier = BarkNotificationCategory.identifier
        content.userInfo = notification.actionContext.userInfo
        content.attachments = attachments

        switch notification.level {
        case .active:
            content.interruptionLevel = .active
        case .passive:
            content.interruptionLevel = .passive
        case .timeSensitive:
            content.interruptionLevel = .timeSensitive
        case .critical:
            content.interruptionLevel = .critical
        }

        if includeSystemSound {
            applySound(to: content, from: notification)
        }
        return content
    }

    private static func applySound(to content: UNMutableNotificationContent, from notification: BarkResolvedNotification) {
        let soundName = BarkSoundLibrary.normalizedSoundName(notification.soundName)
        switch notification.level {
        case .critical:
            let volume = max(0.0, min(1.0, notification.volume ?? 0.5))
            if let soundName, !soundName.isEmpty {
                content.sound = .criticalSoundNamed(UNNotificationSoundName(rawValue: soundName), withAudioVolume: Float(volume))
            } else {
                content.sound = .defaultCriticalSound(withAudioVolume: Float(volume))
            }
        default:
            if let soundName, !soundName.isEmpty {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            } else {
                content.sound = .default
            }
        }
    }
}
