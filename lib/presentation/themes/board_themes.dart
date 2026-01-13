import 'package:flutter/material.dart';
import '../../infrastructure/persistence/settings_repository.dart';

class BoardThemesColors {
  final Color lightSquare;
  final Color darkSquare;
  final Color selection;
  final Color legalMove;
  final Color lastMove;
  final Color check;
  final Color border;

  const BoardThemesColors({
    required this.lightSquare,
    required this.darkSquare,
    this.selection = const Color(0x8081D4FA),
    this.legalMove = const Color(0x6081C784),
    this.lastMove = const Color(0x50FFEB3B),
    this.check = const Color(0x80EF5350),
    this.border = const Color(0xFF5D4037),
  });

  Color squareColor(int file, int rank) {
    final isLight = (file + rank) % 2 == 1;

    return isLight ? lightSquare : darkSquare;
  }

  static BoardThemesColors fromTheme(BoardTheme theme) {
    switch (theme) {
      case BoardTheme.classic:
      return classic;
      case BoardTheme.wood:
      return wood;
      case BoardTheme.blue:
      return blue;
      case BoardTheme.green:
      return green;
      case BoardTheme.gray:
      return gray;
    }
  }

  static const classic = BoardThemesColors(lightSquare: Color(0xFFF0D9B5), darkSquare: Color(0xFFB58863));
  static const wood = BoardThemesColors(lightSquare: Color(0xFFDEB887), darkSquare: Color(0xFF8B4513), border: Color(0xFF3E2723));
  static const blue = BoardThemesColors(lightSquare: Color(0xFFDEE3E6), darkSquare: Color(0xFF8CA2AD), border: Color(0xFF546E7A));
  static const green = BoardThemesColors(lightSquare: Color(0xFFEEEED2), darkSquare: Color(0xFF769656), border: Color(0xFF4E7837));
  static const gray = BoardThemesColors(lightSquare: Color(0xFFE0E0E0), darkSquare: Color(0xFF9E9E9E), border: Color(0xFF616161));
}