# BTChess -- Development Setup

## Prerequisites

- Flutter SDK 3.x or later
- Dart SDK (bundled with Flutter)
- Android Studio (for Android builds) or Xcode (for iOS builds)
- Physical Android or iOS devices for BLE testing (BLE does not work on emulators)

## Installation

```bash
git clone https://github.com/KaitoJD/btchess.git
```
```bash
cd btchess
```
```bash
flutter pub get
```

## Emulator Setup

While BLE features require physical devices, you can use an emulator for general UI development and testing non-BLE features (e.g., hotseat mode, settings, board rendering).

### Android Emulator

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

### iOS Simulator (macOS only)

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

> **Note:** Emulators and simulators do **not** support BLE. Use them only for UI work and hotseat mode. BLE multiplayer testing requires two physical devices — see the [BLE Testing](#ble-testing) section.

## Running the App

```bash
# Run on connected device or emulator
flutter run
```

```bash
# Run in debug mode with verbose logging
flutter run --debug
```

```bash
# Build release APK
flutter build apk
```

```bash
# Build release iOS
flutter build ios
```

## BLE Testing

BLE requires two physical devices. Emulators and simulators do not support BLE peripheral mode or scanning for real devices.

### Android

Minimum SDK 21. The following permissions are declared in AndroidManifest.xml and requested at runtime:

- BLUETOOTH_SCAN (Android 12+)
- BLUETOOTH_CONNECT (Android 12+)
- BLUETOOTH_ADVERTISE (Android 12+)
- ACCESS_FINE_LOCATION (required for BLE scanning on Android < 12)

Enable Bluetooth and location services on the device before testing.

### iOS

Minimum iOS 12.0. The following usage descriptions are in Info.plist:

- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription

The user will be prompted to allow Bluetooth access on first launch.

### Testing Procedure

1. Install the app on two devices.
2. On device A, select Bluetooth mode and create a lobby (host).
3. On device B, select Bluetooth mode and join (client). The host should appear in the scan list.
4. Tap the host entry to connect. The handshake completes automatically.
5. Play a game. Verify moves, resign, and draw flows all work.
6. To test reconnection: toggle Bluetooth off on the client device, then back on. The client should auto-reconnect and sync state.

## Code Generation

Hive type adapters require code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For development, use watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Running Tests

```bash
# Unit tests
flutter test
```
