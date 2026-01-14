import 'package:hive/hive.dart';
import '../../domain/models/saved_game.dart';

abstract class HiveAdapters {
  static bool _registered = false;

  static void registerAll() {
    if (_registered) return;

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SavedGameAdapter());
    }

    _registered = true;
  }
}