import CryptoSwift
import Testing
@testable import BarkMac

struct PayloadResolverTests {
    @Test
    func resolvesMarkdownAndCompatibilityKeys() throws {
        let resolver = BarkPayloadResolver()

        let resolved = try resolver.resolve([
            "title": "Build Alert",
            "markdown": "# Heading\n\nBody line",
            "icon": "https://example.com/icon.png",
            "image": "https://example.com/hero.png",
            "sound": "bell",
            "call": "1",
            "automaticallycopy": "1",
            "isArchive": "0",
            "level": "timeSensitive",
            "url": "https://example.com",
            "copy": "OTP-123456",
        ])

        #expect(resolved.title == "Build Alert")
        #expect(resolved.bodyType == .markdown)
        #expect(resolved.body.contains("Heading"))
        #expect(resolved.body.contains("Body line"))
        #expect(resolved.isAutoCopy)
        #expect(resolved.isArchive == false)
        #expect(resolved.level == .timeSensitive)
        #expect(resolved.urlString == "https://example.com")
        #expect(resolved.iconURLString == "https://example.com/icon.png")
        #expect(resolved.imageURLString == "https://example.com/hero.png")
        #expect(resolved.copyText == "OTP-123456")
        #expect(resolved.soundName == "bell.caf")
        #expect(resolved.isCall)
    }

    @Test
    func resolvesDeleteAndDefaultArchiveBehavior() throws {
        let resolver = BarkPayloadResolver()

        let resolved = try resolver.resolve([
            "id": "remote-123",
            "delete": 1,
        ])

        #expect(resolved.remoteID == "remote-123")
        #expect(resolved.isDeleteCommand)
        #expect(resolved.isArchive)
    }

    @Test
    func resolvesCiphertextPayloadUsingConfiguredEncryption() throws {
        let encryption = BarkEncryptionConfiguration(
            algorithm: .aes128,
            mode: .cbc,
            key: "1234567890123456",
            iv: "1111111111111111"
        )
        let json = #"{"body":"secret body","title":"secret title","sound":"birdsong"}"#
        let aes = try AES(key: encryption.key.bytes, blockMode: CBC(iv: encryption.iv.bytes), padding: .pkcs7)
        let ciphertext = try aes.encrypt(Array(json.utf8)).toBase64()

        let resolver = BarkPayloadResolver(encryption: encryption)
        let resolved = try resolver.resolve([
            "ciphertext": ciphertext,
        ])

        #expect(resolved.title == "secret title")
        #expect(resolved.body == "secret body")
        #expect(resolved.soundName == "birdsong.caf")
    }

    @Test
    func normalizesCriticalVolumeAcrossSupportedRanges() throws {
        let resolver = BarkPayloadResolver()

        let half = try resolver.resolve([
            "level": "critical",
            "volume": "0.5",
        ])
        let five = try resolver.resolve([
            "level": "critical",
            "volume": "5",
        ])
        let ten = try resolver.resolve([
            "level": "critical",
            "volume": "10",
        ])
        let clamped = try resolver.resolve([
            "level": "critical",
            "volume": "99",
        ])

        #expect(half.volume == 0.5)
        #expect(five.volume == 0.5)
        #expect(ten.volume == 1.0)
        #expect(clamped.volume == 1.0)
    }
}
