import 'package:btchess/core/errors/ble_exception.dart';
import 'package:btchess/infrastructure/bluetooth/ble_setup.dart';
import 'package:btchess/infrastructure/bluetooth/bluetooth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BleConnectionAttempt createAttempt() {
    return BleConnectionAttempt(
      id: 42,
      isHost: false,
      platform: 'android',
      deadline: DateTime.now().add(const Duration(seconds: 10)),
    );
  }

  test('cancel invalidates an attempt and ignores late phase callbacks', () async {
    final attempt = createAttempt();
    final phases = <BleSetupPhase>[];
    final phaseSubscription = attempt.phaseStream.listen((event) {
      phases.add(event.phase);
    });
    final connectionExpectation = expectLater(
      attempt.connection,
      throwsA(isA<BleDisconnectedException>()),
    );
    final completionExpectation = expectLater(
      attempt.completion,
      throwsA(isA<BleDisconnectedException>()),
    );

    attempt.reportPhase(BleSetupPhase.connecting);
    await attempt.cancel();
    attempt.reportPhase(BleSetupPhase.ready);

    await connectionExpectation;
    await completionExpectation;
    await Future<void>.delayed(Duration.zero);

    expect(attempt.isCancelled, isTrue);
    expect(attempt.isActive, isFalse);
    expect(phases, [BleSetupPhase.connecting, BleSetupPhase.cancelled]);

    await phaseSubscription.cancel();
  });

  test('failure completes the terminal phase without requiring a transport', () async {
    final attempt = createAttempt();
    final terminalFuture = attempt.terminal;
    final connectionExpectation = expectLater(
      attempt.connection,
      throwsA(isA<BleConnectionException>()),
    );
    final completionExpectation = expectLater(
      attempt.completion,
      throwsA(isA<BleConnectionException>()),
    );

    attempt.fail(const BleConnectionException('setup failed'));

    expect(await terminalFuture, BleSetupPhase.failed);
    await connectionExpectation;
    await completionExpectation;
    expect(attempt.phase, BleSetupPhase.failed);
    expect(attempt.isActive, isFalse);
  });
}
