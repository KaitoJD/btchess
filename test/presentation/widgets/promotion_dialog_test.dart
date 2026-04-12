import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/domain/enums/promotion_piece.dart';
import 'package:btchess/domain/models/piece.dart';
import 'package:btchess/infrastructure/persistence/settings_repository.dart';
import 'package:btchess/presentation/widgets/dialogs/promotion_dialog.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  static final ByteData _svgBytes =
      ByteData.view(Uint8List.fromList(utf8.encode(
    '<svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
  )).buffer);

  @override
  Future<ByteData> load(String key) async {
    return _svgBytes;
  }
}

void main() {
  testWidgets('showPromotionDialog returns selected piece when a piece is tapped',
      (tester) async {
    late BuildContext context;

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeAssetBundle(),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold();
            },
          ),
        ),
      ),
    );

    final dialogFuture = showPromotionDialog(
      context,
      color: PieceColor.white,
      pieceTheme: PieceTheme.standard,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(await dialogFuture, PromotionPiece.queen);
  });

  testWidgets('showPromotionDialog returns null when cancelled', (tester) async {
    late BuildContext context;

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeAssetBundle(),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold();
            },
          ),
        ),
      ),
    );

    final dialogFuture = showPromotionDialog(
      context,
      color: PieceColor.black,
      pieceTheme: PieceTheme.standard,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await dialogFuture, isNull);
  });
}