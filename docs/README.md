_This folder is the technical entry point for contributors. Use it to understand architecture boundaries, local development workflow, BLE protocol constraints, and common failure modes._

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

## Documentation

See the [docs/](docs/) folder for detailed documentation:

- [Development Setup](docs/dev_setup.md)
- [_(Optional) iOS Setup_](/docs/ios_setup.md)
- [Architecture](docs/architecture.md)
- [BLE Protocol](docs/binary_protocol.md)
- [Troubleshooting](docs/troubleshooting.md)

## Contributing

Thank you for your interest in contributing to this project! See [CONTRIBUTING](/CONTRIBUTING.md) to understand a basic workflow to help you submit changes (pull requests) smoothly.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).

See the [LICENSE](./LICENSE) file for details.
