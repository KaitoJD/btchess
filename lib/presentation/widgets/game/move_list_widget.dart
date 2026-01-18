import 'package:flutter/material.dart';
import '../../../domain/models/move.dart';

class MoveListWidget extends StatefulWidget {
  final List<Move> moves;
  final int? selectedMoveIndex;
  final void Function(int index)? onMoveTap;
  final bool showMoveNumbers;
  final bool autoScroll;

  const MoveListWidget({
    super.key,
    required this.moves,
    this.selectedMoveIndex,
    this.onMoveTap,
    this.showMoveNumbers = true,
    this.autoScroll = true,
  });

  @override
  State<MoveListWidget> createState() => _MoveListWidgetState();
}

class _MoveListWidgetState extends State<MoveListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoScroll && widget.moves.length > oldWidget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) {
      return const Center(
        child: Text(
          'No moves yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _buildMoveWidgets(context),
        ),
      ),
    );
  }

  List<Widget> _buildMoveWidgets(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < widget.moves.length; i++) {
      final move = widget.moves[i];
      final isWhiteMove = i % 2 == 0;
      final moveNumber = (i ~/ 2) + 1;

      if (isWhiteMove && widget.showMoveNumbers) {
        widgets.add(
          Text(
            '$moveNumber.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }

      widgets.add(
        _MoveChip(
          move: move,
          index: i,
          isSelected: widget.selectedMoveIndex == i,
          onTap: widget.onMoveTap != null ? () => widget.onMoveTap!(i) : null,
        ),
      );
    }

    return widgets;
  }
}

class _MoveChip extends StatelessWidget {
  final Move move;
  final int index;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MoveChip({
    required this.move,
    required this.index,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent
        ),
        child: Text(
          move.san ?? move.uci,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: _getMoveColor(colorScheme),
          ),
        ),
      ),
    );
  }

  Color _getMoveColor(ColorScheme colorScheme) {
    if (move.isCheckmate) {
      return colorScheme.error;
    }
    if (move.isCheck) {
      return colorScheme.tertiary;
    }
    if (move.isCapture) {
      return colorScheme.secondary;
    }
    return colorScheme.onSurface;
  }
}

class CompactMoveListWidget extends StatelessWidget {
  final List<Move> moves;
  final int? selectedMoveIndex;

  const CompactMoveListWidget({
    super.key,
    required this.moves,
    this.selectedMoveIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final displayMoves = moves.length > 6 ? moves.sublist(moves.length - 6) : moves;
    final startIndex = moves.length - displayMoves.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (moves.length > 6)
          const Text('... ', style: TextStyle(color: Colors.grey)),
          ...displayMoves.asMap().entries.map((entry) {
            final actualIndex = startIndex + entry.key;
            final move = entry.value;
            final isWhite = actualIndex % 2 == 0;
            final moveNum = (actualIndex ~/ 2) + 1;

            return Text(
              '${isWhite ? '$moveNum.' : ''}${move.san ?? move.uci} ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: actualIndex == selectedMoveIndex ? FontWeight.bold : FontWeight.normal
              ),
            );
          }),
      ],
    );
  }
}