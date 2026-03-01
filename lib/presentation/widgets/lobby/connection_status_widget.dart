import 'package:flutter/material.dart';
import '../../../application/states/bluetooth_state.dart';

// Displays the current BLE connection progress with status text,
// an appropriate icon, and optional error/retry actions.
class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({
    required this.status,
    super.key,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  });

  // Current BLE connection status to visualize.
  final BleConnectionStatus status;

  // Error message to display when status is [BleConnectionStatus.error].
  final String? errorMessage;

  // Called when the user taps "Retry" on an error state.
  final VoidCallback? onRetry;

  // Called when the user taps "Cancel" during connection/error.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: _backgroundColor(colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(colorScheme),
            const SizedBox(height: 12),
            Text(
              _statusTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _textColor(colorScheme),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statusDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _textColor(colorScheme).withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (_showProgress) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4),
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            if (status == BleConnectionStatus.error) ...[
              const SizedBox(height: 12),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ],
            if (status == BleConnectionStatus.reconnecting) ...[
              const SizedBox(height: 12),
              Text(
                'Attempting to reconnect...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    switch (status) {
      case BleConnectionStatus.connecting:
        return _AnimatedStatusIcon(
          icon: Icons.bluetooth_searching,
          color: colorScheme.primary,
        );
      case BleConnectionStatus.handshaking:
        return _AnimatedStatusIcon(
          icon: Icons.handshake,
          color: colorScheme.primary,
        );
      case BleConnectionStatus.connected:
        return Icon(
          Icons.bluetooth_connected,
          size: 40,
          color: colorScheme.primary,
        );
      case BleConnectionStatus.reconnecting:
        return _AnimatedStatusIcon(
          icon: Icons.sync,
          color: colorScheme.tertiary,
        );
      case BleConnectionStatus.error:
        return Icon(
          Icons.error_outline,
          size: 40,
          color: colorScheme.error,
        );
      default:
        return Icon(
          Icons.bluetooth,
          size: 40,
          color: colorScheme.onSurfaceVariant,
        );
    }
  }

  String get _statusTitle {
    switch (status) {
      case BleConnectionStatus.connecting:
        return 'Connecting...';
      case BleConnectionStatus.handshaking:
        return 'Handshaking...';
      case BleConnectionStatus.connected:
        return 'Connected';
      case BleConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case BleConnectionStatus.error:
        return 'Connection Failed';
      case BleConnectionStatus.scanning:
        return 'Scanning...';
      case BleConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  String get _statusDescription {
    switch (status) {
      case BleConnectionStatus.connecting:
        return 'Establishing Bluetooth connection';
      case BleConnectionStatus.handshaking:
        return 'Exchanging protocol handshake';
      case BleConnectionStatus.connected:
        return 'Ready to play';
      case BleConnectionStatus.reconnecting:
        return 'Connection lost. Trying to reconnect...';
      case BleConnectionStatus.error:
        return errorMessage ?? 'Something went wrong';
      case BleConnectionStatus.scanning:
        return 'Looking for nearby games';
      case BleConnectionStatus.disconnected:
        return 'Not connected';
    }
  }

  bool get _showProgress {
    return status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.handshaking;
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    switch (status) {
      case BleConnectionStatus.error:
        return colorScheme.errorContainer;
      case BleConnectionStatus.connected:
        return colorScheme.primaryContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _textColor(ColorScheme colorScheme) {
    switch (status) {
      case BleConnectionStatus.error:
        return colorScheme.onErrorContainer;
      case BleConnectionStatus.connected:
        return colorScheme.onPrimaryContainer;
      default:
        return colorScheme.onSurface;
    }
  }
}

// A simple animated icon that pulses for connection-in-progress states.
class _AnimatedStatusIcon extends StatefulWidget {
  const _AnimatedStatusIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  State<_AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<_AnimatedStatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(
            widget.icon,
            size: 40,
            color: widget.color,
          ),
        );
      },
    );
  }
}
