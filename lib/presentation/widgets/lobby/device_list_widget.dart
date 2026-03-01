import 'package:flutter/material.dart';
import '../../../infrastructure/bluetooth/bluetooth_service.dart';

// Displays a list of discovered BLE devices that can be tapped to connect.
class DeviceListWidget extends StatelessWidget {
  const DeviceListWidget({
    required this.devices,
    required this.onDeviceTap,
    super.key,
    this.connectingDeviceId,
  });

  // List of discovered BLE devices to display.
  final List<BleDeviceInfo> devices;

  // Callback when a device is tapped. Receives the selected device info.
  final ValueChanged<BleDeviceInfo> onDeviceTap;

  // If non-null, the device ID currently being connected to (shows spinner).
  final String? connectingDeviceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No games found yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Make sure the host has created a lobby',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
        final isConnecting = connectingDeviceId == device.id;

        return _DeviceTile(
          device: device,
          isConnecting: isConnecting,
          isDisabled: connectingDeviceId != null && !isConnecting,
          onTap: () => onDeviceTap(device),
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnecting,
    required this.isDisabled,
    required this.onTap,
  });

  final BleDeviceInfo device;
  final bool isConnecting;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Display a friendly name by stripping the BTChess prefix
    final displayName = device.name.replaceFirst('BTChess_', '');
    final signalStrength = _signalStrengthLabel(device.rssi);
    final signalIcon = _signalStrengthIcon(device.rssi);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnecting
                      ? colorScheme.tertiaryContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isConnecting
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      )
                    : Icon(
                        Icons.bluetooth,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          signalIcon,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          signalStrength,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isConnecting)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDisabled
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                      : colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _signalStrengthLabel(int rssi) {
    if (rssi >= -50) return 'Excellent signal';
    if (rssi >= -70) return 'Good signal';
    if (rssi >= -85) return 'Fair signal';
    return 'Weak signal';
  }

  IconData _signalStrengthIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_cellular_4_bar;
    if (rssi >= -70) return Icons.signal_cellular_alt;
    if (rssi >= -85) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }
}
