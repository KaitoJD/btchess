import 'package:flutter/material.dart';
import '../screens/game_history_screen.dart';
import '../screens/game_screen.dart';
import '../screens/home_screen.dart';
import '../screens/lobby_screen.dart';
import '../screens/mode_selection_screen.dart';
import '../screens/settings_screen.dart';

abstract class AppRoutes {
  static const String home = '/';
  static const String modeSelection = '/mode-selection';
  static const String game = '/game';
  static const String settings = '/settings';
  static const String history = '/history';
  static const String lobby = '/lobby';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case AppRoutes.modeSelection:
        return MaterialPageRoute(
          builder: (_) => const ModeSelectionScreen(),
          settings: settings,
        );
      case AppRoutes.game:
        return MaterialPageRoute(
          builder: (_) => const GameScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.history:
        return MaterialPageRoute(
          builder: (_) => const GameHistoryScreen(),
          settings: settings,
        );
      case AppRoutes.lobby:
        return MaterialPageRoute(
          builder: (_) => const LobbyScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
    }
  }

  static Future<T?> navigateTo<T>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> navigateAndReplace<T>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushReplacementNamed<T, dynamic>(routeName, arguments: arguments);
  }

  static Future<T?> navigateAndClear<T>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(routeName, (route) => false, arguments: arguments);
  }

  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}