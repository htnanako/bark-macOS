# Bark macOS Client

[简体中文](./README_zh.md) | English

`bark-macos` is a macOS menu bar client for receiving Bark push notifications, designed for individuals and teams using a self-hosted Bark server.

## Features

- Runs in the macOS menu bar
- Connects to a custom Bark server
- Receives and displays push notifications
- Supports initial device registration and generates the device identifier
- Works as a desktop receiver for self-hosted Bark deployments

## Tech Stack

- Swift
- SwiftUI
- macOS AppKit / UserNotifications system capabilities
- Swift Package Manager
- CryptoSwift

## Before You Start

This client must be used with a self-hosted Bark server.

- Server repository: [`https://github.com/htnanako/bark-server`](https://github.com/htnanako/bark-server)
- Available image: `htnanako/bark-server`
- Available image: `ghcr.io/htnanako/bark-server`
- There is no public server
- The official Bark server cannot be used

If you have not deployed your server yet, please complete the server setup and confirm the server URL is reachable before installing the client.

## Installation

1. Download the `.dmg` package for your CPU architecture from the Release page.
2. Open the downloaded `.dmg`.
3. Move `BarkMac.app` into the `Applications` folder.
4. Open the app from the `Applications` folder.

If macOS shows a security prompt, allow the app to open using the standard macOS confirmation flow.

## First-Time Setup

After launching the app for the first time, complete the following steps:

1. Enter your own Bark server URL.
2. Save the configuration and run a connection test to confirm the server is reachable.
3. Manually register the device.

After registration, the app will generate the receiver information for the current device. You can then use that device identifier to send pushes to this Mac.

## Recommended Workflow

1. Deploy and verify your self-hosted Bark server.
2. Install the macOS client.
3. Configure your custom server URL.
4. Run the connection test.
5. Manually register the current device.
6. Send a test push using the registered device information.

## Usage Notes

- If you change the server address, it is recommended to test the connection again and verify the current device registration status.
- If notifications stop arriving, first check whether the server is running normally and whether the configured server URL is correct.
- It is recommended to connect only to servers you deploy and trust.

## About Official Bark

Official Bark is an iPhone push notification app. Its project repository is [`Finb/Bark`](https://github.com/Finb/Bark), and its documentation is available at [`https://bark.day.app/`](https://bark.day.app/).

This project is a community macOS client focused on self-hosted Bark server usage, making it possible to receive Bark pushes on Mac.

- This project is not the official Bark client
- This project does not provide the official Bark public service
- This project is not a replacement for the official Bark iPhone client
- This project and official Bark have different product positioning, so please refer to their respective documentation and release notes

If you already use official Bark, you can treat `bark-macos` as a macOS companion client for self-hosted Bark setups.

## Acknowledgements

Thanks to the official Bark project for its product ideas, interaction design, and documentation, which helped establish a clear understanding of the Bark notification ecosystem.

Thanks to the self-hosted Bark server efforts and related maintenance work that make Bark usable and extensible in private deployment scenarios.

Thanks to everyone who helped with deployment, testing, feedback, and improvement suggestions.

## Updates

For future versions, continue downloading the latest `.dmg` package for your architecture from the Release page.
