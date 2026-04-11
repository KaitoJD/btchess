import 'package:btchess/core/errors/app_exception.dart';
import 'package:btchess/core/errors/ble_exception.dart';
import 'package:btchess/core/utils/user_error_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    UserErrorFormatter.setDebugMode(enabled: false);
  });

  group('UserErrorFormatter.formatError', () {
    test('returns generic text for internal exceptions when debug is off', () {
      final message = UserErrorFormatter.formatError(
        const AppException('Database write failed'),
        context: 'Save failed',
      );

      expect(message, UserErrorFormatter.genericErrorMessage);
    });

    test('returns actionable text for user-fixable exceptions when debug is off', () {
      final message = UserErrorFormatter.formatError(
        const BlePermissionException('Bluetooth permissions not granted'),
      );

      expect(message, 'Bluetooth permissions not granted');
    });

    test('includes technical detail when debug is on', () {
      UserErrorFormatter.setDebugMode(enabled: true);

      final message = UserErrorFormatter.formatError(
        const BleProtocolException('Protocol mismatch', errorCode: 0x10),
        context: 'Handshake failed',
      );

      expect(message, 'Handshake failed: BleProtocolException: Protocol mismatch (error: 0x10)');
    });
  });

  group('UserErrorFormatter.formatMessage', () {
    test('keeps user-fixable plain messages when debug is off', () {
      final message = UserErrorFormatter.formatMessage('Not your turn');

      expect(message, 'Not your turn');
    });

    test('simplifies non-actionable plain messages when debug is off', () {
      final message = UserErrorFormatter.formatMessage('An error occurred (0xff)');

      expect(message, UserErrorFormatter.genericErrorMessage);
    });
  });

  group('UserErrorFormatter.fixHintForMessage', () {
    test('returns guidance hint for bluetooth-off message', () {
      final hint = UserErrorFormatter.fixHintForMessage('Bluetooth is turned off');

      expect(hint, isNotNull);
      expect(hint, contains('Turn on Bluetooth'));
    });

    test('returns null for generic non-actionable message', () {
      final hint = UserErrorFormatter.fixHintForMessage('Something went wrong :(');

      expect(hint, isNull);
    });
  });
}