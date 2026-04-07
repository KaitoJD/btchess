import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/providers/settings_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'core/utils/user_error_formatter.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/themes/app_theme.dart';

class BTChessApp extends ConsumerStatefulWidget {
  const BTChessApp({super.key});

  @override
  ConsumerState<BTChessApp> createState() => _BTChessAppState();
}

class _BTChessAppState extends ConsumerState<BTChessApp> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).loadSettings();

      final debugModeEnabled = ref.read(debugModeProvider);
      UserErrorFormatter.setDebugMode(enabled: debugModeEnabled);
      Logger.setLevel(debugModeEnabled ? LogLevel.debug : LogLevel.off);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(debugModeProvider, (_, enabled) {
      UserErrorFormatter.setDebugMode(enabled: enabled);
      Logger.setLevel(enabled ? LogLevel.debug : LogLevel.off);
    });

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const _AppLoader(),
    );
  }
}

class _AppLoader extends ConsumerWidget {
  const _AppLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsLoaded = ref.watch(settingsLoadedProvider);

    if (!settingsLoaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_on,
                size: 80,
                color: Colors.brown,
              ),
              SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
