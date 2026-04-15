import 'package:btchess/core/constants/ble_constants.dart';
import 'package:btchess/core/constants/timing_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BLE timing and scan constants', () {
    test('uses faster scan fallback delay for cross-platform discovery', () {
      expect(BleConstants.scanFallbackDelaySeconds, 3);
    });

    test('uses extended handshake timeout for cross-platform handshaking', () {
      expect(TimingConstants.handshakeTimeoutMs, 45000);
    });
  });
}
