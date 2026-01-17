import 'package:flutter/material.dart';
import '../../../domain/models/move.dart';
import '../../../domain/models/square.dart';
import '../../themes/board_themes.dart';
import 'dart:math' as math;

class MoveIndicatorWidget extends StatelessWidget {
  final Move? lastMove;
  final double squareSize;
  final bool isFlipped;
  final BoardThemesColors theme;

  const MoveIndicatorWidget({
    super.key,
    this.lastMove,
    required this.squareSize,
    this.isFlipped = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (lastMove == null) return const SizedBox.shrink();

    return CustomPaint(
      size: Size(squareSize * 8, squareSize * 8),
      painter: _MoveArrowPainter(
        from: lastMove!.from,
        to: lastMove!.to,
        squareSize: squareSize,
        isFlipped: isFlipped,
        color: theme.lastMove.withValues(alpha: 0.6),
      ),
    );
  }
}

class _MoveArrowPainter extends CustomPainter {
  final Square from;
  final Square to;
  final double squareSize;
  final bool isFlipped;
  final Color color;

  _MoveArrowPainter({
    required this.from,
    required this.to,
    required this.squareSize,
    required this.isFlipped,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = squareSize * 0.15
      ..strokeCap = StrokeCap.round;

    final fromCenter = _getSquareCenter(from);
    final toCenter = _getSquareCenter(to);

    canvas.drawLine(fromCenter, toCenter, paint);

    _drawArrowhead(canvas, fromCenter, toCenter, paint);
  }

  Offset _getSquareCenter(Square square) {
    final file = isFlipped ? 7 - square.file : square.file;
    final rank = isFlipped ? square.rank : 7 - square.rank;

    return Offset(
      file * squareSize + squareSize / 2,
      rank * squareSize + squareSize / 2
    );
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from).direction;
    final headLength = squareSize * 0.3;
    final leftAngle = direction + 2.5;
    final rightAngle = direction - 2.5;

    final left = Offset(
      to.dx - headLength * math.cos(leftAngle),
      to.dy - headLength * math.sin(leftAngle)
    );

    final right = Offset(
      to.dx - headLength * math.cos(rightAngle),
      to.dy - headLength * math.sin(rightAngle),
    );

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(left.dx, left.dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo(right.dx, right.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MoveArrowPainter oldDelegate) {
    return from != oldDelegate.from || to != oldDelegate.to || squareSize != oldDelegate.squareSize || isFlipped != oldDelegate.isFlipped;
  }
}