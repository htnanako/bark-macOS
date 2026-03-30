import SwiftUI

@main
struct BarkMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: model)
                .preferredColorScheme(.light)
                .onAppear {
                    appDelegate.attach(model: model)
                    model.restoreSessionIfNeeded()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 820)

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image(nsImage: BarkStatusBarIcon.makeImage())
        }
    }
}

private struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("打开主窗口") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(model.streamStatus == "已连接" ? "断开事件流" : "连接事件流") {
                if model.streamStatus == "已连接" {
                    model.disconnectEventStream()
                } else {
                    model.connectEventStream()
                }
            }
            .disabled(model.configuration.deviceKey.isEmpty || model.configuration.streamToken.isEmpty)

            Button("测试本地通知") {
                model.sendTestLocalNotification()
            }

            Divider()

            LabeledContent("SSE", value: model.streamStatus)
            LabeledContent("通知", value: model.notificationStatus)

            Divider()

            Button("退出 Bark") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            model.restoreSessionIfNeeded()
        }
    }
}
