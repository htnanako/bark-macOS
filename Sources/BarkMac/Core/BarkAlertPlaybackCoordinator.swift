import AppKit
import Foundation

protocol BarkPlayableSound: AnyObject {
    var duration: TimeInterval { get }
    var volume: Float { get set }
    func play() -> Bool
    func stop()
}

final class BarkNSSoundAdapter: BarkPlayableSound {
    private let sound: NSSound

    init(sound: NSSound) {
        self.sound = sound
    }

    var duration: TimeInterval {
        sound.duration
    }

    var volume: Float {
        get { sound.volume }
        set { sound.volume = newValue }
    }

    func play() -> Bool {
        sound.play()
    }

    func stop() {
        sound.stop()
    }
}

@MainActor
protocol BarkAlertPlaybackCoordinating: AnyObject {
    func shouldUseSystemNotificationSound(for notification: BarkResolvedNotification) -> Bool
    func play(for notification: BarkResolvedNotification)
    func stopPlayback(forRemoteID remoteID: String)
}

@MainActor
final class BarkAlertPlaybackCoordinator: BarkAlertPlaybackCoordinating {
    typealias SoundURLResolver = @MainActor (String?) -> URL?
    typealias SoundFactory = @MainActor (URL) -> BarkPlayableSound?
    typealias TimeProvider = @MainActor () -> Date
    typealias SleepHandler = @Sendable (TimeInterval) async -> Void

    private let soundURLResolver: SoundURLResolver
    private let soundFactory: SoundFactory
    private let timeProvider: TimeProvider
    private let sleepHandler: SleepHandler
    private let maxCallDuration: TimeInterval
    private var retainedSounds: [UUID: BarkPlayableSound] = [:]
    private var activeCallTask: Task<Void, Never>?
    private var activeCallRemoteID: String?
    private var activeCallSound: BarkPlayableSound?

    init(
        soundURLResolver: @escaping SoundURLResolver = BarkSoundLibrary.resolvedSoundURL(named:),
        soundFactory: @escaping SoundFactory = BarkAlertPlaybackCoordinator.defaultSoundFactory,
        timeProvider: @escaping TimeProvider = Date.init,
        sleepHandler: @escaping SleepHandler = { delay in
            guard delay > 0 else { return }
            try? await Task.sleep(for: .seconds(delay))
        },
        maxCallDuration: TimeInterval = 30
    ) {
        self.soundURLResolver = soundURLResolver
        self.soundFactory = soundFactory
        self.timeProvider = timeProvider
        self.sleepHandler = sleepHandler
        self.maxCallDuration = maxCallDuration
    }

    func shouldUseSystemNotificationSound(for notification: BarkResolvedNotification) -> Bool {
        if notification.level == .passive {
            return false
        }
        return notification.soundName == nil
    }

    func play(for notification: BarkResolvedNotification) {
        guard notification.level != .passive else {
            stopCallPlayback()
            return
        }
        guard let soundName = notification.soundName else {
            return
        }

        if notification.isCall {
            startCallPlayback(remoteID: notification.remoteID, soundName: soundName, volume: playbackVolume(for: notification))
            return
        }

        playOnce(soundName: soundName, volume: playbackVolume(for: notification))
    }

    func stopPlayback(forRemoteID remoteID: String) {
        guard activeCallRemoteID == remoteID else { return }
        stopCallPlayback()
    }

    private func playbackVolume(for notification: BarkResolvedNotification) -> Float {
        if notification.level == .critical {
            return Float(notification.volume ?? 0.5)
        }
        return 1.0
    }

    private func playOnce(soundName: String, volume: Float) {
        guard let sound = makeSound(named: soundName, volume: volume) else {
            return
        }
        let retentionID = UUID()
        retainedSounds[retentionID] = sound
        guard sound.play() else {
            retainedSounds.removeValue(forKey: retentionID)
            return
        }

        let releaseDelay = max(sound.duration, 0.25) + 0.2
        Task { @MainActor [weak self] in
            await self?.sleepHandler(releaseDelay)
            self?.retainedSounds.removeValue(forKey: retentionID)
        }
    }

    private func startCallPlayback(remoteID: String?, soundName: String, volume: Float) {
        stopCallPlayback()
        activeCallRemoteID = remoteID
        activeCallTask = Task { [weak self] in
            await self?.runCallLoop(soundName: soundName, volume: volume)
        }
    }

    private func runCallLoop(soundName: String, volume: Float) async {
        let deadline = timeProvider().addingTimeInterval(maxCallDuration)

        while !Task.isCancelled, timeProvider() < deadline {
            guard let sound = makeSound(named: soundName, volume: volume) else {
                break
            }
            activeCallSound = sound
            let didPlay = sound.play()
            let remaining = deadline.timeIntervalSince(timeProvider())
            let playbackDuration = sound.duration > 0 ? sound.duration : 0.1
            let waitTime = min(playbackDuration, max(remaining, 0))
            if !didPlay || waitTime <= 0 {
                break
            }
            await sleepHandler(waitTime)
            sound.stop()
        }

        if Task.isCancelled == false {
            stopCallPlayback()
        }
    }

    private func stopCallPlayback() {
        activeCallTask?.cancel()
        activeCallTask = nil
        activeCallSound?.stop()
        activeCallSound = nil
        activeCallRemoteID = nil
    }

    private func makeSound(named rawName: String, volume: Float) -> BarkPlayableSound? {
        guard let soundURL = soundURLResolver(rawName), let sound = soundFactory(soundURL) else {
            return nil
        }
        sound.volume = volume
        return sound
    }

    private static func defaultSoundFactory(url: URL) -> BarkPlayableSound? {
        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            return nil
        }
        return BarkNSSoundAdapter(sound: sound)
    }
}
