import Foundation

enum AppTab: String, CaseIterable, Codable, Identifiable {
    case overview
    case server
    case device
    case records

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .overview:
            return "Home"
        case .server:
            return "Server"
        case .device:
            return "Device"
        case .records:
            return "Records"
        }
    }

    var title: String {
        switch self {
        case .overview:
            return "首页状态"
        case .server:
            return "服务端配置"
        case .device:
            return "设备注册"
        case .records:
            return "记录"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "集中查看当前连接状态、最近消息与关键结果，快速了解 Bark 在 Mac 上的运行情况。"
        case .server:
            return "管理服务器地址并检查连接状态，确保消息服务可用、信息同步正常。"
        case .device:
            return "按照清晰的步骤完成设备授权、注册与连接，让接收通知的准备过程一目了然。"
        case .records:
            return "查看历史消息与通知详情，随时回顾重要内容，并快速复制所需信息。"
        }
    }
}
