# BTChess -- Architecture

BTChess uses a 4-layer architecture. Each layer has strict dependency rules to keep the codebase maintainable.


## Layers

**core/** -- Shared constants, utilities, error types, extensions. Pure Dart, no dependencies on other layers. Contains BLE protocol constants (UUIDs, message types, error codes, timing), binary helpers, and the Result type.

**domain/** -- Business logic. Chess rules (via dartchess), models (GameState, Move, Square, Piece, Player), enums (GameStatus, GameEndReason, Winner), and services (ChessService, FenService, PgnService, MoveValidator). No Flutter imports, no infrastructure imports.

**application/** -- State management with Riverpod. Controllers (StateNotifiers) for game, bluetooth, lobby, board, and settings. Providers wire controllers to the rest of the app. States are immutable data classes. This layer coordinates between domain and infrastructure.

**presentation/** -- Flutter UI. Screens (8 total), widgets (board, game info, lobby, dialogs, common), themes (app, board, piece), and routing. Only imports from application/ and domain/, never directly from infrastructure/.

**infrastructure/** -- External service implementations. BLE transport (flutter_blue_plus, ble_peripheral), persistence (Hive, SharedPreferences), and audio. Imports from domain/ and core/ only.

### Dependency Rules

| Layer | Can import | Cannot import |
|---|---|---|
| core | Dart SDK only | domain, application, presentation, infrastructure |
| domain | core, dartchess | application, presentation, infrastructure, Flutter SDK |
| application | domain, infrastructure, core | presentation |
| presentation | application, domain, core | infrastructure (directly) |
| infrastructure | domain, core, external packages | application, presentation |


## State Management

Riverpod providers connect the layers:

- `servicesProvider` -- ChessService, FenService, PgnService
- `gameProvider` -- GameController (StateNotifier\<GameState\>), computed state
- `boardProvider` -- BoardController, selection, flip
- `bluetoothProvider` -- BluetoothService, ConnectionManager, BluetoothState, scanned devices, permissions
- `settingsProvider` -- SettingsController (SharedPreferences-backed)
- `persistenceProvider` -- GameRepository (Hive-backed), saved games list

GameController is the central game loop. In hotseat mode it drives everything locally. In BLE mode, BluetoothController mediates between GameController and the BLE transport layer.


## BLE Multiplayer Data Flow

### Roles

- **Host** -- Creates the lobby, runs a GATT server (BlePeripheralManager), validates all moves, maintains canonical game state. The host is authoritative.
- **Client** -- Joins the lobby, connects to the host's GATT server, sends moves for validation, applies state only after receiving an ACK.

### Connection Setup

1. Host calls `BluetoothController.createLobby()`.
2. `BluetoothService.startAdvertising()` starts the GATT server via `BlePeripheralManager` with the Chess Game Service UUID.
3. Client calls `BluetoothController.startScanning()`.
4. `BluetoothService.startScanning()` filters for the service UUID.
5. Client selects a device, calls `BluetoothController.joinGame(device)`.
6. `BluetoothService.connect()` returns a `BleConnection` (implements `BleTransport`).
7. `ConnectionManager.setupConnection()` performs the HANDSHAKE exchange.
8. On success, both sides transition to `connected` state and the game begins.

### Move Flow (Client to Host)

1. Client taps a move on the board.
2. `BluetoothController.sendMove(move)` encodes a `MoveMessage` (6 bytes: type + msg_id + from + to + promo).
3. `ConnectionManager.sendMove()` writes to the MOVE characteristic (Write With Response) and starts a 3000 ms ACK timer.
4. Host's `BlePeripheralManager` receives the write, decodes via `MessageCodec`, and delivers to `ConnectionManager.messages`.
5. `BluetoothController._handleIncomingMove()` validates the move via `GameController.makeMove()`.
6. Host sends an `AckMessage` (5 bytes) via the STATE_NOTIFY characteristic.
7. Client's `ConnectionManager` receives the ACK. If OK, `BluetoothController` calls `GameController.applyRemoteMove()`. If ERROR, the client shows the error.
8. No optimistic UI updates -- the client board stays locked until ACK arrives.

### Draw / Resign / Game End

- Draw: player sends DRAW_OFFER (3 bytes) via CONTROL. Opponent receives it, shows dialog, sends DRAW_RESPONSE (4 bytes). If accepted, host sends GAME_END with reason DRAW_AGREEMENT.
- Resign: player sends RESIGN (3 bytes). Host sends GAME_END with reason RESIGN.
- Checkmate/stalemate: host detects the condition after applying a move, sends GAME_END with the appropriate reason and winner.

### Reconnection

1. Client detects BLE disconnect, transitions to `reconnecting` state.
2. Auto-reconnect attempt to the same device.
3. On reconnect: re-send HANDSHAKE, then SYNC_REQUEST.
4. Host responds with SYNC_RESPONSE (chunked if payload exceeds MTU).
5. Client calls `GameController.syncState()` to restore the board and resumes play.

### Reliability Stack

The infrastructure layer provides several reliability mechanisms:

- **MessageCodec** -- Binary encode/decode for all 11 message types.
- **ConnectionManager** -- Handshake state machine, ACK tracking with 3000 ms timeout, 2 retries with 500/1000 ms backoff, ping/pong keepalive (15 s interval, 30 s disconnect), dedupe cache (last 100 msg_ids).
- **ChunkHandler** -- Splits large payloads (FEN/PGN) into MTU-sized chunks, reassembles with 10 s timeout.
- **MessageQueue** -- Priority queue (high/normal/low), max 100 messages.
- **RateLimiter** -- MOVE 2/s, DRAW_OFFER 1/30 s, SYNC_REQUEST 1/5 s.


## Persistence

Games are saved to Hive after each move. `GameRepository` handles CRUD with auto-cleanup at 100 saved games (oldest completed games removed first). `SavedGame` stores: id, FEN, move history (SAN), timestamps, mode, result, opponent name. Settings are stored in SharedPreferences via `SettingsRepository`.


## Screens and Navigation

8 routes with guards:

| Screen | Route | Purpose |
|---|---|---|
| Home | / | Main menu |
| Mode Selection | /mode | Choose hotseat or BLE, host/join |
| Lobby | /lobby | Host waiting or client scanning |
| Game | /game | Active chess game |
| Game Over | /game-over | Result display, rematch |
| Game History | /history | Saved and completed games |
| Settings | /settings | App preferences |
| PGN Viewer | /pgn | View/copy/share PGN |

Route guards enforce BLE permissions before entering the lobby screen and prevent navigation away from an active game without confirmation.
