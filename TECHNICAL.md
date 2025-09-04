# 🔧 BTChess Technical Documentation

## 🏗️ Technical Architecture

### Core Technologies
- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **Material 3**: Modern design system
- **Google Fonts**: Typography

### Bluetooth Stack
- **Classic Bluetooth**: `flutter_bluetooth_serial` (Android/Linux)
- **BLE**: `flutter_blue_plus` (iOS/macOS/Windows)
- **Platform Detection**: `universal_platform`
- **Unified Interface**: Custom abstraction layer

### Chess Engine
- **Complete Rule Implementation**: All standard chess rules
- **Move Validation**: Legal move checking with king safety
- **Game State Management**: Check, checkmate, stalemate detection
- **Move History**: Full game recording with replay capability

## 🔨 Development

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── models/                      # Chess piece, position, move models
│   ├── chess_piece.dart        # Chess piece definitions
│   ├── position.dart           # Board position utilities
│   └── move.dart               # Move representation
├── services/                    # Chess engine & Bluetooth services
│   ├── platform_bluetooth_service.dart # Bluetooth connectivity
│   └── chess_game.dart         # Chess game logic
├── providers/                   # State management
│   └── game_provider.dart      # Game state and move management
├── screens/                     # UI screens
│   ├── menu_screen.dart        # Main menu
│   ├── bluetooth_connection_screen.dart # Connection setup
│   └── game_screen.dart        # Game interface
└── widgets/                     # Reusable UI components
    └── chess_board_widget.dart # Chess board display
```

### Key Services
- **PlatformBluetoothService**: Unified Bluetooth abstraction
- **ChessBoard**: Complete chess game engine
- **GameProvider**: Game state and move management

## Dependencies

Key Flutter packages used:
- `flutter_bluetooth_serial`: Bluetooth connectivity (Android/Linux)
- `flutter_blue_plus`: BLE connectivity (iOS/macOS/Windows)
- `permission_handler`: Runtime permission management
- `provider`: State management
- `google_fonts`: Typography
- `universal_platform`: Platform detection

## Technical Implementation Details

### Chess Engine
- Complete implementation of chess rules
- Move validation and game state management
- Check, checkmate, and stalemate detection
- Special moves: castling, en passant, pawn promotion

### Bluetooth Implementation
- Device discovery and pairing
- Reliable message transmission
- Connection state management
- Error handling and recovery

### State Management
- Provider pattern for reactive state updates
- Separation of concerns between UI and business logic
- Efficient board state synchronization

## Permissions

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
