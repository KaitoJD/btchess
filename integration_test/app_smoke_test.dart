import 'package:btchess/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to home', (tester) async {
    app.main();

    await tester.pumpAndSettle();

    expect(find.text('BTChess'), findsWidgets);
    expect(find.text('New Game'), findsOneWidget);
  });
}
