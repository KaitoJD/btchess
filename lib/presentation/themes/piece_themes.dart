import 'package:flutter/material.dart';
import '../../domain/models/piece.dart';
import '../../infrastructure/persistence/settings_repository.dart';

abstract class PieceThemes {
  static String getAssetPath(PieceTheme theme, Piece piece) {
    final themeName = theme.name;
    final colorName = piece.color == PieceColor.white ? 'w' : 'b';
    final pieceLetter = piece.type.letter.toUpperCase();

    return 'assets/pieces/$themeName/$colorName$pieceLetter.svg';
  }

  static String getSymbol(Piece piece) {
    return piece.symbol;
  }

  static TextStyle getSymbolStyle({
    required double size,
    required PieceColor color,
    bool addShadow = true,
  }) {
    return TextStyle(
      fontSize: size * 0.75,
      fontFamily: 'Noto Sans Symbols 2',
      color: color == PieceColor.white ? Colors.white : Colors.black,
      shadows: addShadow
        ? [
          Shadow(
            color: color == PieceColor.white ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ] : null,
    );
  }
}