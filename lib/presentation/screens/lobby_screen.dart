import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/bluetooth_provider.dart';
import '../../application/states/bluetooth_state.dart';
import '../../application/states/lobby_state.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/piece.dart';
import '../../infrastructure/bluetooth/bluetooth_service.dart';
import '../routes/app_router.dart';
import '../widgets/dialogs/disconnect_dialog.dart';
import '../widgets/lobby/connection_status_widget.dart';
import '../widgets/lobby/device_list_widget.dart';
import '../widgets/lobby/scanning_indicator.dart';

// Arguments passed to the lobby screen via route settings.
class LobbyScreenArgs {
  const LobbyScreenArgs({required this.isHost, this.hostColor});

  final bool isHost;
  final PieceColor? hostColor;
}

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _gameNameController = TextEditingController();
  final _playerNameController = TextEditingController();
  bool _lobbyCreated = false;
  bool _isHost = false;
  PieceColor? _hostColor;

  @override
  void initState() {
    super.initState();
    _gameNameController.text = AppConstants.defaultGameName;
    _playerNameController.text = 'Player';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as LobbyScreenArgs?;
    if (args != null) {
      _isHost = args.isHost;
      _hostColor = args.hostColor;
    }
  }

  @override
  void dispose() {
    _gameNameController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(lobbyControllerProvider);
    final bleState = ref.watch(bluetoothControllerProvider);

    // Listen for state transitions to navigate or show dialogs
    ref.listen<LobbyState>(lobbyControllerProvider, (prev, next) {
      _onLobbyStateChanged(prev, next);
    });
    ref.listen<BluetoothState>(bluetoothControllerProvider, (prev, next) {
      _onBleStateChanged(prev, next);
    });

    return PopScope(
      canPop: !lobbyState.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && lobbyState.isActive) {
          await _leaveLobby();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isHost ? 'Host Game' : 'Find Game'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(lobbyState),
          ),
        ),
        body: _isHost
            ? SafeArea(
                child: _buildHostView(context, lobbyState, bleState),
              )
            // On some client devices, asymmetric horizontal safe-area insets
            // can make centered status content appear visually shifted.
            // Keep top/bottom protection while normalizing left/right.
            : SafeArea(
                top: true,
                bottom: true,
                left: false,
                right: false,
                child: _buildClientView(context, lobbyState, bleState),
              ),
      ),
    );
  }

  Widget _buildHostView(
    BuildContext context,
    LobbyState lobbyState,
    BluetoothState bleState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // If lobby is active (created and waiting/ready), show waiting state
    if (_lobbyCreated || lobbyState.isActive) {
      return _buildHostWaitingView(context, lobbyState, bleState);
    }

    // Initial host setup: enter game name and create lobby
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.wifi_tethering,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Create a Lobby',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your opponent will see this game name when scanning',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _gameNameController,
            decoration: const InputDecoration(
              labelText: 'Game Name',
              hintText: '${AppConstants.appName}_MyGame',
              prefixIcon: Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _playerNameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'Player',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createLobby(),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _createLobby,
            icon: const Icon(Icons.bluetooth),
            label: const Text('Create Lobby'),
          ),
          const SizedBox(height: 16),
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure Bluetooth is enabled and your opponent is nearby.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostWaitingView(
    BuildContext context,
    LobbyState lobbyState,
    BluetoothState bleState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          // Show connection status if connecting/handshaking
          if (bleState.isConnecting)
            ConnectionStatusWidget(
              status: bleState.connectionStatus,
            )
          else if (bleState.connectionStatus == BleConnectionStatus.error)
            ConnectionStatusWidget(
              status: bleState.connectionStatus,
              errorMessage: bleState.lastError,
              onRetry: _createLobby,
              onCancel: () => _handleBack(lobbyState),
            )
          else if (lobbyState.status == LobbyStatus.ready)
            _buildReadyView(context, lobbyState)
          else if (lobbyState.status == LobbyStatus.starting)
            _buildStartingView(context)
          else
            const AdvertisingIndicator(),
          const Spacer(),
          // Lobby info card
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    theme,
                    Icons.label_outline,
                    'Game',
                    lobbyState.lobbyName.isNotEmpty
                        ? lobbyState.lobbyName
                        : _gameNameController.text,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    theme,
                    Icons.person_outline,
                    'Host',
                    lobbyState.hostPlayerName.isNotEmpty
                        ? lobbyState.hostPlayerName
                        : _playerNameController.text,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    theme,
                    Icons.circle,
                    'Playing as',
                    _hostColor == PieceColor.black ? 'Black' : 'White',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleBack(lobbyState),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientView(
    BuildContext context,
    LobbyState lobbyState,
    BluetoothState bleState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // If currently connecting or further along, show connection status
    if (bleState.isConnecting ||
        bleState.connectionStatus == BleConnectionStatus.reconnecting) {
      return _buildClientCenteredStatusShell(
        child: ConnectionStatusWidget(
          status: bleState.connectionStatus,
          onCancel: () => _handleBack(lobbyState),
        ),
      );
    }

    // If connected and ready, show ready view
    if (lobbyState.status == LobbyStatus.ready) {
      return _buildClientCenteredStatusShell(
        child: _buildReadyView(context, lobbyState),
      );
    }

    // If error, show error with retry
    if (bleState.connectionStatus == BleConnectionStatus.error ||
        lobbyState.status == LobbyStatus.error) {
      return _buildClientCenteredStatusShell(
        child: ConnectionStatusWidget(
          status: BleConnectionStatus.error,
          errorMessage: bleState.lastError ?? lobbyState.lastError,
          onRetry: _startScan,
          onCancel: () => _handleBack(lobbyState),
        ),
      );
    }

    // Default: scanning / initial state
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player name input
          TextField(
            controller: _playerNameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'Player',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          // Scan controls
          if (bleState.isScanning) ...[
            const ScanningIndicator(),
            const SizedBox(height: 24),
            // Device list
            if (bleState.scannedDevices.isNotEmpty) ...[
              Text(
                'Available Games',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            DeviceListWidget(
              devices: bleState.scannedDevices,
              onDeviceTap: _joinGame,
              connectingDeviceId: bleState.isConnecting
                  ? bleState.connectedDevice?.id
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _stopScan,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Scanning'),
            ),
          ] else ...[
            // Not scanning yet
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Find Nearby Games',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan for hosts that have created a lobby',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.search),
                    label: const Text('Start Scanning'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientCenteredStatusShell({required Widget child}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: child,
        ),
      ),
    );
  }

  Widget _buildReadyView(BuildContext context, LobbyState lobbyState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle,
          size: 64,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Opponent Connected!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (lobbyState.opponentName.isNotEmpty)
          Text(
            lobbyState.opponentName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        if (lobbyState.isHost)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game'),
            ),
          )
        else ...
          [
            const SizedBox(height: 8),
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 16),
            Text(
              'Waiting for host to start the game...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
      ],
    );
  }

  Widget _buildStartingView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator.adaptive(),
        const SizedBox(height: 16),
        Text(
          'Starting game...',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _createLobby() async {
    final gameName = _gameNameController.text.trim();
    final playerName = _playerNameController.text.trim();

    if (gameName.isEmpty || playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a game name and your name')),
      );
      return;
    }

    final lobbyController = ref.read(lobbyControllerProvider.notifier);
    await lobbyController.createLobby(
      gameName: gameName,
      playerName: playerName,
      hostColor: _hostColor ?? PieceColor.white,
    );

    setState(() => _lobbyCreated = true);
  }

  Future<void> _startScan() async {
    final btController = ref.read(bluetoothControllerProvider.notifier);
    await btController.startScanning();
  }

  Future<void> _stopScan() async {
    final btController = ref.read(bluetoothControllerProvider.notifier);
    await btController.stopScanning();
  }

  Future<void> _joinGame(BleDeviceInfo device) async {
    final playerName = _playerNameController.text.trim();
    if (playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name first')),
      );
      return;
    }

    final lobbyController = ref.read(lobbyControllerProvider.notifier);
    await lobbyController.joinGame(device: device, playerName: playerName);
  }

  void _startGame() {
    final lobbyController = ref.read(lobbyControllerProvider.notifier);
    lobbyController.startGame();
  }

  Future<void> _leaveLobby() async {
    final lobbyController = ref.read(lobbyControllerProvider.notifier);
    await lobbyController.leaveLobby();
    setState(() => _lobbyCreated = false);
  }

  Future<void> _handleBack(LobbyState lobbyState) async {
    if (lobbyState.isActive) {
      await _leaveLobby();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _onLobbyStateChanged(LobbyState? prev, LobbyState next) {
    // Navigate to game when lobby transitions to inGame
    if (next.status == LobbyStatus.inGame &&
        prev?.status != LobbyStatus.inGame) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.game);
    }
  }

  void _onBleStateChanged(BluetoothState? prev, BluetoothState next) {
    // Show disconnect dialog if connection drops while in active lobby
    if (prev?.connectionStatus == BleConnectionStatus.connected &&
        next.connectionStatus == BleConnectionStatus.disconnected) {
      final lobbyState = ref.read(lobbyControllerProvider);
      if (lobbyState.isActive) {
        _showDisconnectDialog();
      }
    }
  }

  Future<void> _showDisconnectDialog() async {
    if (!mounted) return;

    final result = await showDisconnectDialog(
      context,
      errorMessage: ref.read(bluetoothControllerProvider).lastError,
    );

    if (!mounted) return;

    if (result == true) {
      // Reconnect: for client, restart scanning; for host, re-create lobby
      if (_isHost) {
        _createLobby();
      } else {
        _startScan();
      }
    } else {
      // Exit
      await _leaveLobby();
      if (mounted) Navigator.of(context).pop();
    }
  }
}