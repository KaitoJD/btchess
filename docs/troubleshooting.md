# BTChess -- Troubleshooting

## BLE Issues

### Scanning finds no devices

- Verify Bluetooth is enabled on both devices.
- On Android, ensure location services are on (required for BLE scanning on Android < 12).
- Check that the host device is actively advertising (lobby screen shows advertising status).
- Restart the scan. The default scan timeout is 30 seconds.
- If the host app was force-closed, advertising stops. Re-create the lobby.

### Permission denied

- On Android 12+, the app needs BLUETOOTH_SCAN, BLUETOOTH_CONNECT, and BLUETOOTH_ADVERTISE. If denied, go to device Settings > Apps > BTChess > Permissions and grant Bluetooth and Location.
- On iOS, grant Bluetooth access when prompted. If previously denied, go to Settings > BTChess > Bluetooth.

### Connection drops or fails

- BLE range is typically 10-30 meters. Stay within range.
- If the connection drops mid-game, the client automatically attempts to reconnect. If it fails, both players see a disconnect dialog with a reconnect option.
- On reconnect, the client sends a SYNC_REQUEST. If the host responds with the full game state, play resumes. If the sync times out (10 seconds), the client prompts to retry or exit.
- If connections fail repeatedly, restart Bluetooth on both devices.

### Client stays on "Waiting for host to start"

- This is expected until the host taps "Start Game". Only the host can initiate game start.
- If the host tapped "Start Game" and the client still does not enter the game:
	- Keep both devices connected and close to each other.
	- On host, tap "Start Game" again (the host retries start using ACK/retry logic).
	- If host shows "Failed to start game", check Bluetooth stability and try again.
- If this repeats, leave and recreate the lobby on both devices.

### Handshake fails or times out

- The handshake has a 5-second timeout. If the host is busy or the connection is unstable, the handshake may fail.
- Protocol version mismatch causes an immediate disconnect with error code 0x10. Ensure both devices run the same app version.

### Moves are rejected with NOT_YOUR_TURN

- The host is authoritative. If the client is out of sync (e.g., after a dropped message), the host rejects the move. The client should request a sync (`requestSync()`), which happens automatically on reconnect.


## Persistence Issues

### Saved games not appearing

- Hive boxes are initialized in `main.dart`. If the app was updated and Hive type adapters changed, the box may need to be cleared.
- The app stores a maximum of 100 games. Oldest completed games are auto-deleted when the limit is reached.

### Settings not persisting

- Settings are stored in SharedPreferences. If they reset after reinstall, this is expected -- SharedPreferences are cleared on app uninstall.


## Build Issues

### Hive adapter errors

If you see errors like `type 'X' is not a subtype of type 'Y'` after changing model fields, regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Android build failures

- Verify `minSdkVersion` is at least 21 in `android/app/build.gradle.kts`.
- If Gradle sync fails, try `cd android && ./gradlew clean && cd ..` then rebuild.
- The `ble_peripheral` plugin requires Android 5.0+ (API 21).

### iOS build failures

- Run `cd ios && pod install && cd ..` after adding or updating dependencies.
- Verify the deployment target is iOS 12.0+ in Xcode.
- Signing issues: configure a valid development team in Xcode under Signing & Capabilities.
