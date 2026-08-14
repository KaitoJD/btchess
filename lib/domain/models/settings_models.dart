enum BoardTheme {
  classic,
  wood,
  blue,
  green,
  gray;

  String get displayName {
    switch (this) {
      case BoardTheme.classic:
        return 'Classic';
      case BoardTheme.wood:
        return 'Wood';
      case BoardTheme.blue:
        return 'Blue';
      case BoardTheme.green:
        return 'Green';
      case BoardTheme.gray:
        return 'Gray';
    }
  }
}

enum PieceTheme {
  standard,
  neo,
  alpha,
  chess24;

  String get displayName {
    switch (this) {
      case PieceTheme.standard:
        return 'Standard';
      case PieceTheme.neo:
        return 'Neo';
      case PieceTheme.alpha:
        return 'Alpha';
      case PieceTheme.chess24:
        return 'Chess24';
    }
  }
}

enum AppThemeMode {
  light,
  dark,
  system;

  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
}
