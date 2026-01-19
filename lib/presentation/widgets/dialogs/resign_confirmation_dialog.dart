import 'package:flutter/material.dart';

class ResignConfirmationDialog extends StatelessWidget {
  const ResignConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.flag, size: 48),
      title: const Text('Resign Game?'),
      content: const Text('Are you sure you want to resign?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Resign'),
        )
      ],
    );
  }
}

Future<bool> showResignConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const ResignConfirmationDialog(),
  );

  return result ?? false;
}