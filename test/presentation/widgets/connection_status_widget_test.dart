import 'package:btchess/application/states/bluetooth_state.dart';
import 'package:btchess/presentation/widgets/lobby/connection_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the system-pairing instruction while pairing', (
    tester,
  ) async {
    var didCancel = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusWidget(
            status: BleConnectionStatus.pairing,
            onCancel: () => didCancel = true,
          ),
        ),
      ),
    );

    expect(find.text('Pairing devices...'), findsOneWidget);
    expect(
      find.text(
        'Please confirm or enter the code in the system dialog on both devices. '
        'BTChess will automatically continue.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(didCancel, isTrue);
  });
}
