import 'package:flutter/material.dart';
import '../../themes/board_themes.dart';

class BoardCoordinatesWidget extends StatelessWidget {
  final double squareSize;
  final bool isFlipped;
  final BoardThemesColors theme;
  final Widget child;
  final double coordinatePadding;

  const BoardCoordinatesWidget({
    super.key,
    required this.squareSize,
    required this.child,
    this.isFlipped = false,
    required this.theme,
    this.coordinatePadding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final fontSize = coordinatePadding * 0.7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: coordinatePadding,
              height: squareSize * 8,
              child: Column(
                children: List.generate(8, (index) {
                  final rank = isFlipped ? index + 1 : 8 - index;
                  return SizedBox(
                    height: squareSize,
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            child,
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: coordinatePadding),
            SizedBox(
              width: squareSize * 8,
              height: coordinatePadding,
              child: Row(
                children: List.generate(8, (index) {
                  final file = isFlipped ? String.fromCharCode('h'.codeUnitAt(0) - index) : String.fromCharCode('a'.codeUnitAt(0) + index);
                  return SizedBox(
                    width: squareSize,
                    child: Center(
                      child: Text(
                        file,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}