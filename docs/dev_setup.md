# BTChess - Development Setup

## Table of Contents

- [Prerequisites](#1-prerequisites)
- [Installation](#2-installation)
- [Code Generation](#3-code-generation)
- [Emulator Setup](#4-emulator-setup)
	- [Android Emulator](#41-android-emulator)
	- [iOS Simulator (macOS only)](#42-ios-simulator-macos-only)
- [Running the App](#5-running-the-app)
- [BLE Testing](#6-ble-testing)
	- [Android](#61-android)
	- [iOS](#62-ios)
- [Running Unit Tests](#7-running-unit-tests)

## 1. Prerequisites

- Flutter SDK 3.32.8
- Dart SDK (bundled with Flutter)
- Android Studio, or Xcode
- Physical Android or iOS devices for BLE testing

Verify your local Flutter SDK version and toolchains before installing dependencies:

```bash
flutter --version
flutter doctor
```

The output should show Flutter `3.32.8`, the bundled Dart SDK version, and the status of configured toolchains such as Android toolchain and Xcode.

## 2. Installation

```bash
git clone https://github.com/KaitoJD/btchess.git
cd btchess
flutter pub get
```

## 3. Code Generation

Hive type adapters require code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For development, use watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## 4. Emulator Setup

While BLE features require physical devices, you can use an emulator for general UI development and testing non-BLE features (e.g., hotseat mode, settings, board rendering).

### 4.1. Android Emulator

1. Open Android Studio and go to **Tools > Device Manager**.
2. Click **Create Virtual Device**.
3. Select a device profile (e.g., Pixel 7) and click **Next**.
4. Choose a system image with **API 21 or higher** (API 33+ recommended). Download it if needed, then click **Next**.
5. Adjust emulator settings if desired, then click **Finish**.
6. Launch the emulator from the Device Manager by clicking the play button.
7. Verify Flutter detects it:

```bash
flutter devices
```

### 4.2. iOS Simulator (macOS only)

1. Install Xcode from the Mac App Store.
2. Open Xcode and go to **Xcode > Settings > Platforms** to install the desired iOS simulator runtime.
3. Launch a simulator:

```bash
open -a Simulator
```

4. Verify Flutter detects it:

```bash
flutter devices
```

> **Note:** Emulators and simulators do **not** support BLE. Use them only for UI work and hotseat mode. BLE multiplayer testing requires two physical devices.

## 5. Running the App

```bash
# Run on connected device or emulator
flutter run

# Run in debug mode with verbose logging
flutter run --debug

# Build release APK
flutter build apk

# Build release iOS
flutter build ios
```

## 6. BLE Testing

BLE requires two physical devices. Emulators and simulators do not support BLE peripheral mode or scanning for real devices.

### 6.1. Android

Minimum SDK 21. The following permissions are declared in AndroidManifest.xml and requested at runtime:

- BLUETOOTH_SCAN (Android 12+)
- BLUETOOTH_CONNECT (Android 12+)
- BLUETOOTH_ADVERTISE (Android 12+)
- ACCESS_FINE_LOCATION (required for BLE scanning on Android < 12)

Enable Bluetooth and location services on the device before testing.

### 6.2. iOS

Minimum iOS 12.0. The following usage descriptions are in Info.plist:

- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription

The user will be prompted to allow Bluetooth access on first launch.

## 7. Running Unit Tests

```bash
# Unit tests
flutter test
```
