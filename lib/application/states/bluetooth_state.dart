import 'package:equatable/equatable.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../../infrastructure/bluetooth/connection_manager.dart' as cm;

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  handshaking,
  connected,
  reconnecting,
  error,
}

class BluetoothState extends Equatable {
  const BluetoothState({
    this.connectionStatus = BleConnectionStatus.disconnected,
    this.isBluetoothOn = false,
    this.isScanning = false,
    this.scannedDevices = const [],
    this.connectedDevice,
    this.isHost = false,
    this.lastError,
    this.pendingMoveId,
  });

  factory BluetoothState.initial() => const BluetoothState();

  // Current connection status
  final BleConnectionStatus connectionStatus;

  // Whether Bluetooth adapter is on
  final bool isBluetoothOn;

  // Whether currently scanning for devices
  final bool isScanning;

  // List of discovered BLE devices
  final List<BleDeviceInfo> scannedDevices;

  // Currently connected device
  final BleDeviceInfo? connectedDevice;

  // Whether you're the host in the connection
  final bool isHost;

  // Last error message
  final String? lastError;

  // Message ID of pending move awaiting ACK
  final int? pendingMoveId;

  // Whether currently connected
  bool get isConnected => connectionStatus == BleConnectionStatus.connected;

  // Whether a connection attempt is in progress
  bool get isConnecting =>
    connectionStatus == BleConnectionStatus.connecting ||
    connectionStatus == BleConnectionStatus.handshaking;

  // Whether there's an active error
  bool get hasError => connectionStatus == BleConnectionStatus.error;

  // Whether a move is pending ACK
  bool get hasPendingMove => pendingMoveId != null;

  BluetoothState copyWith({
    BleConnectionStatus? connectionStatus,
    bool? isBluetoothOn,
    bool? isScanning,
    List<BleDeviceInfo>? scannedDevices,
    BleDeviceInfo? connectedDevice,
    bool? isHost,
    String? lastError,
    int? pendingMoveId,
    bool clearConnectedDevice = false,
    bool clearError = false,
    bool clearPendingMove = false,
  }) {
    return BluetoothState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isBluetoothOn: isBluetoothOn ?? this.isBluetoothOn,
      isScanning: isScanning ?? this.isScanning,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      isHost: isHost ?? this.isHost,
      lastError: clearError ? null : (lastError ?? this.lastError),
      pendingMoveId: clearPendingMove ? null : (pendingMoveId ?? this.pendingMoveId),
    );
  }

  @override
  List<Object?> get props => [
    connectionStatus,
    isBluetoothOn,
    isScanning,
    scannedDevices,
    connectedDevice,
    isHost,
    lastError,
    pendingMoveId,
  ];

  @override
  String toString() => 'BluetoothState(status: $connectionStatus, isHost: $isHost, devices: ${scannedDevices.length})';
}

// Extension to convert infrastructure ConnectionState to UI BleConnectionStatus
extension ConnectionStateToStatus on cm.ConnectionState {
  BleConnectionStatus toBleStatus() {
    switch (this) {
      case cm.ConnectionState.disconnected:
        return BleConnectionStatus.disconnected;
      case cm.ConnectionState.connecting:
        return BleConnectionStatus.connecting;
      case cm.ConnectionState.handshaking:
        return BleConnectionStatus.handshaking;
      case cm.ConnectionState.connected:
        return BleConnectionStatus.connected;
      case cm.ConnectionState.reconnecting:
        return BleConnectionStatus.reconnecting;
      case cm.ConnectionState.error:
        return BleConnectionStatus.error;
    }
  }
}