# 🚀 BTChess Installation Guide

This guide will help you set up and run BTChess on your preferred platform.

## Prerequisites

- **Flutter SDK 3.9+** installed
- Platform-specific development tools:
  - **Android**: Android SDK, licensed NDK
  - **iOS**: Xcode (macOS only)
  - **Linux**: Standard development tools
  - **macOS**: Xcode command line tools
  - **Windows**: Visual Studio with C++ tools

## System Requirements

### For Android:
- Android 5.0 (API level 21) or higher
- Bluetooth capability
- Location permissions (required for Bluetooth scanning)

### For Linux Desktop:
- Ubuntu 18.04 or later (or equivalent Linux distribution)
- Bluetooth capability
- Flutter Linux desktop dependencies

### For iOS:
- iOS 9.0 or later
- Bluetooth capability

### For macOS:
- macOS 10.11 or later
- Bluetooth capability

### For Windows:
- Windows 10 or later
- Bluetooth capability

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd btchess
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Platform Setup

#### Android Setup
1. Install Android SDK and accept licenses
2. Connect an Android device or set up an emulator
3. Enable Developer Options and USB Debugging on your device

#### Linux Desktop Setup
```bash
flutter config --enable-linux-desktop
```

#### iOS Setup (macOS only)
1. Install Xcode from the App Store
2. Open Xcode and accept license agreements
3. Set up iOS Simulator or connect an iOS device

#### macOS Setup
```bash
flutter config --enable-macos-desktop
```

#### Windows Setup
1. Install Visual Studio with C++ build tools
2. Enable Windows desktop development:
```bash
flutter config --enable-windows-desktop
```

## Running the Application

### Quick Start
```bash
# Quick start (defaults to current platform)
./run.sh
```

### Platform-Specific Commands

#### Android
```bash
# Debug build
flutter run

# Release build
./run.sh build android release
flutter build apk --release
```

#### Linux Desktop
```bash
# Debug build
flutter run -d linux

# Release build
./run.sh build linux release
flutter build linux --release
```

#### iOS (macOS only)
```bash
# Debug build
flutter run -d ios

# Release build
./run.sh build ios release
flutter build ios --release
```

#### macOS (macOS only)
```bash
# Debug build
flutter run -d macos

# Release build
./run.sh build macos release
flutter build macos --release
```

#### Windows
```bash
# Debug build
flutter run -d windows

# Release build
./run.sh build windows release
flutter build windows --release
```

## Build Commands Reference

The project includes a convenient `run.sh` script for building across platforms:

```bash
# Platform-specific builds
./run.sh build android    # Build Android APK
./run.sh build ios        # Build iOS app
./run.sh build linux      # Build Linux executable
./run.sh build macos      # Build macOS app
./run.sh build windows    # Build Windows executable

# Debug vs Release builds
./run.sh build android debug    # Debug build
./run.sh build android release  # Release build
```

## Permissions Setup

### Android Permissions
The app requires the following permissions (automatically requested at runtime):
- `BLUETOOTH` - Basic Bluetooth functionality
- `BLUETOOTH_ADMIN` - Bluetooth device management
- `BLUETOOTH_SCAN` - Scan for nearby devices (Android 12+)
- `BLUETOOTH_CONNECT` - Connect to devices (Android 12+)
- `BLUETOOTH_ADVERTISE` - Make device discoverable (Android 12+)
- `ACCESS_COARSE_LOCATION` - Required for Bluetooth scanning
- `ACCESS_FINE_LOCATION` - Enhanced location access

### iOS/macOS Permissions
- Bluetooth usage permissions (automatically requested)

### Linux/Windows
- Bluetooth access (may require running with appropriate privileges)

## Dependencies

The project uses these key Flutter packages:
- `flutter_bluetooth_serial`: Bluetooth connectivity (Android/Linux)
- `flutter_blue_plus`: BLE connectivity (iOS/macOS/Windows)
- `permission_handler`: Runtime permission management
- `provider`: State management
- `google_fonts`: Typography
- `universal_platform`: Platform detection

## Troubleshooting

### Common Build Issues

1. **Flutter SDK issues:**
   ```bash
   flutter doctor
   flutter clean
   flutter pub get
   ```

2. **Platform-specific issues:**
   - **Android**: Ensure Android SDK is properly installed and licenses accepted
   - **iOS**: Make sure Xcode is up to date and licenses accepted
   - **Linux**: Install required development packages
   - **Windows**: Ensure Visual Studio with C++ tools is installed

3. **Dependency issues:**
   ```bash
   flutter pub cache repair
   flutter pub get
   ```

### Development Tips

1. **Testing Bluetooth functionality:**
   - Requires physical devices (emulators don't support Bluetooth)
   - Use two physical devices for complete testing

2. **Debugging:**
   ```bash
   flutter logs          # View runtime logs
   flutter analyze       # Static analysis
   flutter test          # Run tests
   flutter doctor        # Check setup issues
   ```

3. **Performance profiling:**
   ```bash
   flutter run --profile  # Profile mode
   ```

## Development Environment

### Recommended VS Code Extensions
- Flutter
- Dart
- Flutter Intl
- Bracket Pair Colorizer

### Recommended Android Studio Plugins
- Flutter
- Dart

## First Run Setup

1. **Enable Bluetooth** on your device
2. **Grant permissions** when prompted
3. **Test connectivity** by running the app on two devices
4. **Host a game** on one device and **join** from another

## Next Steps

After successful installation, refer to the main [README.md](README.md) for:
- How to play the game
- Game features and controls
- Technical architecture details
- Contributing guidelines

For issues during installation, check the troubleshooting section or create an issue in the repository.
