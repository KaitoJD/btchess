# BTChess

A mobile chess app for Android and iOS with local multiplayer via Bluetooth Low Energy.

## Features

- **Hotseat Mode** – Two players, one device. Take turns on the same screen.
- **Bluetooth Multiplayer** – Play against a friend on another phone over BLE.
- **Full Chess Rules** – Legal move validation, check/checkmate, castling, en passant, pawn promotion, and draw conditions.
- **Offline First** – No internet required. Games are saved locally.
- **Game History** – Resume in-progress games or review past matches.

## Tech Stack

- **Flutter** – Cross-platform UI framework
- **Riverpod** – State management
- **dartchess** – Chess rules engine
- **flutter_blue_plus** – Bluetooth Low Energy communication
- **Hive** – Local persistence

## Getting Started

### Prerequisites

- Flutter SDK (3.x or later)
- Android Studio / Xcode for device builds
- Physical devices recommended for BLE testing

### Installation

```bash
# Clone the repository
git clone https://github.com/KaitoJD/btchess.git
cd btchess

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
├── domain/          # Core models, chess logic, value objects
├── application/     # Controllers, providers, state management
├── presentation/    # Screens, widgets, themes
└── infrastructure/  # BLE communication, persistence
```

## Documentation

See the [docs/](docs/) folder for detailed documentation:

- [Architecture](docs/architecture.md)
- [BLE Protocol](docs/binary_protocol.md)
- [Development Setup](docs/dev_setup.md)
- [Troubleshooting](docs/troubleshooting.md)

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).  
You are free to share and adapt the material for non-commercial purposes, as long as you give appropriate credit and distribute your contributions under the same license.  
See the [LICENSE](./LICENSE) file for details.
