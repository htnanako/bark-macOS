import Foundation
import Testing
@testable import BarkMac

struct NotificationBehaviorTests {
    @Test
    func composerWritesActionContextAndInterruptionLevel() {
        let resolved = BarkResolvedNotification(
            eventID: "evt-1",
            remoteID: "remote-1",
            title: "Alert",
            subtitle: "CI",
            body: "Build failed",
            bodyType: .plainText,
            group: "builds",
            urlString: "https://example.com/logs",
            copyText: "Build failed",
            soundName: "minuet.caf",
            level: .timeSensitive,
            volume: nil,
            isCall: true,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        let content = BarkNotificationComposer.makeContent(from: resolved)

        #expect(content.categoryIdentifier == BarkNotificationCategory.identifier)
        #expect(content.interruptionLevel == .timeSensitive)
        #expect(content.userInfo[BarkNotificationUserInfoKeys.url] as? String == "https://example.com/logs")
        #expect(content.userInfo[BarkNotificationUserInfoKeys.copyText] as? String == "Build failed")
        #expect(content.userInfo[BarkNotificationUserInfoKeys.remoteID] as? String == "remote-1")
        #expect(content.userInfo[BarkNotificationUserInfoKeys.level] as? String == BarkNotificationLevel.timeSensitive.rawValue)
        #expect(content.userInfo[BarkNotificationUserInfoKeys.isCall] as? Bool == true)
    }

    @Test
    @MainActor
    func archiveDisabledSkipsHistoryButKeepsBehaviorPure() async {
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [],
            pasteboardWriter: { _ in },
            urlOpener: { _ in },
            restoreSessionOnInit: false
        )
        let resolved = BarkResolvedNotification(
            eventID: "evt-2",
            remoteID: "remote-2",
            title: "Title",
            subtitle: "",
            body: "Body",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: nil,
            level: .active,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: false,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        await model.applyResolvedNotification(resolved, shouldDeliverNotification: false, shouldPerformAutoCopy: false)

        #expect(model.notificationHistory.isEmpty)
    }

    @Test
    @MainActor
    func deleteCommandRemovesExistingHistoryRecord() async {
        let initial = BarkNotificationRecord(
            remoteID: "remote-3",
            title: "Title",
            body: "Body",
            rawPayload: "{}"
        )
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [initial],
            pasteboardWriter: { _ in },
            urlOpener: { _ in },
            restoreSessionOnInit: false
        )
        let resolved = BarkResolvedNotification(
            eventID: "evt-3",
            remoteID: "remote-3",
            title: "",
            subtitle: "",
            body: "",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: nil,
            level: .active,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: true,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        await model.applyResolvedNotification(resolved, shouldDeliverNotification: false, shouldPerformAutoCopy: false)

        #expect(model.notificationHistory.isEmpty)
    }

    @Test
    @MainActor
    func clearHistoryOlderThanRemovesOnlyExpiredRecords() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let recent = BarkNotificationRecord(
            receivedAt: now.addingTimeInterval(-60 * 60),
            remoteID: "recent",
            title: "Recent",
            body: "Keep",
            rawPayload: "{}"
        )
        let old = BarkNotificationRecord(
            receivedAt: now.addingTimeInterval(-60 * 60 * 24 * 10),
            remoteID: "old",
            title: "Old",
            body: "Remove",
            rawPayload: "{}"
        )
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [recent, old],
            pasteboardWriter: { _ in },
            urlOpener: { _ in },
            restoreSessionOnInit: false
        )

        model.clearNotificationHistory(olderThan: 60 * 60 * 24 * 7, now: now)

        #expect(model.notificationHistory.count == 1)
        #expect(model.notificationHistory.first?.remoteID == "recent")
    }

    @Test
    @MainActor
    func importHistoryMergesByRemoteIDAndKeepsNewestOrder() throws {
        let existing = BarkNotificationRecord(
            receivedAt: Date(timeIntervalSince1970: 100),
            remoteID: "same",
            title: "Older",
            body: "Old body",
            rawPayload: "{}"
        )
        let importedNewer = BarkNotificationRecord(
            receivedAt: Date(timeIntervalSince1970: 200),
            remoteID: "same",
            title: "Newer",
            body: "New body",
            rawPayload: "{}"
        )
        let importedUnique = BarkNotificationRecord(
            receivedAt: Date(timeIntervalSince1970: 150),
            remoteID: "unique",
            title: "Unique",
            body: "Unique body",
            rawPayload: "{}"
        )
        let data = try JSONEncoder().encode([importedNewer, importedUnique])
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [existing],
            pasteboardWriter: { _ in },
            urlOpener: { _ in },
            restoreSessionOnInit: false
        )

        let importedCount = try model.importNotificationHistory(from: data)

        #expect(importedCount == 2)
        #expect(model.notificationHistory.count == 2)
        #expect(model.notificationHistory.first?.title == "Newer")
        #expect(model.notificationHistory.map(\.remoteID) == ["same", "unique"])
    }

    @Test
    @MainActor
    func notificationActionsCopyAndOpen() {
        var copiedText = ""
        var openedURL: URL?
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [],
            pasteboardWriter: { copiedText = $0 },
            urlOpener: { openedURL = $0 },
            restoreSessionOnInit: false
        )
        let context = BarkNotificationActionContext(
            remoteID: "remote-4",
            urlString: "https://example.com/path",
            copyText: "OTP",
            level: .active,
            isCall: false,
            title: "T",
            subtitle: "S",
            body: "B"
        )

        let copyNeedsWindow = model.handleNotificationAction(
            actionIdentifier: BarkNotificationCategory.copyAction,
            context: context
        )
        #expect(copyNeedsWindow == false)
        #expect(copiedText == "OTP")

        let openNeedsWindow = model.handleNotificationAction(
            actionIdentifier: BarkNotificationCategory.openAction,
            context: context
        )
        #expect(openNeedsWindow == false)
        #expect(openedURL?.absoluteString == "https://example.com/path")

        let fallbackNeedsWindow = model.handleNotificationAction(
            actionIdentifier: BarkNotificationCategory.openAction,
            context: BarkNotificationActionContext(
                remoteID: nil,
                urlString: nil,
                copyText: nil,
                level: .active,
                isCall: false,
                title: "Only local",
                subtitle: "",
                body: ""
            )
        )
        #expect(fallbackNeedsWindow)
        #expect(model.configuration.selectedTab == .records)
    }

    @Test
    @MainActor
    func foregroundPresentationOptionsRespectPassiveAndCustomSoundRules() {
        let model = AppModel(
            configuration: BarkServerConfiguration(),
            notificationHistory: [],
            pasteboardWriter: { _ in },
            urlOpener: { _ in },
            restoreSessionOnInit: false
        )

        let passive = BarkNotificationActionContext(
            remoteID: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .passive,
            isCall: false,
            title: "Passive",
            subtitle: "",
            body: ""
        )
        let customSound = BarkNotificationActionContext(
            remoteID: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .active,
            isCall: false,
            title: "Active",
            subtitle: "",
            body: ""
        )
        let defaultSound = BarkNotificationActionContext(
            remoteID: nil,
            urlString: nil,
            copyText: nil,
            soundName: nil,
            level: .active,
            isCall: false,
            title: "Default",
            subtitle: "",
            body: ""
        )

        #expect(model.foregroundPresentationOptions(for: passive.userInfo) == [.list])
        #expect(model.foregroundPresentationOptions(for: customSound.userInfo) == [.banner, .list])
        #expect(model.foregroundPresentationOptions(for: defaultSound.userInfo) == [.banner, .list, .sound])
    }
}
