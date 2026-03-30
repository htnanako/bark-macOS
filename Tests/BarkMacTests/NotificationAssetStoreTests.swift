import Foundation
import Testing
import UserNotifications
import CryptoSwift
@testable import BarkMac

struct NotificationAssetStoreTests {
    @Test
    func prefersImageAttachmentAndFallsBackToIcon() {
        let imageFirst = BarkResolvedNotification(
            eventID: "evt-image",
            remoteID: "remote-image",
            title: "Image",
            subtitle: "",
            body: "Body",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            iconURLString: "https://example.com/icon.png",
            imageURLString: "https://example.com/hero.png",
            copyText: nil,
            soundName: nil,
            level: .active,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )
        let iconOnly = BarkResolvedNotification(
            eventID: "evt-icon",
            remoteID: "remote-icon",
            title: "Icon",
            subtitle: "",
            body: "Body",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            iconURLString: "https://example.com/icon.png",
            imageURLString: nil,
            copyText: nil,
            soundName: nil,
            level: .active,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        #expect(BarkNotificationAssetStore.assetDescriptors(for: imageFirst) == [
            BarkNotificationAssetDescriptor(identifier: "image", urlString: "https://example.com/hero.png"),
        ])
        #expect(BarkNotificationAssetStore.assetDescriptors(for: iconOnly) == [
            BarkNotificationAssetDescriptor(identifier: "icon", urlString: "https://example.com/icon.png"),
        ])
    }

    @Test
    func composerCarriesNotificationAttachments() throws {
        let imageURL = try Self.makeTinyPNG()
        let attachment = try UNNotificationAttachment(identifier: "icon", url: imageURL)
        let notification = BarkResolvedNotification(
            eventID: "evt-attachment",
            remoteID: "remote-attachment",
            title: "Attachment",
            subtitle: "",
            body: "Body",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            iconURLString: imageURL.absoluteString,
            imageURLString: nil,
            copyText: nil,
            soundName: nil,
            level: .active,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        let content = BarkNotificationComposer.makeContent(from: notification, attachments: [attachment])

        #expect(content.attachments.count == 1)
        #expect(content.attachments.first?.identifier == "icon")
    }

    @Test
    func cachedAssetURLFindsExistingHashedFileWithoutRedownloading() throws {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BarkNotificationAssets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let urlString = "https://example.com/static-icon.png"
        let hash = urlString.bytes.sha256().toHexString()
        let cachedURL = directory.appendingPathComponent("icon-\(hash).png")
        let data = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9s7fVhQAAAAASUVORK5CYII="))
        try data.write(to: cachedURL, options: .atomic)

        let resolved = BarkNotificationAssetStore.cachedAssetURL(
            iconURLString: urlString,
            imageURLString: nil
        )

        #expect(resolved == cachedURL)
    }

    private static func makeTinyPNG() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BarkMacTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("tiny-\(UUID().uuidString).png")
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9s7fVhQAAAAASUVORK5CYII="
        let data = try #require(Data(base64Encoded: base64))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
