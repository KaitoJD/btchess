# BTChess - iOS Install Guide

> [!note]
>
> __The process of installing BTChess on iOS devices can be complex and time-consuming.__

## Table of Contents

- [Prerequisites](#1-prerequisites)
- [Download the IPA file](#2-download-the-ipa-file)
- [Install Sideloadly](#3-install-sideloadly)
- [Install BTChess](#4-install-btchess)
- [Grant app permissions in Settings](#5-grant-app-permissions-in-settings)

## 1. Prerequisites

- An iOS device running iOS 13 or later
- An [Apple Account](https://support.apple.com/en-us/108647?device-type=iphone) that you can access
- A Windows/macOS machine
- A USB cable to connect the iOS device to the Windows/macOS machine

## 2. Download the IPA file

[Click here to download the latest released IPA file](https://github.com/KaitoJD/btchess/releases/download/v1.0.0-beta.1/btchess_1.0.0-beta.1.ipa)

## 3. Install Sideloadly

- [Download Sideloadly](https://sideloadly.io/#download)
- Open the Sideloadly setup file and follow the setup wizard.
- _Please make sure that you have your Apple account signed in iTunes and iCloud_

> [!important]
>
> ___Note for Windows users__: According to Sideloadly, you should install the desktop (non-Microsoft-Store) versions of iTunes and iCloud. If you have the Microsoft Store versions installed, uninstall them first. Then install the appropriate iTunes and iCloud installers linked below._
> - [iTunes x64](https://www.apple.com/itunes/download/win64) - [iTunes x32](https://www.apple.com/itunes/download/win32)
> - [iCloud](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe)

## 4. Install BTChess

- Launch Sideloadly, connect your iOS device to the Windows/macOS machine with the USB cable
- Enter your Apple ID in the `Apple ID` field
- Click the IPA icon and select the IPA file you prepared
- Click **Start** and wait for installation to finish

## 5. Grant app permissions in Settings

_The steps below were tested on iOS 18.7.2; UI locations may differ on other iOS versions._

### 5.1. Trust the Developer

- Open __Settings__ on the iPhone
- Go to __General__
- Scroll down and open __VPN & Device Management__ (on older iOS versions this may be shown as __Device Management__ or __Profiles & Device Management__)
- Under "Developer App" you will see the Apple ID email you entered into Sideloadly - tap it
- Tap the blue text that says __Trust [your email]__
- In the confirmation dialog, tap __Trust__ again

### 5.2. Enable Developer Mode

_If the app still errors or requests "Developer Mode", enable Developer Mode:_

- Open __Settings__ -> __Privacy & Security__
- Scroll to the bottom and find __Developer Mode__
- Toggle Developer Mode __on__
- The iPhone will ask you to restart - restart the device
- After reboot, a prompt will ask to enable Developer Mode; choose __Turn On__ and enter your device passcode if requested

#

> [!note]
>
> __After 7 days the app may crash on launch. To renew, connect the device to your computer and press "Start" in Sideloadly again - app data will be preserved.__

If you need help or want to discuss, open a thread in the repository [Discussions](https://github.com/KaitoJD/btchess/discussions)
