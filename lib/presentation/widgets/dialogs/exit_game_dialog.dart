import 'package:flutter/material.dart';

class ExitGameDialog extends StatelessWidget {
  final bool isBleGame;

  const ExitGameDialog({
    super.key,
    this.isBleGame = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = isBleGame ? 'Leaving will disconnect you from your opponent and end the game.' : 'Your game progress will be saved. You can continue later.';

    return AlertDialog(
      icon: const Icon(Icons.exit_to_app, size: 48),
      title: const Text('Exit Game?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Exit'),
        ),
      ],
    );
  }
}

Future<bool> showExitGameDialog(BuildContext context, {bool isBleGame = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => ExitGameDialog(isBleGame: isBleGame),
  );

  return result ?? false;
}