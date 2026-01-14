import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/saved_game.dart';
import 'hive_adapters.dart';

abstract class HiveBoxes {
  static const String games = 'games';
  static const String history = 'history';
}

class HiveInitializer {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    HiveAdapters.registerAll();

    _initialized = true;
  }

  static Future<void> openBoxes() async {
    await Hive.openBox<SavedGame>(HiveBoxes.games);
  }

  static Future<void> close() async {
    await Hive.close();

    _initialized = false;
  }

  static Future<void> clearAll() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.games);
    await Hive.deleteBoxFromDisk(HiveBoxes.history);
  }
}