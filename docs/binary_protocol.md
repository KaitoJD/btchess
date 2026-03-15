# BTChess Binary Protocol

Binary message format for BLE communication between two BTChess devices. Protocol version: `0x01`.

The protocol is host-authoritative: the host validates all moves and maintains the canonical game state. Messages are designed to fit within BLE's default MTU (23 bytes ATT, ~20 bytes usable payload). Each message carries a `msg_id` for deduplication and ACK correlation.

Lobby start is host-initiated: host sends `GAME_START` to the client, client ACKs it, then both devices transition into the game screen.


## GATT Service Layout

| Component | UUID | Properties |
|---|---|---|
| Chess Game Service | `0000c0de-0000-1000-8000-00805f9b34fb` | -- |
| MOVE (client to host) | `0000c0de-0001-1000-8000-00805f9b34fb` | Write With Response |
| STATE_NOTIFY (host to client) | `0000c0de-0002-1000-8000-00805f9b34fb` | Notify |
| CONTROL (bi-directional) | `0000c0de-0003-1000-8000-00805f9b34fb` | Write, Notify |


## Message Types

| Code | Name | Direction | Size (bytes) |
|---|---|---|---|
| `0x00` | HANDSHAKE | Bi-directional | 6 |
| `0x01` | MOVE | Client to Host | 6 |
| `0x02` | ACK | Bi-directional | 5 |
| `0x03` | SYNC_REQUEST | Client to Host | 3 |
| `0x04` | SYNC_RESPONSE | Host to Client | 5 + payload |
| `0x05` | CHUNK | Host to Client | 5 + payload |
| `0x06` | GAME_END | Host to Client | 5 |
| `0x07` | DRAW_OFFER | Bi-directional | 3 |
| `0x08` | DRAW_RESPONSE | Bi-directional | 4 |
| `0x09` | RESIGN | Client to Host | 3 |
| `0x0A` | PING | Bi-directional | 7 |
| `0x0B` | PONG | Bi-directional | 7 |
| `0x0C` | GAME_START | Host to Client | 3 |


## Message Headers

Standard header (3 bytes): `msg_type` (1) + `msg_id` (2, big-endian).

Chunked header (5 bytes): standard header + `seq` (1, 1-indexed) + `total` (1, chunk count).


## Message Specifications

### HANDSHAKE (0x00) -- 6 bytes

Sent immediately after BLE connection is established.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x00` |
| 1-2 | msg_id | uint16, big-endian |
| 3 | protocol_version | `0x01` |
| 4 | role | `0x01` = HOST, `0x02` = CLIENT |
| 5 | host_color | `0x00` = unspecified, `0x01` = white, `0x02` = black |

Flow:

1. Client sends HANDSHAKE with `role=CLIENT`, `host_color=0x00`.
2. Host validates protocol version.
3. If compatible: host replies with HANDSHAKE `role=HOST` and its selected `host_color`.
4. If incompatible: host sends ACK with `error_code=0x10` and disconnects.

### MOVE (0x01) -- 6 bytes

Client sends a chess move to the host for validation.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x01` |
| 1-2 | msg_id | uint16, big-endian |
| 3 | from | Source square index (0-63) |
| 4 | to | Destination square index (0-63) |
| 5 | promo | `0`=none, `1`=Queen, `2`=Rook, `3`=Bishop, `4`=Knight |

Square indexing: `index = rank * 8 + file`, where a1=0, b1=1, ..., h1=7, a2=8, ..., h8=63. In other words, `file = index % 8` (a=0, h=7) and `rank = index ~/ 8` (1st rank=0, 8th rank=7).


### ACK (0x02) -- 5 bytes

Acknowledges a received message that expects reliability (for example: `MOVE`, `GAME_START`).

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x02` |
| 1-2 | msg_id | uint16, references the acknowledged message |
| 3 | status | `0x00`=OK, `0x01`=ERROR |
| 4 | error_code | See Error Codes (0 if success) |

Direction notes:

- Host to client: ACK for client requests (for example `MOVE`).
- Client to host: ACK for host-initiated reliable signals (currently `GAME_START`).


### SYNC_REQUEST (0x03) -- 3 bytes

Client requests the full game state from host. Header only, no payload.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x03` |
| 1-2 | msg_id | uint16 |


### SYNC_RESPONSE (0x04) / CHUNK (0x05) -- 5 + payload bytes

Host sends the full game state (FEN, move history). Uses chunked header.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x04` or `0x05` |
| 1-2 | msg_id | uint16 |
| 3 | seq | Chunk sequence (1-indexed) |
| 4 | total | Total number of chunks |
| 5+ | payload | UTF-8 encoded JSON (FEN/PGN data) |

Chunking rules:

- If payload fits one MTU: single chunk with `seq=1`, `total=1`.
- If larger: split into multiple chunks.
- Client reassembles in order (1..total).
- Reassembly timeout: 10 seconds. On timeout or missing chunk, discard the buffer and re-send SYNC_REQUEST.


### GAME_END (0x06) -- 5 bytes

Host notifies that the game has ended.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x06` |
| 1-2 | msg_id | uint16 |
| 3 | reason | See Game End Reasons |
| 4 | winner | See Winner Codes |


### DRAW_OFFER (0x07) -- 3 bytes

A player offers a draw. Header only.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x07` |
| 1-2 | msg_id | uint16 |


### DRAW_RESPONSE (0x08) -- 4 bytes

Response to a draw offer.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x08` |
| 1-2 | msg_id | uint16 |
| 3 | accepted | `0x00`=REJECTED, `0x01`=ACCEPTED |


### RESIGN (0x09) -- 3 bytes

A player resigns. Header only.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x09` |
| 1-2 | msg_id | uint16 |


### PING (0x0A) / PONG (0x0B) -- 7 bytes

Keepalive and latency measurement.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x0A` or `0x0B` |
| 1-2 | msg_id | uint16 |
| 3-6 | timestamp | uint32, big-endian (Unix timestamp or monotonic ms) |


### GAME_START (0x0C) -- 3 bytes

Host starts the match after both players are connected in lobby.

| Byte | Field | Value |
|---|---|---|
| 0 | msg_type | `0x0C` |
| 1-2 | msg_id | uint16 |

Flow:

1. Host sends `GAME_START` to client.
2. Client replies with `ACK` using the same `msg_id`.
3. Client transitions to game on receive.
4. Host transitions to game after ACK success.


## Error Codes

| Code | Name | Description |
|---|---|---|
| `0x00` | SUCCESS | Operation completed |
| `0x01` | INVALID_MOVE | Move is not legal |
| `0x02` | NOT_YOUR_TURN | Out-of-turn move attempt |
| `0x03` | GAME_ENDED | Game already concluded |
| `0x04` | SYNC_REQUIRED | Client state out of sync |
| `0x05` | UNKNOWN_MSG_TYPE | Unrecognized message type |
| `0x06` | MALFORMED_MESSAGE | Message parsing failed |
| `0x07` | DUPLICATE_MSG | msg_id already processed |
| `0x08` | RATE_LIMITED | Too many requests |
| `0x10` | VERSION_MISMATCH | Protocol version incompatible |
| `0x11` | SESSION_EXPIRED | Game session no longer valid |
| `0xFF` | INTERNAL_ERROR | Unexpected error |


## Game End Reasons

| Code | Name |
|---|---|
| `0x01` | CHECKMATE |
| `0x02` | STALEMATE |
| `0x03` | RESIGN |
| `0x04` | DRAW_AGREEMENT |
| `0x05` | FIFTY_MOVE_RULE |
| `0x06` | THREEFOLD_REPETITION |
| `0x07` | INSUFFICIENT_MATERIAL |
| `0x08` | TIMEOUT |
| `0x09` | DISCONNECT |


## Winner Codes

| Code | Name |
|---|---|
| `0x00` | DRAW |
| `0x01` | WHITE |
| `0x02` | BLACK |


## Reliability

### Message IDs

`msg_id` is a 16-bit unsigned integer (0-65535) that wraps around. The host maintains a dedupe cache of the last 64 processed msg_ids. On receiving a duplicate, the host re-sends the cached ACK without re-processing.

### Timeouts

| Parameter | Value | Purpose |
|---|---|---|
| T_ack | 3000 ms | Wait for ACK after sending reliable messages (`MOVE`, `GAME_START`) |
| T_chunk | 10000 ms | Wait for all chunks in a SYNC |
| T_ping | 15000 ms | Interval between PINGs |
| T_disconnect | 30000 ms | No PONG received, consider disconnected |

### Retry Policy

- Max retries: 2 (total 3 attempts).
- Backoff delays: 500 ms, then 1000 ms.
- Applies to reliable send-with-ACK operations (`MOVE`, `GAME_START`).

### Rate Limiting

| Message Type | Limit |
|---|---|
| MOVE | Max 2 per second |
| DRAW_OFFER | Max 1 per 30 seconds |
| SYNC_REQUEST | Max 1 per 5 seconds |

Violations receive ACK with `status=ERROR`, `error_code=0x08` (RATE_LIMITED).


## Example Messages

MOVE e2 to e4 (no promotion), msg_id=1:

```
Hex: 01 00 01 0C 1C 00

01       msg_type = MOVE
00 01    msg_id = 1
0C       from = 12 (e2)
1C       to = 28 (e4)
00       promo = none
```

ACK success for msg_id=1:

```
Hex: 02 00 01 00 00

02       msg_type = ACK
00 01    msg_id = 1
00       status = OK
00       error_code = SUCCESS
```

ACK invalid move for msg_id=5:

```
Hex: 02 00 05 01 01

02       msg_type = ACK
00 05    msg_id = 5
01       status = ERROR
01       error_code = INVALID_MOVE
```

HANDSHAKE client initiating, msg_id=1:

```
Hex: 00 00 01 01 02 00

00       msg_type = HANDSHAKE
00 01    msg_id = 1
01       protocol_version = 1
02       role = CLIENT
00       host_color = unspecified
```

GAME_START, msg_id=12:

```
Hex: 0C 00 0C

0C       msg_type = GAME_START
00 0C    msg_id = 12
```

GAME_END checkmate, white wins, msg_id=10:

```
Hex: 06 00 0A 01 01

06       msg_type = GAME_END
00 0A    msg_id = 10
01       reason = CHECKMATE
01       winner = WHITE
```


## Implementation Notes

Square conversion helpers in Dart:

```dart
int squareToIndex(String square) {
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]) - 1;
  return rank * 8 + file;
}

String indexToSquare(int index) {
  final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
  final rank = (index ~/ 8) + 1;
  return '$file$rank';
}

List<int> encodeMsgId(int msgId) {
  return [(msgId >> 8) & 0xFF, msgId & 0xFF];
}

int decodeMsgId(int hi, int lo) {
  return (hi << 8) | lo;
}
```

Receivers should validate the `msg_type` byte before parsing the rest of the message. Unknown types should be rejected with error code `0x05` (UNKNOWN_MSG_TYPE). Messages shorter than the expected size for their type should be rejected with `0x06` (MALFORMED_MESSAGE).

## 14. Security Considerations

| Concern          | Mitigation                                   |
|------------------|----------------------------------------------|
| Eavesdropping    | Require BLE pairing (LE Secure Connections)  |
| Replay attacks   | Session-scoped msg_id + dedupe cache         |
| Spam/DoS         | Rate limiting (see section 11)               |
| MITM             | BLE pairing with numeric comparison          |
