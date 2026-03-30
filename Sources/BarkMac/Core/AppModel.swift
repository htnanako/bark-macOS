import AppKit
import Foundation
import Observation
import ServiceManagement
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

@MainActor
@Observable
final class AppModel {
    var configuration: BarkServerConfiguration {
        didSet {
            SettingsStore.save(configuration)
        }
    }
    var notificationHistory: [BarkNotificationRecord] {
        didSet {
            SettingsStore.saveNotificationHistory(notificationHistory)
        }
    }

    var lastPingMessage: String = "启动后自动检测中..."
    var lastServerSummary: String = "正在检查服务端状态..."
    var registrationMessage: String = "尚未注册"
    var notificationStatus: String = "未请求"
    var notificationSettingsSummary: String = "等待读取系统通知设置"
    var launchAtLoginEnabled: Bool = false
    var launchAtLoginStatus: String = "等待读取登录项状态"
    var streamStatus: String = "未连接"
    var lastNotificationPayload: String = "还没有收到推送"
    var toastSignal: BarkToastSignal?
    var isWorking: Bool = false

    private let apiClient: BarkAPIClient
    private let pasteboardWriter: @MainActor (String) -> Void
    private let urlOpener: @MainActor (URL) -> Void
    private let alertPlaybackCoordinator: BarkAlertPlaybackCoordinating
    private let notificationAssetStore: BarkNotificationAssetServing
    private var streamTask: Task<Void, Never>?
    private var hasRestoredSession = false
    private let maxNotificationHistoryCount = 200

    init(
        configuration: BarkServerConfiguration = SettingsStore.load(),
        notificationHistory: [BarkNotificationRecord] = SettingsStore.loadNotificationHistory(),
        apiClient: BarkAPIClient = BarkAPIClient(),
        pasteboardWriter: @escaping @MainActor (String) -> Void = AppModel.defaultPasteboardWriter,
        urlOpener: @escaping @MainActor (URL) -> Void = AppModel.defaultURLOpener,
        alertPlaybackCoordinator: BarkAlertPlaybackCoordinating = BarkAlertPlaybackCoordinator(),
        notificationAssetStore: BarkNotificationAssetServing = BarkNotificationAssetStore(),
        restoreSessionOnInit: Bool = true
    ) {
        self.configuration = configuration
        self.notificationHistory = notificationHistory.sorted { $0.receivedAt > $1.receivedAt }
        self.apiClient = apiClient
        self.pasteboardWriter = pasteboardWriter
        self.urlOpener = urlOpener
        self.alertPlaybackCoordinator = alertPlaybackCoordinator
        self.notificationAssetStore = notificationAssetStore
        BarkSoundLibrary.installBundledSoundsIfNeeded()
        if let latest = self.notificationHistory.first {
            lastNotificationPayload = latest.payload
        }
        if restoreSessionOnInit {
            restoreSessionIfNeeded()
        }
    }

    func restoreSessionIfNeeded() {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true

        refreshNotificationSettings()
        refreshLaunchAtLoginStatus()
        refreshServerStatus()

        if !configuration.deviceKey.isEmpty {
            registrationMessage = """
            已恢复本地注册
            key: \(configuration.deviceKey)
            stream: \(configuration.streamToken.isEmpty ? "未保存" : "已保存")
            provider: \(configuration.providerID)
            """
        }

        guard configuration.autoConnectOnLaunch else {
            streamStatus = "已待机"
            return
        }

        guard !configuration.deviceKey.isEmpty, !configuration.streamToken.isEmpty else {
            return
        }
        connectEventStream()
    }

    func requestNotificationAuthorization() {
        notificationStatus = "请求中..."
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                notificationStatus = granted ? "已授权" : "用户拒绝"
                refreshNotificationSettings()
            } catch {
                notificationStatus = "授权失败: \(describe(error: error))"
            }
        }
    }

    func refreshNotificationSettings() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notificationStatus = settings.alertSetting == .enabled ? "已授权" : "已授权但横幅关闭"
            case .denied:
                notificationStatus = "用户拒绝"
            case .notDetermined:
                notificationStatus = "未请求"
            @unknown default:
                notificationStatus = "状态未知"
            }

            notificationSettingsSummary = """
            授权: \(describeAuthorization(settings.authorizationStatus))
            横幅: \(describeSetting(settings.alertSetting))
            声音: \(describeSetting(settings.soundSetting))
            通知中心: \(describeSetting(settings.notificationCenterSetting))
            锁屏: \(describeSetting(settings.lockScreenSetting))
            """
        }
    }

    func openNotificationSettings() {
        let workspace = NSWorkspace.shared
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            workspace.open(url)
        }
    }

    func enableAutoConnectOnLaunch() {
        guard !configuration.autoConnectOnLaunch else { return }
        configuration.autoConnectOnLaunch = true
        registrationMessage = "已开启启动后自动连接事件流"
        if streamTask == nil, !configuration.deviceKey.isEmpty, !configuration.streamToken.isEmpty {
            connectEventStream()
        }
    }

    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            switch service.status {
            case .enabled:
                launchAtLoginEnabled = true
                launchAtLoginStatus = "已启用，登录后会自动启动"
            case .requiresApproval:
                launchAtLoginEnabled = false
                launchAtLoginStatus = "已注册但需要用户在系统设置中批准"
            case .notRegistered:
                launchAtLoginEnabled = false
                launchAtLoginStatus = "未启用"
            case .notFound:
                launchAtLoginEnabled = false
                launchAtLoginStatus = "系统未找到可注册的登录项"
            @unknown default:
                launchAtLoginEnabled = false
                launchAtLoginStatus = "登录项状态未知"
            }
        } else {
            launchAtLoginEnabled = false
            launchAtLoginStatus = "当前系统版本不支持此能力"
        }
    }

    func enableLaunchAtLogin() {
        guard !launchAtLoginEnabled else { return }
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                refreshLaunchAtLoginStatus()
                registrationMessage = "已请求开启登录时启动"
            } catch {
                refreshLaunchAtLoginStatus()
                registrationMessage = """
                登录时自动启动设置失败
                这通常不是网络故障，而是当前自分发未正式签名的 .app 无法被 ServiceManagement 注册为登录项。
                详细错误: \(describe(error: error))
                """
            }
        } else {
            launchAtLoginEnabled = false
            launchAtLoginStatus = "当前系统版本不支持此能力"
        }
    }

    func openLoginItemsSettings() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func refreshServerStatus() {
        isWorking = true
        lastPingMessage = "测试中..."
        lastServerSummary = "正在获取服务端信息..."
        Task {
            defer { isWorking = false }

            do {
                async let pingMessage = apiClient.ping(configuration: configuration)
                async let info = apiClient.info(configuration: configuration)
                let (ping, serverInfo) = try await (pingMessage, info)
                lastPingMessage = ping
                lastServerSummary = AppModel.describe(serverInfo: serverInfo)
            } catch {
                lastPingMessage = "连接失败"
                lastServerSummary = error.localizedDescription
            }
        }
    }

    func registerCurrentDevice() {
        isWorking = true
        registrationMessage = "注册中..."
        Task {
            defer { isWorking = false }

            do {
                let response = try await apiClient.register(configuration: configuration)
                let resolvedKey = response.deviceKey ?? response.key ?? ""
                if !resolvedKey.isEmpty {
                    configuration.deviceKey = resolvedKey
                }
                if let streamToken = response.streamToken, !streamToken.isEmpty {
                    configuration.streamToken = streamToken
                }
                registrationMessage = """
                注册成功
                key: \(resolvedKey.isEmpty ? "未返回" : resolvedKey)
                stream: \(configuration.streamToken.isEmpty ? "未返回" : "已签发")
                provider: \(response.providerID ?? configuration.providerID)
                """
            } catch {
                registrationMessage = error.localizedDescription
            }
        }
    }

    func connectEventStream() {
        guard streamTask == nil else { return }
        guard !configuration.deviceKey.isEmpty else {
            streamStatus = BarkClientError.missingDeviceKey.localizedDescription
            return
        }
        guard !configuration.streamToken.isEmpty else {
            streamStatus = BarkClientError.missingStreamToken.localizedDescription
            return
        }

        streamStatus = "连接中..."
        streamTask = Task.detached(priority: .userInitiated) { [weak self] in
            await Self.runEventStreamLoop(owner: self)
        }
    }

    func disconnectEventStream() {
        streamTask?.cancel()
        streamTask = nil
        streamStatus = "已断开"
    }

    func copyDeviceKeyToPasteboard() {
        guard !configuration.deviceKey.isEmpty else { return }
        copyTextToPasteboard(configuration.deviceKey)
    }

    func copyStreamTokenToPasteboard() {
        guard !configuration.streamToken.isEmpty else { return }
        copyTextToPasteboard(configuration.streamToken)
    }

    func copyTextToPasteboard(_ text: String) {
        guard !text.isEmpty else { return }
        pasteboardWriter(text)
    }

    func emitToast(_ message: String, symbolName: String) {
        toastSignal = BarkToastSignal(message: message, symbolName: symbolName)
    }

    func clearNotificationHistory() {
        guard !notificationHistory.isEmpty else { return }
        notificationHistory.removeAll()
        lastNotificationPayload = "还没有收到推送"
        emitToast("历史记录已清空", symbolName: "trash.fill")
    }

    func clearNotificationHistory(olderThan age: TimeInterval, now: Date = .now) {
        guard !notificationHistory.isEmpty else { return }
        let cutoff = now.addingTimeInterval(-age)
        let originalCount = notificationHistory.count
        notificationHistory.removeAll { $0.receivedAt < cutoff }
        let removedCount = originalCount - notificationHistory.count
        guard removedCount > 0 else {
            emitToast("没有符合条件的历史记录", symbolName: "tray.fill")
            return
        }
        emitToast("已清理 \(removedCount) 条历史记录", symbolName: "trash.fill")
    }

    func deleteNotificationRecord(_ record: BarkNotificationRecord, shouldSyncSystemNotifications: Bool = true) {
        if let remoteID = record.remoteID, !remoteID.isEmpty {
            alertPlaybackCoordinator.stopPlayback(forRemoteID: remoteID)
        }
        notificationHistory.removeAll { $0.id == record.id }
        if shouldSyncSystemNotifications, let remoteID = record.remoteID, !remoteID.isEmpty {
            let identifier = "bark-remote-\(remoteID)"
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        emitToast("已删除记录", symbolName: "trash.fill")
    }

    func exportNotificationHistory() {
        guard !notificationHistory.isEmpty else {
            emitToast("没有可导出的历史记录", symbolName: "tray.fill")
            return
        }

        do {
            let data = try exportedNotificationHistoryData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "bark-history-\(Self.exportTimestamp()).json"
            panel.title = "导出 Bark 历史记录"

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            emitToast("历史记录已导出", symbolName: "square.and.arrow.up.fill")
        } catch {
            registrationMessage = "导出历史记录失败: \(describe(error: error))"
        }
    }

    func importNotificationHistory() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.title = "导入 Bark 历史记录"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let importedCount = try importNotificationHistory(from: data)
            emitToast("已导入 \(importedCount) 条记录", symbolName: "square.and.arrow.down.fill")
        } catch {
            registrationMessage = "导入历史记录失败: \(describe(error: error))"
        }
    }

    func exportedNotificationHistoryData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(notificationHistory)
    }

    @discardableResult
    func importNotificationHistory(from data: Data) throws -> Int {
        let importedRecords = try JSONDecoder().decode([BarkNotificationRecord].self, from: data)
        mergeImportedNotificationHistory(importedRecords)
        return importedRecords.count
    }

    func sendTestLocalNotification(soundName: String? = "chime") {
        Task {
            let payload: [String: Any] = [
                "title": "Bark 本地通知测试",
                "subtitle": "macOS Client",
                "body": soundName == nil
                    ? "如果你看到了这条横幅，说明本地通知展示链路是正常的。"
                    : "如果横幅和 chime 都正常，说明本地通知与声音播放链路都已就绪。",
                "sound": soundName as Any,
                "source": "manual_test",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
            ]
            .compactMapValues { $0 }

            do {
                let resolved = try payloadResolver.resolve(payload, eventID: "manual-test-\(UUID().uuidString)")
                try await sendLocalNotification(from: resolved)
                refreshNotificationSettings()
                registrationMessage = """
                已触发本地通知测试
                title: Bark 本地通知测试
                sound: \(resolved.soundName ?? "default")
                body: \(resolved.body)
                """
            } catch {
                registrationMessage = "本地通知投递失败: \(describe(error: error))"
            }
        }
    }

    func foregroundPresentationOptions(for userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        let context = BarkNotificationActionContext(userInfo: userInfo)
        if context.level == .passive {
            return [.list]
        }
        if context.soundName != nil {
            return [.banner, .list]
        }
        return [.banner, .list, .sound]
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
        let context = BarkNotificationActionContext(userInfo: response.notification.request.content.userInfo)
        return handleNotificationAction(actionIdentifier: response.actionIdentifier, context: context)
    }

    func handleNotificationAction(actionIdentifier: String, context: BarkNotificationActionContext) -> Bool {
        switch actionIdentifier {
        case BarkNotificationCategory.copyAction:
            let text = context.fallbackCopyText
            if !text.isEmpty {
                copyTextToPasteboard(text)
                emitToast("内容已复制", symbolName: "checkmark.circle.fill")
            }
            return false
        case BarkNotificationCategory.openAction, UNNotificationDefaultActionIdentifier:
            if let url = validatedURL(from: context.urlString) {
                urlOpener(url)
                return false
            }
            configuration.selectedTab = .records
            return true
        default:
            return false
        }
    }

    func applyResolvedNotification(
        _ resolved: BarkResolvedNotification,
        shouldDeliverNotification: Bool = true,
        shouldPerformAutoCopy: Bool = true
    ) async {
        lastNotificationPayload = resolved.rawPayload

        if resolved.isDeleteCommand {
            handleDeleteCommand(resolved, shouldSyncSystemNotifications: shouldDeliverNotification)
            return
        }

        if resolved.isArchive {
            storeNotificationRecord(from: resolved)
        }

        if shouldPerformAutoCopy, resolved.isAutoCopy {
            let text = resolved.actionContext.fallbackCopyText
            if !text.isEmpty {
                copyTextToPasteboard(text)
                emitToast("内容已自动复制", symbolName: "doc.on.doc.fill")
            }
        }

        if shouldDeliverNotification, resolved.shouldDeliverLocalNotification {
            do {
                try await sendLocalNotification(from: resolved)
            } catch {
                registrationMessage = "本地通知投递失败: \(describe(error: error))"
            }
        }
    }

    private var payloadResolver: BarkPayloadResolver {
        BarkPayloadResolver(encryption: configuration.encryption)
    }

    private func storeNotificationRecord(from resolved: BarkResolvedNotification) {
        let record = BarkNotificationRecord(resolved: resolved)
        notificationHistory.removeAll { existing in
            if let remoteID = resolved.remoteID, !remoteID.isEmpty {
                return existing.remoteID == remoteID
            }
            return false
        }
        notificationHistory.insert(record, at: 0)
        trimNotificationHistoryIfNeeded()
    }

    private func mergeImportedNotificationHistory(_ importedRecords: [BarkNotificationRecord]) {
        var merged: [String: BarkNotificationRecord] = [:]
        let combined = notificationHistory + importedRecords
        for record in combined {
            let key = historyRecordKey(for: record)
            if let existing = merged[key] {
                merged[key] = existing.receivedAt >= record.receivedAt ? existing : record
            } else {
                merged[key] = record
            }
        }
        notificationHistory = merged.values.sorted { $0.receivedAt > $1.receivedAt }
        trimNotificationHistoryIfNeeded()
    }

    private func historyRecordKey(for record: BarkNotificationRecord) -> String {
        if let remoteID = record.remoteID, !remoteID.isEmpty {
            return "remote:\(remoteID)"
        }
        return "local:\(record.id.uuidString)"
    }

    private func trimNotificationHistoryIfNeeded() {
        if notificationHistory.count > maxNotificationHistoryCount {
            notificationHistory.removeLast(notificationHistory.count - maxNotificationHistoryCount)
        }
    }

    private func handleDeleteCommand(_ resolved: BarkResolvedNotification, shouldSyncSystemNotifications: Bool) {
        guard let remoteID = resolved.remoteID, !remoteID.isEmpty else {
            registrationMessage = "收到 delete 指令，但缺少消息 id。"
            return
        }
        alertPlaybackCoordinator.stopPlayback(forRemoteID: remoteID)
        notificationHistory.removeAll { $0.remoteID == remoteID }
        if shouldSyncSystemNotifications {
            let identifier = "bark-remote-\(remoteID)"
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        emitToast("已删除消息 \(remoteID)", symbolName: "trash.fill")
    }

    private func sendLocalNotification(from resolved: BarkResolvedNotification) async throws {
        let attachments = await notificationAssetStore.attachments(for: resolved)
        let content = BarkNotificationComposer.makeContent(
            from: resolved,
            includeSystemSound: alertPlaybackCoordinator.shouldUseSystemNotificationSound(for: resolved),
            attachments: attachments
        )
        let request = UNNotificationRequest(
            identifier: resolved.notificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        )

        try await UNUserNotificationCenter.current().add(request)
        alertPlaybackCoordinator.play(for: resolved)
    }

    private static func describe(serverInfo: BarkServerInfo) -> String {
        let providers = serverInfo.providers?.joined(separator: ", ") ?? "无"
        return """
        version: \(serverInfo.version ?? "unknown")
        build: \(serverInfo.build ?? "unknown")
        arch: \(serverInfo.arch ?? "unknown")
        devices: \(serverInfo.devices.map(String.init) ?? "0")
        providers: \(providers)
        """
    }

    private static func runEventStreamLoop(owner: AppModel?) async {
        guard let owner else { return }

        let apiClient = BarkAPIClient()
        var attempt = 0
        while !Task.isCancelled {
            do {
                let currentConfiguration = await MainActor.run { owner.configuration }
                try await apiClient.consumeEvents(configuration: currentConfiguration) { [weak owner] message in
                    Task { @MainActor in
                        owner?.handleStreamMessage(message)
                    }
                }
                attempt = 0
                await MainActor.run {
                    owner.streamStatus = "连接已关闭"
                }
            } catch is CancellationError {
                break
            } catch {
                attempt += 1
                let delay = await MainActor.run { owner.reconnectDelay(for: attempt) }
                await MainActor.run {
                    owner.streamStatus = "重连中，\(Int(delay)) 秒后重试"
                }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        await MainActor.run {
            owner.streamTask = nil
        }
    }

    private func handleStreamMessage(_ message: BarkSSEMessage) {
        if let id = message.id, !id.isEmpty {
            configuration.lastEventID = id
        }

        guard message.event == "notification" else {
            streamStatus = "已连接"
            return
        }

        streamStatus = "已连接"

        guard let data = message.data.data(using: .utf8) else { return }
        guard let eventObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let payload = (eventObject["payload"] as? [String: Any]) ?? eventObject

        do {
            let resolved = try payloadResolver.resolve(payload, eventID: message.id)
            Task {
                await applyResolvedNotification(resolved)
            }
        } catch {
            lastNotificationPayload = prettyPrintedJSON(from: payload) ?? fallbackDescription(for: payload)
            registrationMessage = "推送解析失败: \(describe(error: error))"
            emitToast("推送解析失败", symbolName: "exclamationmark.triangle.fill")
        }
    }

    private func reconnectDelay(for attempt: Int) -> Double {
        let steps: [Double] = [1, 2, 5, 10, 20, 30]
        let base = steps[min(attempt - 1, steps.count - 1)]
        let jitter = Double.random(in: 0 ..< 0.8)
        return base + jitter
    }

    private func prettyPrintedJSON(from payload: [String: Any]) -> String? {
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return text
    }

    private func fallbackDescription(for payload: [String: Any]) -> String {
        payload
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    private func validatedURL(from urlString: String?) -> URL? {
        guard let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }

    private func describeAuthorization(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .notDetermined:
            return "未请求"
        case .provisional:
            return "临时授权"
        case .ephemeral:
            return "短期授权"
        @unknown default:
            return "未知"
        }
    }

    private func describeSetting(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled:
            return "已开启"
        case .disabled:
            return "已关闭"
        case .notSupported:
            return "不支持"
        @unknown default:
            return "未知"
        }
    }

    private func describe(error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain.contains("ServiceManagement") {
            if nsError.localizedDescription.contains("无法连接服务") {
                return "ServiceManagement (\(nsError.code)): 无法连接系统登录项服务，当前未正式签名的构建大概率无法启用开机自启"
            }
            return "ServiceManagement (\(nsError.code)): \(nsError.localizedDescription)"
        }
        if nsError.domain.isEmpty {
            return error.localizedDescription
        }
        return "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
    }

    private static func defaultPasteboardWriter(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func defaultURLOpener(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private static func exportTimestamp(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: now)
    }
}
