import 'package:flutter/material.dart';

abstract class AppTheme {
    static const Color primaryColor = Color(0xFF795548);
    static const Color accentColor = Color(0xFF8D6E63);
    static const Color successColor = Color(0xFF4CAF50);
    static const Color errorColor = Color(0xFFE53935);
    static const Color warningColor = Color(0xFFFFC107);

    static ThemeData get light {
        return ThemeData(
            useMaterial3: true,

            colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                brightness: Brightness.light,
            ),

            appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 2,
            ),

            cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
            ),

            listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),

            switchTheme: SwitchThemeData(
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.check, size: 14);
                    }
                    return null;
                }),
            ),

            dividerTheme: const DividerThemeData(
                space: 1,
                thickness: 1,
            ),

            snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                ),
            ),

            bottomSheetTheme: const BottomSheetThemeData(
                showDragHandle: true,
                dragHandleSize: Size(32, 4),
            ),

            dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
            ),
        );
    }

    static ThemeData get dark {
        return ThemeData(
            useMaterial3: true,

            colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                brightness: Brightness.dark,
            ),

            appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 2,
            ),

            cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                ),
            ),

            inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
            ),

            listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),

            switchTheme: SwitchThemeData(
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                        return const Icon(Icons.check, size: 14);
                    }
                    return null;
                }),
            ),

            dividerTheme: const DividerThemeData(
                space: 1,
                thickness: 1,
            ),

            snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                ),
            ),

            bottomSheetTheme: const BottomSheetThemeData(
                showDragHandle: true,
                dragHandleSize: Size(32, 4),
            ),

            dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
            ),
        );
    }
}  