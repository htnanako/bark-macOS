# Bark macOS Client

简体中文 | [English](./README.md)

`bark-macos` 是一个用于接收 Bark 推送的 macOS 菜单栏客户端，适合自建 Bark 服务端的个人或团队使用。

## 功能简介

- 在 macOS 菜单栏中常驻运行
- 连接自定义 Bark 服务端
- 接收并展示推送通知
- 支持首次注册设备并生成当前设备的接收标识
- 适合作为自建 Bark 推送体系的桌面接收端

## 技术栈

- Swift
- SwiftUI
- macOS AppKit / UserNotifications 系统能力
- Swift Package Manager
- CryptoSwift

## 使用前说明

本客户端必须配合自建服务端使用。

- 服务端仓库：[`https://github.com/htnanako/bark-server`](https://github.com/htnanako/bark-server)
- 可用镜像：`htnanako/bark-server`
- 可用镜像：`ghcr.io/htnanako/bark-server`
- 没有公用服务端
- 不可使用 Bark 官方服务器

如果你还没有部署服务端，请先完成服务端部署并确认访问地址可用，再继续安装客户端。

## 安装

1. 从 Release 页面下载与你设备架构对应的 `.dmg` 安装包。
2. 打开下载后的 `.dmg`。
3. 将 `BarkMac.app` 拖动或移动到 `Applications` 文件夹。
4. 前往 `Applications` 文件夹打开应用。

如果系统提示安全确认，请按 macOS 的常规方式允许应用打开。

## 首次配置

首次启动后，请先完成以下配置：

1. 填写你自己的 Bark 服务端 URL。
2. 保存后先执行一次连接测试，确认服务地址可访问。
3. 手动执行设备注册。

设备注册完成后，应用会为当前设备生成对应的接收信息。后续你可以使用该设备的标识向这台 Mac 发送推送。

## 推荐使用流程

1. 先部署并确认自建服务端可正常访问。
2. 安装 macOS 客户端。
3. 配置自定义服务器 URL。
4. 执行测试连接。
5. 手动注册当前设备。
6. 使用注册后的设备信息进行推送测试。

## 使用提示

- 如果你修改了服务端地址，建议重新测试连接并重新确认当前设备注册状态。
- 如果长时间没有收到通知，请优先检查服务端是否正常运行，以及当前配置的服务器 URL 是否填写正确。
- 建议只连接你自己部署和信任的服务端。

## 关于官方 Bark

官方 Bark 是一个面向 iPhone 的推送通知应用，项目地址为 [`Finb/Bark`](https://github.com/Finb/Bark)，相关说明文档可参考 [`https://bark.day.app/`](https://bark.day.app/)。

本项目是一个面向 macOS 的社区客户端，主要服务于自建 Bark 服务端的使用场景，用于在 Mac 上接收 Bark 推送。

- 本项目不是官方 Bark 客户端
- 本项目不提供官方 Bark 公共服务
- 本项目不能直接替代官方 Bark iPhone 客户端
- 本项目与官方 Bark 的定位不同，请分别参考各自的说明文档和发布内容

如果你已经在使用官方 Bark，可以把 `bark-macos` 理解为自建 Bark 体系下的 macOS 补充客户端。

## 鸣谢

感谢官方 Bark 项目提供了优秀的产品思路、交互体验与使用文档，也为 Bark 推送生态建立了清晰的基础认知。

感谢自建 Bark 服务端相关项目与维护工作，让 Bark 能够在私有化、自部署场景中持续使用与扩展。

感谢所有参与部署、测试、反馈和改进建议的使用者。

## 获取更新

后续版本请继续通过 Release 页面下载对应架构的最新 `.dmg` 安装包进行更新。
