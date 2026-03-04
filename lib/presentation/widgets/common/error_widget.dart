import 'package:flutter/material.dart';

// A centered error display with an icon, message, and optional retry button.
//
// Named [AppErrorWidget] to avoid conflict with Flutter's built-in
// [ErrorWidget]. Use this for user-facing error states in screens.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    required this.message,
    super.key,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  // Error message to display.
  final String message;

  // Optional callback for a retry action. When provided, a "Retry"
  // button is shown below the message.
  final VoidCallback? onRetry;

  // Icon displayed above the message.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
