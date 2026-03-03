import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/audio/audio_service.dart';
import 'settings_provider.dart';

// Provides the [AudioService] singleton, kept in sync with the
//  user's sound-enabled preference from settings.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();

  // Keep soundEnabled in sync with the settings toggle.
  ref.listen<bool>(soundEnabledProvider, (_, enabled) {
    service.soundEnabled = enabled;
  }, fireImmediately: true);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});