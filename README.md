# ♟️ BTChess - Multi-Platform Bluetooth Chess

A beautiful, cross-platform chess game that allows two players on different devices to compete via Bluetooth connectivity. Built with Flutter for seamless gameplay across Android, iOS, Linux, macOS, and Windows.

## Features

- **Full Chess Implementation**: Complete rule set including castling, en passant, and pawn promotion
- **Multi-Platform Support**: Android, iOS, Linux, macOS, Windows
- **Bluetooth Connectivity**: Classic Bluetooth (Android/Linux) and BLE (iOS/macOS/Windows)
- **Modern UI**: Material Design 3 with beautiful animations
- **Real-time Gameplay**: Instant move synchronization between devices
- **Intuitive Controls**: Tap to select and move pieces
- **Game Management**: Resign, draw offers, and automatic game end detection

## Quick Start

```bash
git clone https://github.com/KaitoJD/btchess.git
cd btchess
flutter pub get
./run.sh  # Runs on current platform
```

For detailed installation instructions, platform setup, and build commands, see **[INSTALLATION.md](INSTALLATION.md)**.

##  Platform Support Matrix

| Platform | Bluetooth Type | Status | Build Command |
|----------|----------------|--------|---------------|
| Android  | Classic BT     | Full | `./run.sh build android` |
| Linux    | Classic BT     | Full | `./run.sh build linux` |
| iOS      | BLE            | Full | `./run.sh build ios` |
| macOS    | BLE            | Full | `./run.sh build macos` |
| Windows  | BLE            | Full | `./run.sh build windows` |

## Documentation

- **[Gameplay Guide](GAMEPLAY.md)** - Learn how to play, game controls, and UI features
- **[Installation Guide](INSTALLATION.md)** - Setup instructions for all platforms
- **[Technical Documentation](TECHNICAL.md)** - Architecture, dependencies, and development details
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## Platform-Specific Features

### Android & Linux
- **Classic Bluetooth**: Uses traditional Bluetooth Serial Port Profile
- **Device Scanning**: Automatic discovery of paired and nearby devices
- **Robust Connection**: Established Serial Port communication

### iOS, macOS & Windows
- **Bluetooth Low Energy (BLE)**: Modern, energy-efficient communication
- **Service Discovery**: Custom chess service UUID for device identification
- **Notification-based**: Real-time data exchange via BLE characteristics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on multiple platforms
5. Submit a pull request

For detailed development information, see [TECHNICAL.md](TECHNICAL.md).

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).  
You are free to share and adapt the material for non-commercial purposes, as long as you give appropriate credit and distribute your contributions under the same license.  
See the [LICENSE](./LICENSE) file for details.
