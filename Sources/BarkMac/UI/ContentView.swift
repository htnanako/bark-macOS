import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    @State private var payloadPreviewRecord: BarkNotificationRecord?
    @State private var activeToast: BarkToast?
    @State private var recordSearchText = ""
    @State private var recordsGroupedByGroup = true

    private let statusColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]
    private let overviewCardContentHeight: CGFloat = 176
    private let deviceInfoCardContentHeight: CGFloat = 190
    private let deviceBottomCardHeight: CGFloat = 348

    var body: some View {
        ZStack {
            BarkPalette.canvas
                .ignoresSafeArea()

            backgroundOrbs

            VStack(alignment: .leading, spacing: 24) {
                heroHeader
                tabBar
                pageHeader

                ZStack {
                    tabContentScrollView(.overview) {
                        overviewPage
                    }

                    tabContentScrollView(.server) {
                        serverPage
                    }

                    tabContentScrollView(.device) {
                        devicePage
                    }

                    tabContentScrollView(.records) {
                        recordsPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 1040, maxHeight: .infinity, alignment: .top)

            if let record = payloadPreviewRecord {
                payloadPreviewOverlay(record: record)
            }

            if let toast = activeToast {
                toastView(toast)
                    .padding(.top, 22)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }

            VStack {
                Spacer()

                HStack {
                    Spacer()
                    footerBar
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
            .frame(maxWidth: 1040, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(minWidth: 980, minHeight: 820)
        .onChange(of: model.toastSignal) { _, newValue in
            guard let newValue else { return }
            showToast(newValue.message, symbolName: newValue.symbolName)
        }
    }

    private var backgroundOrbs: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(BarkPalette.sky.opacity(0.24))
                    .frame(width: 360, height: 360)
                    .blur(radius: 12)
                    .offset(x: proxy.size.width * 0.34, y: -180)

                Circle()
                    .fill(BarkPalette.mint.opacity(0.18))
                    .frame(width: 420, height: 420)
                    .blur(radius: 20)
                    .offset(x: proxy.size.width * 0.42, y: proxy.size.height * 0.38)

                Circle()
                    .fill(BarkPalette.peach.opacity(0.16))
                    .frame(width: 280, height: 280)
                    .blur(radius: 18)
                    .offset(x: -proxy.size.width * 0.28, y: proxy.size.height * 0.22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BARK MAC DESKTOP")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(BarkPalette.muted)

                HStack(alignment: .center, spacing: 14) {
                    BarkHeroLogo()

                    Text("Bark for macOS")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.ink)
                }

                Text("在 Mac 上接收和查看 Bark 消息，随时掌握设备连接状态与最新通知。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BarkPalette.subtleInk)
                    .frame(maxWidth: 640, alignment: .leading)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                compactStatusChip(title: "当前页面", value: model.configuration.selectedTab.title, tint: BarkPalette.indigo)
                compactStatusChip(title: "事件流", value: model.streamStatus, tint: streamTint)
            }
        }
        .padding(.top, 8)
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            Text("Version \(AppVersion.displayString)")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.subtleInk)

            githubLinkButton
        }
    }

    private var githubLinkButton: some View {
        Link(destination: URL(string: "https://github.com/htnanako/bark-macOS")!) {
            GitHubLineIcon()
                .frame(width: 18, height: 18)
        }
        .help("打开 GitHub 仓库")
    }

    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    model.configuration.selectedTab = tab
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tab.shortTitle.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.1)

                        Text(tab.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(model.configuration.selectedTab == tab ? .white : BarkPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(model.configuration.selectedTab == tab ? BarkPalette.accent : Color.white.opacity(0.62))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(model.configuration.selectedTab == tab ? BarkPalette.accent : BarkPalette.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.configuration.selectedTab.shortTitle.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(BarkPalette.muted)

            HStack(alignment: .center, spacing: 16) {
                Text(model.configuration.selectedTab.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BarkPalette.ink)

                Spacer(minLength: 0)

                if model.configuration.selectedTab == .records {
                    Button("清空历史记录") {
                        model.clearNotificationHistory()
                    }
                    .buttonStyle(BarkDangerButtonStyle())
                    .disabled(model.notificationHistory.isEmpty)
                }
            }

            Text(model.configuration.selectedTab.subtitle)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundStyle(BarkPalette.subtleInk)
                .frame(maxWidth: 700, alignment: .leading)
        }
    }

    private func tabContentScrollView<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 8)
        }
        .opacity(model.configuration.selectedTab == tab ? 1 : 0)
        .allowsHitTesting(model.configuration.selectedTab == tab)
        .accessibilityHidden(model.configuration.selectedTab != tab)
        .zIndex(model.configuration.selectedTab == tab ? 1 : 0)
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            statusGrid

            HStack(alignment: .top, spacing: 20) {
                overviewSummaryCard
                inboxSummaryCard
            }
        }
    }

    private var overviewSummaryCard: some View {
        card(
            eyebrow: "Overview",
            title: "当前运行状态",
            summary: ""
        ) {
            VStack(alignment: .leading, spacing: 14) {
                summaryRow(
                    title: "服务端",
                    value: model.lastPingMessage,
                    detail: serverSummaryBrief,
                    tint: BarkPalette.sky
                )
                summaryRow(
                    title: "注册",
                    value: registrationHeadline,
                    detail: registrationSummaryBrief,
                    tint: BarkPalette.mint
                )
            }
            .frame(maxWidth: .infinity, minHeight: overviewCardContentHeight, maxHeight: overviewCardContentHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var inboxSummaryCard: some View {
        card(
            eyebrow: "Inbox",
            title: "最近一条推送",
            summary: ""
        ) {
            Group {
                if let latest = model.notificationHistory.first {
                    ScrollView(showsIndicators: true) {
                        notificationPreview(record: latest)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.trailing, 4)
                    }
                } else {
                    emptyState(
                        title: "还没有收到推送",
                        detail: "连上事件流后，最新消息会优先显示在这里。"
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: overviewCardContentHeight, maxHeight: overviewCardContentHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var serverPage: some View {
        card(
            eyebrow: "Connection",
            title: "服务端配置",
            summary: "管理服务端地址与密文解密配置。注册时仍沿用当前内置的 App ID、Provider ID 和 Topic。"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                fieldRow("Server URL", text: $model.configuration.serverURL, prompt: "http://127.0.0.1:8080", width: 460)

                HStack(spacing: 12) {
                    Button("测试服务器") {
                        model.refreshServerStatus()
                    }
                    .buttonStyle(BarkPrimaryButtonStyle())
                    .disabled(model.isWorking)

                    if model.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(BarkPalette.accent)
                    }
                }

                consolePanel(model.lastServerSummary, minHeight: 132)

                Divider()
                    .overlay(BarkPalette.border)

                VStack(alignment: .leading, spacing: 14) {
                    Text("密文解密配置")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.ink)

                    Text("当服务端推送 `ciphertext` 时，桌面端会按这里的算法配置先解密，再继续走同一套参数解析与通知逻辑。留空 key 表示不启用密文解密。")
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(BarkPalette.subtleInk)

                    HStack(alignment: .top, spacing: 16) {
                        fieldStack(label: "Algorithm", caption: "和发送端保持一致") {
                            Picker("Algorithm", selection: $model.configuration.encryption.algorithm) {
                                ForEach(BarkEncryptionAlgorithm.allCases) { algorithm in
                                    Text(algorithm.rawValue).tag(algorithm)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        fieldStack(label: "Mode", caption: "CBC / ECB / GCM") {
                            Picker("Mode", selection: $model.configuration.encryption.mode) {
                                ForEach(BarkEncryptionMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    fieldRow(
                        "Key",
                        text: $model.configuration.encryption.key,
                        prompt: "\(model.configuration.encryption.algorithm.keyLength) 字符",
                        width: 420
                    )

                    fieldRow(
                        "IV",
                        text: $model.configuration.encryption.iv,
                        prompt: model.configuration.encryption.ivPlaceholder,
                        width: 420
                    )
                    .disabled(model.configuration.encryption.mode.ivLength == nil)
                }
                .padding(18)
                .background(panelBackground(cornerRadius: 22))
            }
        }
    }

    private var devicePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            card(
                eyebrow: "Registration",
                title: "设备注册流程",
                summary: "按顺序完成通知权限、注册设备、连接事件流和接收推送。当前需要处理的步骤会被高亮出来。"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    registrationStep(
                        index: 0,
                        title: "请求通知权限",
                        detail: "允许桌面端弹出本地提醒和声音。",
                        status: model.notificationStatus,
                        isActive: activeRegistrationStepIndex == 0,
                        isCompleted: hasNotificationAuthorization
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Button("请求通知权限") {
                                    model.requestNotificationAuthorization()
                                }
                                .buttonStyle(BarkPrimaryButtonStyle())
                                .disabled(hasNotificationAuthorization)

                                Button("打开系统通知设置") {
                                    model.openNotificationSettings()
                                }
                                .buttonStyle(BarkSecondaryButtonStyle())
                            }
                        }
                    }

                    registrationConnector

                    registrationStep(
                        index: 1,
                        title: "注册当前设备",
                        detail: "向服务端注册当前设备。",
                        status: registrationStepStatus,
                        isActive: activeRegistrationStepIndex == 1,
                        isCompleted: hasRegistrationCredentials
                    ) {
                        Button("注册当前设备") {
                            model.registerCurrentDevice()
                        }
                        .buttonStyle(BarkPrimaryButtonStyle())
                        .disabled(model.isWorking || hasRegistrationCredentials)
                    }

                    registrationConnector

                    registrationStep(
                        index: 2,
                        title: "连接事件流",
                        detail: "建立 SSE 长连接，保持设备在线接收推送。如果无法收到推送消息，可断开重新连接SSE。",
                        status: model.streamStatus,
                        isActive: activeRegistrationStepIndex == 2,
                        isCompleted: isStreamConnected
                    ) {
                        HStack(spacing: 12) {
                            Button("连接事件流") {
                                model.connectEventStream()
                            }
                            .buttonStyle(BarkPrimaryButtonStyle())

                            Button("断开连接") {
                                model.disconnectEventStream()
                            }
                            .buttonStyle(BarkDangerButtonStyle())
                        }
                    }

                    registrationConnector

                    registrationStep(
                        index: 3,
                        title: "等待推送到达",
                        detail: "连接建立后，收到的消息会自动写入记录页，并在本地弹出通知。",
                        status: latestRecordStatus,
                        isActive: activeRegistrationStepIndex == 3,
                        isCompleted: hasReceivedNotifications
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Text("收到的推送会自动出现在“记录”页，最新消息始终置顶。手动测试按钮会同时验证本地横幅和 chime 声音，不依赖服务端。")
                            //     .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            //     .foregroundStyle(BarkPalette.subtleInk)

                            Button("手动触发本地通知") {
                                model.sendTestLocalNotification()
                            }
                            .buttonStyle(BarkSecondaryButtonStyle())
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 20) {
                card(
                    eyebrow: "Credentials",
                    title: "当前凭证",
                    summary: "注册成功后，关键凭证会保存在本地。"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        readonlyFieldRow("Stream Token", text: model.configuration.streamToken, placeholder: "register 后返回")
                        readonlyFieldRow("Device Key", text: model.configuration.deviceKey, placeholder: "register 后返回")
                        readonlyFieldRow("Last Event ID", text: model.configuration.lastEventID, placeholder: "断线重连游标")

                        HStack(spacing: 12) {
                            Button(model.launchAtLoginEnabled ? "登录时启动已开启" : "开启登录时启动") {
                                model.enableLaunchAtLogin()
                            }
                            .buttonStyle(BarkSecondaryButtonStyle())
                            .disabled(model.launchAtLoginEnabled)
                            .frame(maxWidth: .infinity)

                            Button(model.configuration.autoConnectOnLaunch ? "启动自动连接已开启" : "开启启动自动连接") {
                                model.enableAutoConnectOnLaunch()
                            }
                            .buttonStyle(BarkSecondaryButtonStyle())
                            .disabled(model.configuration.autoConnectOnLaunch)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: deviceInfoCardContentHeight, maxHeight: deviceInfoCardContentHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, minHeight: deviceBottomCardHeight, maxHeight: deviceBottomCardHeight, alignment: .topLeading)

                card(
                    eyebrow: "Result",
                    title: "执行结果",
                    summary: "保留当前注册结果文本，方便联调时快速复制和比对。"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        consolePanel(model.registrationMessage, minHeight: 98, maxHeight: 98)

                        HStack(spacing: 12) {
                            Button("复制 Device Key") {
                                copyToPasteboard(model.configuration.deviceKey, successMessage: "Device Key 已复制")
                            }
                            .buttonStyle(BarkSecondaryButtonStyle())
                            .disabled(model.configuration.deviceKey.isEmpty)
                            .frame(maxWidth: .infinity)

                            Button("复制完整 URL") {
                                copyToPasteboard(serverDeviceURL, successMessage: "完整 URL 已复制")
                            }
                            .buttonStyle(BarkSecondaryButtonStyle())
                            .disabled(serverDeviceURL.isEmpty)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: deviceInfoCardContentHeight, maxHeight: deviceInfoCardContentHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, minHeight: deviceBottomCardHeight, maxHeight: deviceBottomCardHeight, alignment: .topLeading)
            }
        }
    }

    private var recordsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            recordsToolbar

            if model.notificationHistory.isEmpty {
                card(
                    eyebrow: "History",
                    title: "还没有推送记录",
                    summary: "一旦收到消息，这里会按时间倒序保存所有推送，并支持展开查看完整 payload。"
                ) {
                    emptyState(
                        title: "记录列表为空",
                        detail: "先在“设备注册”页连上事件流，再发送一条测试推送。"
                    )
                }
            } else if filteredNotificationHistory.isEmpty {
                card(
                    eyebrow: "Search",
                    title: "没有匹配结果",
                    summary: "当前搜索条件下没有找到历史记录。"
                ) {
                    emptyState(
                        title: "试试更短的关键词",
                        detail: "搜索会匹配标题、正文、分组、URL、复制内容和原始 Payload。"
                    )
                }
            } else if recordsGroupedByGroup {
                ForEach(groupedRecordSections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            tagPill(section.title, tint: section.isUngrouped ? BarkPalette.sky : BarkPalette.indigo)

                            Text("\(section.records.count) 条")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(BarkPalette.muted)

                            Spacer(minLength: 0)

                            Text(section.latestReceivedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(BarkPalette.muted)
                        }

                        ForEach(section.records) { record in
                            recordCard(record)
                        }
                    }
                }
            } else {
                ForEach(filteredNotificationHistory) { record in
                    recordCard(record)
                }
            }
        }
    }

    private var recordsToolbar: some View {
        card(
            eyebrow: "Records",
            title: "历史记录工具",
            summary: "搜索、分组、导入导出和清理。"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(BarkPalette.muted)

                    TextField("搜索标题、正文、分组、URL 或 Payload", text: $recordSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(BarkPalette.border, lineWidth: 1)
                        )
                )

                HStack(spacing: 12) {
                    Toggle(isOn: $recordsGroupedByGroup) {
                        Text("按分组查看")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BarkPalette.ink)
                    }
                    .toggleStyle(.switch)

                    Spacer(minLength: 0)

                    Menu("按时间范围清理") {
                        Button("清理 24 小时前记录") {
                            model.clearNotificationHistory(olderThan: 60 * 60 * 24)
                        }
                        Button("清理 7 天前记录") {
                            model.clearNotificationHistory(olderThan: 60 * 60 * 24 * 7)
                        }
                        Button("清理 30 天前记录") {
                            model.clearNotificationHistory(olderThan: 60 * 60 * 24 * 30)
                        }
                    }
                    .buttonStyle(BarkSecondaryButtonStyle())
                    .disabled(model.notificationHistory.isEmpty)

                    Button("导入记录") {
                        model.importNotificationHistory()
                    }
                    .buttonStyle(BarkSecondaryButtonStyle())

                    Button("导出记录") {
                        model.exportNotificationHistory()
                    }
                    .buttonStyle(BarkSecondaryButtonStyle())
                    .disabled(model.notificationHistory.isEmpty)
                }
            }
        }
    }

    private func recordCard(_ record: BarkNotificationRecord) -> some View {
        card(
            eyebrow: "Record",
            title: record.displayTitle,
            summary: record.receivedAt.formatted(date: .abbreviated, time: .standard),
            headerAccessory: {
                recordActionsMenu(record: record)
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let previewURL = record.cachedAssetURL {
                    recordAssetPreview(url: previewURL, cornerRadius: 18, maxHeight: 220)
                }

                if let secondaryTag = record.secondaryTagText {
                    tagPill(secondaryTag, tint: record.group == nil ? BarkPalette.sky : BarkPalette.indigo)
                }

                Text(record.displayBody)
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(BarkPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var statusGrid: some View {
        LazyVGrid(columns: statusColumns, alignment: .leading, spacing: 16) {
            StatusBadge(
                title: "通知权限",
                value: model.notificationStatus,
                detail: "决定是否能正常显示提醒和声音。",
                tint: BarkPalette.sky
            )
            StatusBadge(
                title: "SSE 连接",
                value: model.streamStatus,
                detail: "保持在线订阅，断线后会自动重连补发。",
                tint: BarkPalette.mint
            )
            StatusBadge(
                title: "服务端连通",
                value: model.lastPingMessage,
                detail: "通过 /ping 与 /info 检查当前服务状态。",
                tint: BarkPalette.peach
            )
            StatusBadge(
                title: "推送记录",
                value: "\(model.notificationHistory.count) 条",
                detail: model.notificationHistory.first?.displayTitle ?? "还没有收到推送",
                tint: BarkPalette.indigo
            )
        }
    }

    private func compactStatusChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(BarkPalette.muted)

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(BarkPalette.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 120, alignment: .topLeading)
        .frame(minHeight: 58, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BarkPalette.border, lineWidth: 1)
                )
        )
    }

    private func summaryRow(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(BarkPalette.muted)

                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(BarkPalette.ink)

                Text(detail)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(BarkPalette.subtleInk)
                    .textSelection(.enabled)
            }
        }
    }

    private func notificationPreview(record: BarkNotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let previewURL = record.cachedAssetURL {
                recordAssetPreview(url: previewURL, cornerRadius: 20, maxHeight: 180)
            }

            Text(record.receivedAt.formatted(date: .abbreviated, time: .standard))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.muted)

            Text(record.displayTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.ink)

            Text(record.displayBody)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundStyle(BarkPalette.subtleInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func recordAssetPreview(url: URL, cornerRadius: CGFloat, maxHeight: CGFloat) -> some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BarkPalette.panel)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(BarkPalette.muted)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(BarkPalette.border, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BarkPalette.panel)
        )
    }

    private func recordActionsMenu(record: BarkNotificationRecord) -> some View {
        Menu {
            Button("复制标题") {
                copyToPasteboard(record.displayTitle, successMessage: "标题已复制")
            }
            Button("复制内容") {
                copyToPasteboard(record.displayBody, successMessage: "内容已复制")
            }
            Button("复制标题+内容") {
                copyToPasteboard(record.combinedText, successMessage: "标题和内容已复制")
            }
            Button("复制完整 Payload") {
                copyToPasteboard(record.payload, successMessage: "完整 Payload 已复制")
            }
            Divider()
            Button("显示完整 Payload") {
                payloadPreviewRecord = record
            }
            Divider()
            Button("删除这条记录", role: .destructive) {
                if payloadPreviewRecord?.id == record.id {
                    payloadPreviewRecord = nil
                }
                model.deleteNotificationRecord(record)
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BarkPalette.muted)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .overlay(
                            Circle()
                                .stroke(BarkPalette.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func payloadPreviewSheet(record: BarkNotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("完整 Payload")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.ink)

                    Text(record.displayTitle)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(BarkPalette.subtleInk)

                    Text(record.receivedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.muted)
                }

                Spacer(minLength: 16)

                Button("复制 Payload") {
                    copyToPasteboard(record.payload, successMessage: "完整 Payload 已复制")
                }
                .buttonStyle(BarkSecondaryButtonStyle())
            }

            consolePanel(record.payload, minHeight: 320, maxHeight: .infinity)
        }
        .padding(24)
        .frame(width: 620, height: 460, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(BarkPalette.card.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(BarkPalette.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 30, x: 0, y: 20)
        )
    }

    private func payloadPreviewOverlay(record: BarkNotificationRecord) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    payloadPreviewRecord = nil
                }

            payloadPreviewSheet(record: record)
                .onTapGesture {
                    // Prevent taps inside the panel from dismissing the overlay.
                }
        }
        .transition(.opacity)
    }

    private func toastView(_ toast: BarkToast) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: toast.symbolName)
                    .font(.system(size: 13, weight: .bold))

                Text(toast.message)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(BarkPalette.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(BarkPalette.toast)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func registrationStep<Actions: View>(
        index: Int,
        title: String,
        detail: String,
        status: String,
        isActive: Bool,
        isCompleted: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isCompleted ? BarkPalette.mint : (isActive ? BarkPalette.accent : BarkPalette.border))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isCompleted || isActive ? .white : BarkPalette.muted)
                    )

                if isCompleted {
                    Text("完成")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.mint)
                } else if isActive {
                    Text("当前")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.accent)
                }
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(BarkPalette.ink)

                        Text(detail)
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(BarkPalette.subtleInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 12)

                    tagPill(status, tint: isCompleted ? BarkPalette.mint : (isActive ? BarkPalette.accent : BarkPalette.peach))
                }

                actions()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isActive ? BarkPalette.activePanel : BarkPalette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isActive ? BarkPalette.accent.opacity(0.5) : BarkPalette.border, lineWidth: isActive ? 1.4 : 1)
                )
        )
    }

    private var registrationConnector: some View {
        Rectangle()
            .fill(BarkPalette.border)
            .frame(width: 2, height: 20)
            .padding(.leading, 26)
            .padding(.vertical, 8)
    }

    private func tagPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(tint == BarkPalette.accent || tint == BarkPalette.mint ? .white : BarkPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
            )
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.ink)

            Text(detail)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(BarkPalette.subtleInk)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .padding(20)
        .background(panelBackground(cornerRadius: 22))
    }

    private func card<Content: View>(
        eyebrow: String,
        title: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        card(
            eyebrow: eyebrow,
            title: title,
            summary: summary,
            headerAccessory: { EmptyView() },
            content: content
        )
    }

    private func card<HeaderAccessory: View, Content: View>(
        eyebrow: String,
        title: String,
        summary: String,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(BarkPalette.muted)

                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(BarkPalette.ink)

                    if !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(BarkPalette.subtleInk)
                    }
                }

                Spacer(minLength: 0)

                headerAccessory()
            }

            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(BarkPalette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(BarkPalette.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 28, x: 0, y: 18)
        )
    }

    private func fieldRow(
        _ label: String,
        text: Binding<String>,
        prompt: String,
        width: CGFloat? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.muted)
                .frame(width: 112, alignment: .leading)

            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(BarkPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: width ?? .infinity)
                .background(panelBackground(cornerRadius: 14))
        }
    }

    private func fieldStack<Content: View>(
        label: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.muted)

            content()

            Text(caption)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(BarkPalette.subtleInk)
        }
    }

    private func readonlyFieldRow(_ label: String, text: String, placeholder: String) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(BarkPalette.muted)
                .frame(width: 112, alignment: .leading)

            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(text.isEmpty ? BarkPalette.muted : BarkPalette.ink)
                .lineLimit(1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(panelBackground(cornerRadius: 14))
        }
    }

    private func consolePanel(_ text: String, minHeight: CGFloat, maxHeight: CGFloat? = nil) -> some View {
        ScrollView(showsIndicators: true) {
            Text(text)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(BarkPalette.ink)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
                .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BarkPalette.console)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BarkPalette.border, lineWidth: 1)
                )
        )
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(BarkPalette.panel)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(BarkPalette.border, lineWidth: 1)
            )
    }

    private var hasNotificationAuthorization: Bool {
        model.notificationStatus == "已授权"
    }

    private var hasRegistrationCredentials: Bool {
        !model.configuration.deviceKey.isEmpty && !model.configuration.streamToken.isEmpty
    }

    private var isStreamConnected: Bool {
        model.streamStatus == "已连接"
    }

    private var hasReceivedNotifications: Bool {
        !model.notificationHistory.isEmpty
    }

    private var activeRegistrationStepIndex: Int {
        if !hasNotificationAuthorization {
            return 0
        }
        if !hasRegistrationCredentials {
            return 1
        }
        if !isStreamConnected {
            return 2
        }
        return 3
    }

    private var registrationHeadline: String {
        hasRegistrationCredentials ? "已生成 Device Key 与 Stream Token" : "等待注册完成"
    }

    private var serverDeviceURL: String {
        let serverURL = model.configuration.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceKey = model.configuration.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !serverURL.isEmpty, !deviceKey.isEmpty else {
            return ""
        }
        return serverURL.hasSuffix("/") ? "\(serverURL)\(deviceKey)" : "\(serverURL)/\(deviceKey)"
    }

    private var serverSummaryBrief: String {
        let text = model.lastServerSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "等待连接服务端" : compactSummary(text, limit: 46)
    }

    private var registrationSummaryBrief: String {
        if hasRegistrationCredentials {
            return "Device Key 和 Stream Token 已保存到本地。"
        }
        return compactSummary(model.registrationMessage, limit: 46)
    }

    private var registrationFocusTitle: String {
        switch activeRegistrationStepIndex {
        case 0:
            return "先打开通知权限"
        case 1:
            return "向服务端注册当前设备"
        case 2:
            return "把 SSE 长连接建立起来"
        default:
            return hasReceivedNotifications ? "当前流程已经跑通" : "等待第一条推送"
        }
    }

    private var registrationFocusSummary: String {
        switch activeRegistrationStepIndex {
        case 0:
            return "没有通知权限时，即使消息到达，也无法在桌面端形成完整提醒。"
        case 1:
            return "注册成功后会返回 Device Key 和 Stream Token，并自动保存到本地。"
        case 2:
            return "连接成功后会自动进入在线监听状态，断线会重试。"
        default:
            return hasReceivedNotifications ? "最近的推送已经进入记录页，可以展开查看完整 payload。" : "现在可以从服务端发一条测试消息验证全链路。"
        }
    }

    private var registrationStepStatus: String {
        if hasRegistrationCredentials {
            return "已拿到凭证"
        }
        return model.registrationMessage
    }

    private var latestRecordStatus: String {
        if let record = model.notificationHistory.first {
            return "最新: \(record.receivedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "等待第一条消息"
    }

    private var streamTint: Color {
        switch model.streamStatus {
        case "已连接":
            return BarkPalette.mint
        case "已断开", "连接失败":
            return BarkPalette.danger
        default:
            return BarkPalette.peach
        }
    }

    private func compactSummary(_ text: String, limit: Int) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard flattened.count > limit else {
            return flattened
        }
        return "\(flattened.prefix(limit))..."
    }

    private func copyToPasteboard(_ text: String, successMessage: String) {
        guard !text.isEmpty else {
            showToast("没有可复制的内容", symbolName: "exclamationmark.circle.fill")
            return
        }

        model.copyTextToPasteboard(text)
        showToast(successMessage, symbolName: "checkmark.circle.fill")
    }

    private func showToast(_ message: String, symbolName: String) {
        let toast = BarkToast(message: message, symbolName: symbolName)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            activeToast = toast
        }

        Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard activeToast?.id == toast.id else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    activeToast = nil
                }
            }
        }
    }

    private var filteredNotificationHistory: [BarkNotificationRecord] {
        let query = recordSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return model.notificationHistory
        }

        return model.notificationHistory.filter { record in
            let haystacks = [
                record.displayTitle,
                record.subtitle,
                record.body,
                record.group ?? "",
                record.urlString ?? "",
                record.copyText ?? "",
                record.remoteID ?? "",
                record.payload,
            ]
            .map { $0.lowercased() }

            return haystacks.contains { $0.contains(query) }
        }
    }

    private var groupedRecordSections: [BarkRecordSection] {
        let grouped = Dictionary(grouping: filteredNotificationHistory) { record in
            let trimmed = record.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "未分组" : trimmed
        }

        return grouped.map { title, records in
            BarkRecordSection(
                id: title,
                title: title,
                isUngrouped: title == "未分组",
                records: records.sorted { $0.receivedAt > $1.receivedAt }
            )
        }
        .sorted { $0.latestReceivedAt > $1.latestReceivedAt }
    }
}

private struct BarkToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let symbolName: String
}

private struct BarkRecordSection: Identifiable, Equatable {
    let id: String
    let title: String
    let isUngrouped: Bool
    let records: [BarkNotificationRecord]

    var latestReceivedAt: Date {
        records.first?.receivedAt ?? .distantPast
    }
}

private extension BarkNotificationRecord {
    var cachedAssetURL: URL? {
        BarkNotificationAssetStore.cachedAssetURL(
            iconURLString: iconURLString,
            imageURLString: imageURLString
        )
    }
}

private struct BarkHeroLogo: View {
    var body: some View {
        Group {
            if let image = BarkHeroLogoAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: BarkStatusBarIcon.makeImage())
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(BarkPalette.ink)
            }
        }
        .frame(width: 52, height: 52)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

private struct GitHubLineIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let strokeWidth = max(1.25, size * 0.085)

            ZStack {
                Path { path in
                    path.addEllipse(
                        in: CGRect(
                            x: size * 0.22,
                            y: size * 0.28,
                            width: size * 0.56,
                            height: size * 0.48
                        )
                    )
                }
                .stroke(BarkPalette.ink.opacity(0.88), lineWidth: strokeWidth)

                Path { path in
                    path.move(to: CGPoint(x: size * 0.31, y: size * 0.34))
                    path.addLine(to: CGPoint(x: size * 0.39, y: size * 0.16))
                    path.addLine(to: CGPoint(x: size * 0.47, y: size * 0.33))

                    path.move(to: CGPoint(x: size * 0.53, y: size * 0.33))
                    path.addLine(to: CGPoint(x: size * 0.61, y: size * 0.16))
                    path.addLine(to: CGPoint(x: size * 0.69, y: size * 0.34))

                    path.move(to: CGPoint(x: size * 0.39, y: size * 0.77))
                    path.addQuadCurve(
                        to: CGPoint(x: size * 0.61, y: size * 0.77),
                        control: CGPoint(x: size * 0.50, y: size * 0.91)
                    )
                }
                .stroke(
                    BarkPalette.ink.opacity(0.88),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

@MainActor
private enum BarkHeroLogoAsset {
    static let image: NSImage? = {
        guard let url = BarkResourceBundle.bundle?.url(forResource: "Bark", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}

private enum BarkPalette {
    static let canvas = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.96, blue: 0.94),
            Color(red: 0.93, green: 0.96, blue: 0.98),
            Color(red: 0.92, green: 0.97, blue: 0.94),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let toast = LinearGradient(
        colors: [
            Color.white.opacity(0.96),
            Color(red: 0.93, green: 0.96, blue: 0.99).opacity(0.98),
            Color(red: 0.93, green: 0.97, blue: 0.95).opacity(0.96),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let card = Color.white.opacity(0.76)
    static let panel = Color.white.opacity(0.88)
    static let activePanel = Color(red: 0.93, green: 0.97, blue: 1.0).opacity(0.95)
    static let console = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.23)
    static let subtleInk = Color(red: 0.34, green: 0.40, blue: 0.47)
    static let muted = Color(red: 0.47, green: 0.55, blue: 0.62)
    static let border = Color.white.opacity(0.68)
    static let accent = Color(red: 0.17, green: 0.49, blue: 0.86)
    static let sky = Color(red: 0.42, green: 0.67, blue: 0.94)
    static let mint = Color(red: 0.42, green: 0.79, blue: 0.65)
    static let peach = Color(red: 0.93, green: 0.64, blue: 0.39)
    static let indigo = Color(red: 0.44, green: 0.48, blue: 0.88)
    static let danger = Color(red: 0.86, green: 0.29, blue: 0.27)
}

private struct BarkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(BarkPalette.accent.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isEnabled ? 0.18 : 0.52), lineWidth: 1)
                    )
                    .shadow(color: BarkPalette.accent.opacity(isEnabled ? 0.22 : 0.06), radius: 14, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.92)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct BarkSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isEnabled ? BarkPalette.ink : BarkPalette.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.88 : 0.97) : 0.82))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isEnabled ? 0.98 : 0.92), lineWidth: 1)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(BarkPalette.ink.opacity(isEnabled ? 0.08 : 0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isEnabled ? (configuration.isPressed ? 0.04 : 0.08) : 0.03), radius: 12, x: 0, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.78)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct BarkDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(BarkPalette.danger.opacity(configuration.isPressed ? 0.82 : 1))
                    .shadow(color: BarkPalette.danger.opacity(0.18), radius: 12, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
