import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/game_provider.dart';

bool hasActiveGame(WidgetRef ref) {
  return ref.read(hasActiveGameProvider);
}

bool isGameInProgress(WidgetRef ref) {
  return ref.read(isGameInProgressProvider);
}

enum RouteGuardResult {
  allow,
  redirect,
  block,
}

RouteGuardResult gameScreenGuard(WidgetRef ref) {
  if (!hasActiveGame(ref)) {
    return RouteGuardResult.redirect;
  }
  return RouteGuardResult.allow;
}