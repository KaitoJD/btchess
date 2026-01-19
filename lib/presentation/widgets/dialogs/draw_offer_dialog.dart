import 'package:flutter/material.dart';

class DrawOfferDialog extends StatelessWidget {
  const DrawOfferDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.handshake, size: 48),
      title: const Text('Offer Draw?'),
      content: const Text('Do you want to offer a draw to your opponent?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Offer Draw'),
        ),
      ],
    );
  }
}

class DrawOfferedDialog extends StatelessWidget {
  final String opponentName;

  const DrawOfferedDialog({
    super.key,
    this.opponentName = 'Opponent',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.handshake, size: 48),
      title: const Text('Draw Offered'),
      content: Text('$opponentName is offering a draw. Do you accept?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

Future<bool> showDrawOfferDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const DrawOfferDialog(),
  );

  return result ?? false;
}

Future<bool> showDrawOfferedDialog(BuildContext context, {String opponentName = 'Opponent'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => DrawOfferedDialog(opponentName: opponentName),
  );

  return result ?? false;
}