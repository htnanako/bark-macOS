import Foundation

enum SettingsStore {
    private static let configurationKey = "me.fin.bark.macos.configuration"
    private static let notificationHistoryKey = "me.fin.bark.macos.notificationHistory"

    static func load() -> BarkServerConfiguration {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: configurationKey) else {
            return BarkServerConfiguration()
        }
        return (try? JSONDecoder().decode(BarkServerConfiguration.self, from: data)) ?? BarkServerConfiguration()
    }

    static func save(_ configuration: BarkServerConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        UserDefaults.standard.set(data, forKey: configurationKey)
    }

    static func loadNotificationHistory() -> [BarkNotificationRecord] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: notificationHistoryKey) else {
            return []
        }

        let history = (try? JSONDecoder().decode([BarkNotificationRecord].self, from: data)) ?? []
        return history.sorted { $0.receivedAt > $1.receivedAt }
    }

    static func saveNotificationHistory(_ history: [BarkNotificationRecord]) {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }
        UserDefaults.standard.set(data, forKey: notificationHistoryKey)
    }
}
