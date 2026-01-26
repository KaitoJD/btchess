import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/settings_provider.dart';
import '../../infrastructure/persistence/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Player'),
          _NameTile(
            name: settings.playerName,
            onChanged: (name) => controller.setPlayerName(name),
          ),
          const Divider(),
          const _SectionHeader(title: 'Game'),
          SwitchListTile(
            title: const Text('Show Legal Moves'),
            subtitle: const Text('Highlight valid moves when selecting a piece'),
            value: settings.showLegalMoves,
            onChanged: (value) => controller.setShowLegalMoves(value),
          ),
          SwitchListTile(
            title: const Text('Show Coordinates'),
            subtitle: const Text('Display a-h and 1-8 on the board'),
            value: settings.showCoordinates,
            onChanged: (value) => controller.setShowCoordinates(value),
          ),
          SwitchListTile(
            title: const Text('Auto Flip Board'),
            subtitle: const Text('Flip board when playing as black'),
            value: settings.autoFlipBoard,
            onChanged: (value) => controller.setAutoFlipBoard(value),
          ),
          const Divider(),
          const _SectionHeader(title: 'Appearance'),
          _ThemeSelector<BoardTheme>(
            title: 'Board Theme',
            value: settings.boardTheme,
            values: BoardTheme.values,
            getLabel: (t) => t.displayName,
            onChanged: (theme) => controller.setBoardTheme(theme),
          ),
          _ThemeSelector<PieceTheme>(
            title: 'Piece Theme',
            value: settings.pieceTheme,
            values: PieceTheme.values,
            getLabel: (t) => t.displayName,
            onChanged: (theme) => controller.setPieceTheme(theme),
          ),
          const Divider(),
          const _SectionHeader(title: 'Sound'),
          SwitchListTile(
            title: const Text('Sound Effects'),
            subtitle: const Text('Play sounds for moves and captures'),
            value: settings.soundEnabled,
            onChanged: (value) => controller.setSoundEnabled(value),
          ),
          const Divider(),
          const _SectionHeader(title: 'Developer'),
          SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show debug information and logs'),
            value: settings.debugMode,
            onChanged: (value) => controller.setDebugMode(value),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => _showResetDialog(context, controller),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Reset All Settings'),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'BTChess',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16)
        ],
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context, dynamic controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.resetToDefaults();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({
    required this.name,
    required this.onChanged,
  });

  final String name;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Player Name'),
      subtitle: Text(name),
      trailing: const Icon(Icons.edit),
      onTap: () => _showNameDialog(context),
    );
  }

  Future<void> _showNameDialog(BuildContext context) async {
    final controller = TextEditingController(text: name);

    final newName = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Player Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      onChanged(newName);
    }
  }
}

class _ThemeSelector<T extends Enum> extends StatelessWidget {
  const _ThemeSelector({
    required this.title,
    required this.value,
    required this.values,
    required this.getLabel,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) getLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(getLabel(value)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showPicker(context),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: values.map((v) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(v),
            child: Row(
              children: [
                if (v == value)
                  Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else const SizedBox(width: 24),
                const SizedBox(width: 12),
                Text(getLabel(v)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      onChanged(selected);
    }
  }
}