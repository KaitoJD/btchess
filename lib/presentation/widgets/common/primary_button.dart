import 'package:flutter/material.dart';

// A full-width filled button matching the app's primary action pattern.
//
// Wraps [FilledButton.icon] in a fixed-height [SizedBox] for consistent
// sizing across all screens. Supports an optional loading state that
// disables interaction and shows a spinner in place of the icon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
  });

  // Button label text.
  final String label;

  // Callback when pressed. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  // Optional leading icon. Ignored when [isLoading] is true.
  final IconData? icon;

  // When true, shows a spinner and disables the button.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget child;
    if (icon != null || isLoading) {
      child = FilledButton.icon(
        onPressed: effectiveOnPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label),
      );
    } else {
      child = FilledButton(
        onPressed: effectiveOnPressed,
        child: Text(label),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: child,
    );
  }
}
