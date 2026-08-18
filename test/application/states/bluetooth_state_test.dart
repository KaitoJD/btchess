import 'package:btchess/application/states/bluetooth_state.dart';
import 'package:btchess/infrastructure/bluetooth/ble_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BluetoothState connection progress', () {
    test('treats pairing as an in-progress connection state', () {
      const state = BluetoothState(
        connectionStatus: BleConnectionStatus.pairing,
      );

      expect(state.isConnecting, isTrue);
      expect(state.isConnected, isFalse);
      expect(state.hasError, isFalse);
    });

    test('maps pairing setup progress to the pairing UI status', () {
      expect(
        BleSetupPhase.pairing.toBleStatus(),
        BleConnectionStatus.pairing,
      );
    });

    test('maps an awaited pairing reconnect to reconnecting', () {
      expect(
        BleSetupPhase.awaitingReconnect.toBleStatus(),
        BleConnectionStatus.reconnecting,
      );
    });
  });
}
