import Foundation
import Testing
@testable import BarkMac

@MainActor
struct AlertPlaybackCoordinatorTests {
    @Test
    func passiveNotificationsStaySilentEvenWithCustomSound() {
        let harness = PlaybackHarness()
        let coordinator = harness.makeCoordinator()
        let notification = BarkResolvedNotification(
            eventID: "evt-passive",
            remoteID: "passive-1",
            title: "Passive",
            subtitle: "",
            body: "Quiet",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .passive,
            volume: nil,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        #expect(coordinator.shouldUseSystemNotificationSound(for: notification) == false)
        coordinator.play(for: notification)
        #expect(harness.createdSounds.isEmpty)
    }

    @Test
    func criticalCustomSoundUsesNormalizedVolumeForManualPlayback() {
        let harness = PlaybackHarness()
        let coordinator = harness.makeCoordinator()
        let notification = BarkResolvedNotification(
            eventID: "evt-critical",
            remoteID: "critical-1",
            title: "Critical",
            subtitle: "",
            body: "Loud",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .critical,
            volume: 0.5,
            isCall: false,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        #expect(coordinator.shouldUseSystemNotificationSound(for: notification) == false)
        coordinator.play(for: notification)

        #expect(harness.createdSounds.count == 1)
        #expect(harness.createdSounds.first?.volume == 0.5)
        #expect(harness.createdSounds.first?.playCount == 1)
    }

    @Test
    func callPlaybackRepeatsUntilTimeout() async {
        let harness = PlaybackHarness()
        let coordinator = harness.makeCoordinator(maxCallDuration: 0.03)
        let notification = BarkResolvedNotification(
            eventID: "evt-call",
            remoteID: "call-1",
            title: "Call",
            subtitle: "",
            body: "Repeat",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .active,
            volume: nil,
            isCall: true,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        coordinator.play(for: notification)
        for _ in 0..<20 {
            await Task.yield()
        }

        #expect(harness.createdSounds.count >= 2)
    }

    @Test
    func newCallInterruptsPreviousAndDeleteStopsCurrentCall() async {
        let harness = PlaybackHarness()
        let coordinator = harness.makeCoordinator(maxCallDuration: 0.3)
        let first = BarkResolvedNotification(
            eventID: "evt-call-1",
            remoteID: "call-1",
            title: "First",
            subtitle: "",
            body: "First",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: "chime.caf",
            level: .active,
            volume: nil,
            isCall: true,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )
        let second = BarkResolvedNotification(
            eventID: "evt-call-2",
            remoteID: "call-2",
            title: "Second",
            subtitle: "",
            body: "Second",
            bodyType: .plainText,
            group: nil,
            urlString: nil,
            copyText: nil,
            soundName: "bell.caf",
            level: .active,
            volume: nil,
            isCall: true,
            isAutoCopy: false,
            isArchive: true,
            isDeleteCommand: false,
            rawPayload: "{}",
            resolvedPayload: [:],
            receivedAt: .now
        )

        coordinator.play(for: first)
        await Task.yield()
        coordinator.play(for: second)
        await Task.yield()

        let firstSound = harness.createdSounds.first { $0.url.lastPathComponent == "chime.caf" }
        #expect(firstSound?.stopCount ?? 0 >= 1)

        coordinator.stopPlayback(forRemoteID: "call-2")
        await Task.yield()

        let secondSound = harness.createdSounds.first { $0.url.lastPathComponent == "bell.caf" }
        #expect(secondSound?.stopCount ?? 0 >= 1)
    }
}

private final class PlaybackHarness: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 0)
    var createdSounds: [TestSound] = []

    @MainActor
    func makeCoordinator(maxCallDuration: TimeInterval = 30) -> BarkAlertPlaybackCoordinator {
        BarkAlertPlaybackCoordinator(
            soundURLResolver: { rawName in
                let name = BarkSoundLibrary.normalizedSoundName(rawName) ?? "unknown.caf"
                return URL(fileURLWithPath: "/tmp/\(name)")
            },
            soundFactory: { [weak self] url in
                guard let self else { return nil }
                let sound = TestSound(url: url, duration: 0.01)
                self.createdSounds.append(sound)
                return sound
            },
            timeProvider: { [weak self] in
                self?.now ?? Date(timeIntervalSince1970: 0)
            },
            sleepHandler: { [weak self] delay in
                guard let self else { return }
                self.now = self.now.addingTimeInterval(delay)
                await Task.yield()
            },
            maxCallDuration: maxCallDuration
        )
    }
}

private final class TestSound: BarkPlayableSound {
    let url: URL
    let duration: TimeInterval
    var volume: Float = 1.0
    var playCount = 0
    var stopCount = 0

    init(url: URL, duration: TimeInterval) {
        self.url = url
        self.duration = duration
    }

    func play() -> Bool {
        playCount += 1
        return true
    }

    func stop() {
        stopCount += 1
    }
}
