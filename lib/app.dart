import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/providers/settings_provider.dart';
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

    Future.microtask(() {
      ref.read(settingsControllerProvider.notifier).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTChess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
                'BTChess',
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
