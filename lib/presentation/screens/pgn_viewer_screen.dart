import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_over_screen.dart';

class PgnViewerScreen extends StatelessWidget {
  const PgnViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as PgnViewerScreenArgs;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pgn = args.pgn;

    return Scaffold(
      appBar: AppBar(
        title: Text(args.title ?? 'Game PGN'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy PGN',
            onPressed: () => _copyToClipboard(context, pgn),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPgnSection(
                      context: context,
                      title: 'Headers',
                      content: _extractHeaders(pgn),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _buildPgnSection(
                      context: context,
                      title: 'Moves',
                      content: _extractMovetext(pgn),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _buildFullPgnCard(pgn, theme, colorScheme),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _copyToClipboard(context, pgn),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Clipboard'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPgnSection({
    required BuildContext context,
    required String title,
    required String content,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPgnCard(String pgn, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Full PGN',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              pgn,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractHeaders(String pgn) {
    final lines = pgn.split('\n');
    final headers = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        headers.add(trimmed);
      }
    }
    return headers.join('\n');
  }

  String _extractMovetext(String pgn) {
    final lines = pgn.split('\n');
    final moveLines = <String>[];
    bool pastHeaders = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty && !pastHeaders) {
        pastHeaders = true;
        continue;
      }
      if (pastHeaders && trimmed.isNotEmpty) {
        moveLines.add(trimmed);
      }
      // Also grab non-header, non-empty lines even before blank separator
      if (!pastHeaders && !trimmed.startsWith('[') && trimmed.isNotEmpty) {
        moveLines.add(trimmed);
      }
    }
    return moveLines.join('\n');
  }

  void _copyToClipboard(BuildContext context, String pgn) {
    Clipboard.setData(ClipboardData(text: pgn));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PGN copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
