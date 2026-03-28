# BTChess - iOS Setup Guide (Without a macOS device)

## Table of Contents

- [Prerequisites](#1-prerequisites)
- [Prepare the IPA file](#2-prepare-the-ipa-file)
- [Setup Sideloadly](#3-setup-sideloadly)
- [Install BTChess](#4-install-btchess)
- [Grant app permissions in Settings](#5-grant-app-permissions-in-settings)
- [Notes](#6-notes)

## 1. Prerequisites

- An iOS device running iOS 12 or later
- An Apple account (iCloud, etc.) that you can access
- A Windows machine with GitHub CLI installed and signed in
- A USB cable to connect the iOS device to the Windows machine

## 2. Prepare the IPA file

> [!tip]
> If you have GitHub CLI installed and signed in, run the script `latest-ipa-getter.bat` (you can find the script in the [`scripts`](/scripts/) folder) where you want to create `btchess.ipa`. If the script finishes and you see `btchess.ipa`, continue to [Step 3: Setup Sideloadly](#3-setup-sideloadly).

If you want to try other builds of the app, follow the steps below.

### 2.1. Download the artifact

- [Go to the Actions tab on the repository main page](https://github.com/KaitoJD/btchess/actions/workflows/build_master.yml?query=is%3Asuccess)
- Select the `Build and Release` workflow run you want to download artifacts from
- _Under "Artifacts (Produced during runtime)" you will see two artifacts: `android-apk` and `ios-xcarchive`._ __Download the `ios-xcarchive` artifact.__

### 2.2. Create the IPA

> [!tip]
> Run the script `ipa-packager.bat` (you can find the script in the [`scripts`](/scripts/) folder) __after placing that script in the same folder as the `ios-xcarchive.zip` you downloaded.__ If the script runs successfully and produces `btchess.ipa`, proceed to [Step 3: Setup Sideloadly](#3-setup-sideloadly).

If the script fails or you don't get an `btchess.ipa`, create the IPA manually:

- Unzip `ios-xcarchive.zip` into a folder named `ios-xcarchive`
- Inside `ios-xcarchive`, unzip `Runner.xcarchive.tar.gz` into a folder named `Runner.xcarchive`
- Open `Runner.xcarchive` -> `Runner.xcarchive` -> `Products` -> `Applications`
- Create a new folder named `Payload` there
- Copy `Runner.app` into the `Payload` folder
- Zip the `Payload` folder as `Payload.zip` (use "Store" compression method)
- Rename `Payload.zip` to `btchess.ipa` (or any name with the `.ipa` extension)

## 3. Setup Sideloadly

- [Download the Sideloadly version suitable for your Windows machine.](https://sideloadly.io/#download)

> [!important]
> _Note: According to Sideloadly, you should install the desktop (non-Microsoft-Store) versions of iTunes and iCloud. If you have the Microsoft Store versions installed, uninstall them first. Then install the appropriate iTunes and iCloud installers linked below._
> - [iTunes x64](https://www.apple.com/itunes/download/win64) - [iTunes x32](https://www.apple.com/itunes/download/win32)
> - [iCloud](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe)

- When installing iTunes and iCloud, the apps will ask you to sign in to the iTunes Store and iCloud - use your Apple ID for that.

_You may need to restart your computer after installation completes._

## 4. Install BTChess

- Launch Sideloadly, connect your iOS device to the Windows machine with the USB cable
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

_If the app still errors or requests "Developer Mode" after trusting the developer, enable Developer Mode:_

- Open __Settings__ -> __Privacy & Security__
- Scroll to the bottom and find __Developer Mode__
- Toggle Developer Mode __on__
- The iPhone will ask you to restart - restart the device
- After reboot, a prompt will ask to enable Developer Mode; choose __Turn On__ and enter your device passcode if requested

## 6. Notes

- __7-day expiration__: Using a free personal Apple account means the signing certificate is valid for 7 days. After 7 days the app may crash on launch. To renew, connect the device to your computer and press "Start" in Sideloadly again - app data will be preserved.

If you need help or want to discuss, open a thread in the repository [Discussions](https://github.com/KaitoJD/btchess/discussions)
