import 'package:flutter/material.dart';

// A pre-configured [AppBar] matching the app's consistent style.
//
// Provides a centered title, optional actions, and configurable
// back-button behavior. Uses the theme's AppBar defaults
// (`centerTitle: true`, `elevation: 0`).
class ChessAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChessAppBar({
    required this.title,
    super.key,
    this.actions,
    this.leading,
    this.showBackButton = true,
  });

  // Title text displayed in the app bar.
  final String title;

  // Optional action widgets on the right side.
  final List<Widget>? actions;

  // Optional custom leading widget. Overrides the default back button.
  final Widget? leading;

  // Whether to show the default back button when there is a
  // previous route. Set to `false` to suppress it.
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      leading: leading,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
    );
  }
}
