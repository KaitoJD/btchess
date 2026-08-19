import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/constants/timing_constants.dart';
import '../../core/errors/ble_exception.dart';
import '../../core/utils/logger.dart';
import 'ble_connection.dart';
import 'ble_peripheral.dart';
import 'ble_setup.dart';

class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });

  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;
}

/// Owns one central-side connect/pair/reconnect attempt.
///
/// Pairing belongs to Android/iOS system UI.  This object only observes its
/// progress, pauses app-level GATT work while it is in progress, and makes
/// late callbacks harmless once the user cancels or a newer attempt starts.
class BleConnectionAttempt {
  BleConnectionAttempt({
    required this.id,
    required this.isHost,
    required this.deadline,
    required this.platform,
  }) {
    final timeout = deadline.difference(DateTime.now());
    _deadlineTimer = Timer(timeout.isNegative ? Duration.zero : timeout, () {
      const error = BleTimeoutException(
        'Bluetooth setup timed out',
        timeout: Duration(
          milliseconds: TimingConstants.connectionSetupTimeoutMs,
        ),
      );
      fail(error, reason: 'setup deadline elapsed');
    });
    // The controller normally awaits [connection], while callers that only
    // render phaseStream may never subscribe to [result].  Mark both internal
    // futures as observed without changing the error seen by real callers.
    _connectionCompleter.future.ignore();
    _resultCompleter.future.ignore();
  }

  final int id;
  final bool isHost;
  final DateTime deadline;
  final String platform;

  final StreamController<PeerSetupEvent> _phaseController =
      StreamController<PeerSetupEvent>.broadcast();
  final Completer<BleConnection> _connectionCompleter =
      Completer<BleConnection>();
  final Completer<BleConnection> _resultCompleter = Completer<BleConnection>();
  final Completer<BleSetupPhase> _terminalCompleter =
      Completer<BleSetupPhase>();

  Timer? _deadlineTimer;
  Future<void> Function()? _cancelAction;
  BleSetupPhase? _phase;
  BleConnection? _preparedConnection;
  bool _cancelled = false;

  /// Receives every meaningful setup phase for this attempt.
  Stream<PeerSetupEvent> get phaseStream => _phaseController.stream;

  /// Completes after a fresh GATT connection has discovered its services and
  /// subscribed to notifications.  The caller then runs the protocol
  /// handshake and calls [complete] using this same attempt.
  Future<BleConnection> get connection => _connectionCompleter.future;

  /// Completes only when the full setup attempt is ready, including the
  /// controller-owned protocol handshake.
  Future<BleConnection> get result => _resultCompleter.future;

  /// Alias for [result], matching the setup contract's completion wording.
  Future<BleConnection> get completion => result;

  /// Completes when this attempt is ready, failed, or cancelled.  Internal
  /// waits race against it so cancellation does not leave a 90-second timer
  /// alive in the background.
  Future<BleSetupPhase> get terminal => _terminalCompleter.future;

  BleSetupPhase? get phase => _phase;
  bool get isCancelled => _cancelled;
  bool get isActive => !_cancelled && !(_phase?.isTerminal ?? false);
  Duration get remaining {
    final duration = deadline.difference(DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }

  /// Lets the controller include its handshaking/ready phases in the same
  /// attempt timeline.  Calls after cancellation or terminal failure are
  /// deliberately ignored.
  void reportPhase(BleSetupPhase phase, {String? reason}) {
    if (!isActive || phase.isTerminal) return;
    _emit(phase, reason: reason);
  }

  /// Marks the protocol as ready after the caller finishes its handshake.
  void complete() {
    if (!isActive) return;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _emit(BleSetupPhase.ready);
    final connection = _preparedConnection;
    if (!_resultCompleter.isCompleted) {
      if (connection == null) {
        _resultCompleter.completeError(
          const BleConnectionException(
            'Bluetooth setup completed before a transport was prepared',
          ),
        );
      } else {
        _resultCompleter.complete(connection);
      }
    }
    _completeTerminal(BleSetupPhase.ready);
    _closePhaseStream();
  }

  /// Marks the attempt failed and invalidates all pending callbacks.
  void fail(Object error, {String? reason, StackTrace? stackTrace}) {
    if (!isActive) return;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _emit(BleSetupPhase.failed, reason: reason ?? 'setup failed');
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.completeError(error, stackTrace);
    }
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.completeError(error, stackTrace);
    }
    _completeTerminal(BleSetupPhase.failed);
    final cancelAction = _cancelAction;
    if (cancelAction != null) {
      unawaited(cancelAction());
    }
    _closePhaseStream();
  }

  /// Cancels this app-level attempt.  It intentionally does not attempt to
  /// dismiss the operating system's pairing dialog or delete a saved bond.
  Future<void> cancel() async {
    if (!isActive) return;
    _cancelled = true;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _emit(BleSetupPhase.cancelled, reason: 'cancelled by user or superseded');

    final cancelAction = _cancelAction;
    if (cancelAction != null) {
      try {
        await cancelAction();
      } catch (_) {
        // Cancellation must remain idempotent even when GATT has already
        // disappeared due to the system pairing flow.
      }
    }

    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.completeError(
        const BleDisconnectedException('Bluetooth setup attempt cancelled'),
      );
    }
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.completeError(
        const BleDisconnectedException('Bluetooth setup attempt cancelled'),
      );
    }
    _completeTerminal(BleSetupPhase.cancelled);
    _closePhaseStream();
  }

  void _setCancelAction(Future<void> Function() cancelAction) {
    _cancelAction = cancelAction;
    if (_cancelled) {
      unawaited(cancelAction());
    }
  }

  void _completeConnection(BleConnection connection) {
    if (!isActive || _connectionCompleter.isCompleted) return;
    _preparedConnection = connection;
    _connectionCompleter.complete(connection);
  }

  void _emit(BleSetupPhase phase, {String? reason}) {
    _phase = phase;
    final event = PeerSetupEvent(
      attemptId: id,
      phase: phase,
      isHost: isHost,
      platform: platform,
      occurredAt: DateTime.now(),
      reason: reason,
    );
    if (!_phaseController.isClosed) {
      _phaseController.add(event);
    }
    Logger.debug(
      'BLE setup attempt=$id role=${isHost ? 'host' : 'client'} '
      'platform=$platform phase=${phase.name}'
      '${reason == null ? '' : ' reason=$reason'}',
      tag: 'BluetoothService',
    );
  }

  void _closePhaseStream() {
    if (!_phaseController.isClosed) {
      unawaited(_phaseController.close());
    }
  }

  void _completeTerminal(BleSetupPhase phase) {
    if (!_terminalCompleter.isCompleted) {
      _terminalCompleter.complete(phase);
    }
  }
}

class BluetoothService {
  // BLE peripheral manager for host advertising mode
  final BlePeripheralManager _peripheralManager = BlePeripheralManager();

  // Stream controller for scanned devices
  final StreamController<List<BleDeviceInfo>> _devicesController =
      StreamController<List<BleDeviceInfo>>.broadcast();

  // Currently discovered devices
  final Map<String, BleDeviceInfo> _discoveredDevices = {};

  // Scan subscription
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Optional timer for switching from service-filter scan to broad scan
  Timer? _scanFallbackTimer;

  // Tracks scan timing and mode for diagnostics.
  DateTime? _scanStartedAt;
  bool _isFallbackScanActive = false;
  bool _hasLoggedFirstDevice = false;

  // Whether currently scanning
  bool _isScanning = false;

  // Only one central-side setup attempt may own a remote device at a time.
  // Replacing it cancels the old generation so stale platform callbacks cannot
  // revive an abandoned lobby.
  BleConnectionAttempt? _activeCentralAttempt;
  int _nextConnectionAttemptId = 0;

  // Stream of discovered devices
  Stream<List<BleDeviceInfo>> get discoveredDevices =>
      _devicesController.stream;

  // Whether BLE is supported on this device
  Future<bool> get isSupported async {
    return FlutterBluePlus.isSupported;
  }

  // Whether Bluetooth is currently on
  Future<bool> get isBluetoothOn async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  // Stream of Bluetooth adapter state changes
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  // Whether currently scanning
  bool get isScanning => _isScanning;

  // Checks if all required permission are granted
  Future<bool> checkPermissions() async {
    // flutter_blue_plus handles permission requests internally
    // This is a simplified check
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return false;

      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  // Request Bluetooth to be turned on
  Future<void> requestBluetoothOn() async {
    await FlutterBluePlus.turnOn();
  }

  // Starts scanning for BTChess devices
  Future<void> startScanning() async {
    if (_isScanning) return;

    final isOn = await isBluetoothOn;
    if (!isOn) {
      throw const BleNotAvailableException('Bluetooth is not enabled');
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _scanStartedAt = DateTime.now();
    _isFallbackScanActive = Platform.isIOS;
    _hasLoggedFirstDevice = false;

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: _handleScanError,
    );

    if (Platform.isIOS) {
      Logger.debug(
        'Starting compatibility-first broad scan on iOS',
        tag: 'BluetoothService',
      );
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );
      _scanFallbackTimer?.cancel();
      _scanFallbackTimer = null;
    } else {
      Logger.debug(
        'Starting service-filtered scan (fallback in ${BleConstants.scanFallbackDelaySeconds}s)',
        tag: 'BluetoothService',
      );
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );

      _scheduleScanFallback();
    }
  }

  void _scheduleScanFallback() {
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = Timer(
      const Duration(seconds: BleConstants.scanFallbackDelaySeconds),
      () async {
        if (!_isScanning || _discoveredDevices.isNotEmpty) {
          return;
        }

        try {
          final elapsed = _scanStartedAt == null
              ? null
              : DateTime.now().difference(_scanStartedAt!).inMilliseconds;
          Logger.debug(
            'No devices found with service-filtered scan, retrying without service filter '
            '(elapsed=${elapsed ?? -1}ms)',
            tag: 'BluetoothService',
          );
          _isFallbackScanActive = true;
          await FlutterBluePlus.stopScan();
          await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
          );
        } catch (e) {
          Logger.warn(
            'Failed to switch to scan fallback mode (${e.runtimeType})',
            tag: 'BluetoothService',
          );
        }
      },
    );
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final device = result.device;
      final extracted = _extractDeviceName(result);
      final name = extracted.name;

      if (name.startsWith(BleConstants.deviceNamePrefix)) {
        _discoveredDevices[device.remoteId.str] = BleDeviceInfo(
          id: device.remoteId.str,
          name: name,
          rssi: result.rssi,
          device: device,
        );

        if (!_hasLoggedFirstDevice) {
          _hasLoggedFirstDevice = true;
          final elapsed = _scanStartedAt == null
              ? null
              : DateTime.now().difference(_scanStartedAt!).inMilliseconds;
          Logger.debug(
            'First BTChess device discovered in ${elapsed ?? -1}ms '
            '(scanMode=${_isFallbackScanActive ? 'fallback' : 'service-filtered'}, '
            'nameSource=${extracted.source})',
            tag: 'BluetoothService',
          );
        }
      }
    }

    _devicesController.add(_discoveredDevices.values.toList());
  }

  ({String name, String source}) _extractDeviceName(ScanResult result) {
    String? fromLocalName;
    String? fromAdvName;

    // Access advertisement fields dynamically so we remain compatible
    // across minor plugin API differences.
    final advData = result.advertisementData as dynamic;
    try {
      fromLocalName = advData.localName as String?;
    } catch (_) {}
    try {
      fromAdvName = advData.advName as String?;
    } catch (_) {}

    final localName = (fromLocalName ?? '').trim();
    if (localName.isNotEmpty) {
      return (name: localName, source: 'advertisement.localName');
    }

    final advName = (fromAdvName ?? '').trim();
    if (advName.isNotEmpty) {
      return (name: advName, source: 'advertisement.advName');
    }

    final platformName = result.device.platformName.trim();
    return (name: platformName, source: 'device.platformName');
  }

  void _handleScanError(Object error) {
    Logger.error('Scan error (${error.runtimeType})', tag: 'BluetoothService');
    _isScanning = false;
  }

  // Stops scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await FlutterBluePlus.stopScan();
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = null;
    _scanStartedAt = null;
    _isFallbackScanActive = false;
    _hasLoggedFirstDevice = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  /// Starts a central/client connection attempt immediately.
  ///
  /// The returned object owns the 90-second setup deadline.  Its GATT
  /// transport becomes available through [BleConnectionAttempt.connection];
  /// callers should then report `handshaking`/`ready` on the same attempt so
  /// the UI observes one continuous connect → pair → reconnect flow.
  BleConnectionAttempt startConnectionAttempt(
    BleDeviceInfo deviceInfo, {
    bool asHost = false,
  }) {
    final previous = _activeCentralAttempt;
    if (previous != null && previous.isActive) {
      unawaited(previous.cancel());
    }

    final attempt = BleConnectionAttempt(
      id: ++_nextConnectionAttemptId,
      isHost: asHost,
      deadline: DateTime.now().add(
        const Duration(milliseconds: TimingConstants.connectionSetupTimeoutMs),
      ),
      platform: _platformLabel,
    );
    _activeCentralAttempt = attempt;

    // Starting in a microtask gives the controller a chance to subscribe to
    // phaseStream before the first `connecting` event is emitted.
    unawaited(
      Future<void>.microtask(
        () => _runCentralAttempt(attempt, deviceInfo, asHost: asHost),
      ),
    );
    return attempt;
  }

  /// Compatibility wrapper for callers that only need a connected transport.
  /// New setup flows should use [startConnectionAttempt] to surface pairing
  /// progress and preserve cancellation identity through the handshake.
  Future<BleConnection> connect(
    BleDeviceInfo deviceInfo, {
    bool asHost = false,
  }) async {
    final attempt = startConnectionAttempt(deviceInfo, asHost: asHost);
    final connection = await attempt.connection;
    attempt.complete();
    return connection;
  }

  Future<void> _runCentralAttempt(
    BleConnectionAttempt attempt,
    BleDeviceInfo initialDeviceInfo, {
    required bool asHost,
  }) async {
    var deviceInfo = initialDeviceInfo;
    var device = deviceInfo.device;
    StreamSubscription<BluetoothConnectionState>? linkSubscription;
    StreamSubscription<BluetoothBondState>? bondSubscription;
    var linkConnected = false;
    var hasEverConnected = false;
    var linkGeneration = 0;
    var pairingInProgress = false;
    var pairingWasObserved = false;
    DateTime? lastStaleHandleRescanAt;
    Completer<BluetoothBondState>? pairingOutcome;

    void updateLinkState({required bool connected}) {
      if (connected && !linkConnected) {
        linkGeneration++;
      }
      linkConnected = connected;
      hasEverConnected = hasEverConnected || connected;
    }

    void ensureAttemptActive() {
      if (!attempt.isActive) {
        throw const BleDisconnectedException(
          'Bluetooth setup attempt is no longer active',
        );
      }
      if (attempt.remaining.inMilliseconds <= 0) {
        throw const BleTimeoutException(
          'Bluetooth setup timed out',
          timeout: Duration(
            milliseconds: TimingConstants.connectionSetupTimeoutMs,
          ),
        );
      }
    }

    DateTime boundedDeadline([DateTime? secondaryDeadline]) {
      if (secondaryDeadline == null ||
          secondaryDeadline.isAfter(attempt.deadline)) {
        return attempt.deadline;
      }
      return secondaryDeadline;
    }

    Future<T> awaitForAttempt<T>(
      Future<T> operation, {
      DateTime? secondaryDeadline,
    }) async {
      ensureAttemptActive();
      final deadline = boundedDeadline(secondaryDeadline);
      final remaining = deadline.difference(DateTime.now());
      if (remaining.inMilliseconds <= 0) {
        throw const BleTimeoutException(
          'Bluetooth setup timed out',
          timeout: Duration(
            milliseconds: TimingConstants.connectionSetupTimeoutMs,
          ),
        );
      }

      return Future.any<T>([
        operation,
        Future<T>.delayed(
          remaining,
          () => throw const BleTimeoutException(
            'Bluetooth setup timed out',
            timeout: Duration(
              milliseconds: TimingConstants.connectionSetupTimeoutMs,
            ),
          ),
        ),
        attempt.terminal.then<T>(
          (_) => throw const BleDisconnectedException(
            'Bluetooth setup attempt ended before the operation completed',
          ),
        ),
      ]);
    }

    Future<void> delayForAttempt(
      Duration duration, {
      DateTime? secondaryDeadline,
    }) {
      return awaitForAttempt<void>(
        Future<void>.delayed(duration),
        secondaryDeadline: secondaryDeadline,
      );
    }

    Future<void> cancelSubscriptions() async {
      await linkSubscription?.cancel();
      await bondSubscription?.cancel();
      linkSubscription = null;
      bondSubscription = null;
    }

    Future<void> replaceObservedDevice(BleDeviceInfo replacement) async {
      await cancelSubscriptions();
      deviceInfo = replacement;
      device = replacement.device;
      updateLinkState(connected: false);
      pairingInProgress = false;
      pairingOutcome = null;

      linkSubscription = device.connectionState.listen((connectionState) {
        if (!attempt.isActive) return;

        if (connectionState == BluetoothConnectionState.connected) {
          updateLinkState(connected: true);
          return;
        }

        if (!hasEverConnected) return;
        updateLinkState(connected: false);
        if (pairingInProgress) {
          attempt.reportPhase(
            BleSetupPhase.awaitingReconnect,
            reason: 'GATT link changed during pairing',
          );
        }
      });

      if (Platform.isAndroid) {
        bondSubscription = device.bondState.listen((bondState) {
          if (!attempt.isActive) return;

          if (bondState == BluetoothBondState.bonding) {
            pairingWasObserved = true;
            if (!pairingInProgress) {
              pairingInProgress = true;
              pairingOutcome = Completer<BluetoothBondState>();
            }
            attempt.reportPhase(BleSetupPhase.pairing);
            return;
          }

          if (!pairingInProgress) return;
          pairingInProgress = false;
          final outcome = pairingOutcome;
          if (outcome != null && !outcome.isCompleted) {
            outcome.complete(bondState);
          }

          if (bondState == BluetoothBondState.bonded && !linkConnected) {
            attempt.reportPhase(
              BleSetupPhase.awaitingReconnect,
              reason: 'bond completed; waiting for GATT reconnect',
            );
          }
        });
      }
    }

    attempt._setCancelAction(() async {
      await cancelSubscriptions();
      try {
        await device.disconnect();
      } catch (_) {
        // GATT can already be gone after a system-managed pairing transition.
      }
    });

    Future<void> connectLink({
      required bool reconnecting,
      DateTime? reconnectDeadline,
    }) async {
      final retryDeadline = boundedDeadline(reconnectDeadline);
      var physicalAttempt = 0;

      while (true) {
        ensureAttemptActive();
        if (retryDeadline.difference(DateTime.now()).inMilliseconds <= 0) {
          throw BleTimeoutException(
            reconnecting
                ? 'Timed out waiting for BLE reconnect after pairing'
                : 'Timed out opening BLE link',
            timeout: reconnecting
                ? const Duration(
                    milliseconds: TimingConstants.pairingReconnectTimeoutMs,
                  )
                : const Duration(
                    milliseconds: TimingConstants.connectionSetupTimeoutMs,
                  ),
          );
        }

        physicalAttempt++;
        attempt.reportPhase(
          reconnecting
              ? BleSetupPhase.awaitingReconnect
              : BleSetupPhase.connecting,
          reason: reconnecting ? 'reconnect attempt $physicalAttempt' : null,
        );

        try {
          if (!device.isConnected) {
            final remainingMs = retryDeadline
                .difference(DateTime.now())
                .inMilliseconds
                .clamp(1, TimingConstants.connectionTimeoutMs)
                .toInt();
            await awaitForAttempt<void>(
              device.connect(
                license: License.nonprofit,
                // Do not let connect request MTU before bond state has settled.
                mtu: null,
                timeout: Duration(milliseconds: remainingMs),
              ),
              secondaryDeadline: retryDeadline,
            );
          }
          ensureAttemptActive();
          updateLinkState(connected: device.isConnected);
          return;
        } catch (error) {
          if (!attempt.isActive) rethrow;
          if (!_isRecoverableConnectFailure(error) ||
              retryDeadline.difference(DateTime.now()).inMilliseconds <= 0) {
            rethrow;
          }

          final canRescanStaleHandle =
              lastStaleHandleRescanAt == null ||
              DateTime.now()
                      .difference(lastStaleHandleRescanAt!)
                      .inMilliseconds >=
                  TimingConstants.staleHandleRescanCooldownMs;
          if (_shouldRescanForStaleHandle(error) && canRescanStaleHandle) {
            lastStaleHandleRescanAt = DateTime.now();
            final replacement = await _rescanExactLobby(
              expectedName: deviceInfo.name,
              attempt: attempt,
              deadline: retryDeadline,
            );
            if (replacement != null) {
              await replaceObservedDevice(replacement);
            }
          }

          Logger.warn(
            'BLE setup attempt=${attempt.id} retrying link after '
            '${error.runtimeType}',
            tag: 'BluetoothService',
          );
          await delayForAttempt(
            const Duration(
              milliseconds: TimingConstants.connectionRetryDelayMs,
            ),
            secondaryDeadline: retryDeadline,
          );
        }
      }
    }

    Future<void> waitForPairingAndUsableLink() async {
      ensureAttemptActive();
      if (Platform.isAndroid) {
        // The peripheral initiates createBond asynchronously after the raw
        // link arrives.  Give its BOND_BONDING callback a small observation
        // window before any app-level MTU/discovery/subscribe operation.
        await delayForAttempt(
          const Duration(
            milliseconds: TimingConstants.pairingObservationDelayMs,
          ),
        );

        if (pairingInProgress) {
          attempt.reportPhase(BleSetupPhase.pairing);
          final result = await awaitForAttempt<BluetoothBondState>(
            pairingOutcome!.future,
          );
          if (result != BluetoothBondState.bonded) {
            throw const BleConnectionException(
              'Pairing was cancelled or rejected. Confirm the code on both devices and retry.',
            );
          }
        }
      }

      if (linkConnected && device.isConnected) return;

      final reconnectDeadline = DateTime.now().add(
        const Duration(milliseconds: TimingConstants.pairingReconnectTimeoutMs),
      );
      await connectLink(
        reconnecting: hasEverConnected || pairingWasObserved,
        reconnectDeadline: reconnectDeadline,
      );

      // A reconnect after BOND_BONDED always starts with fresh discovery and
      // characteristic handles.  If pairing re-enters meanwhile, wait again.
      if (Platform.isAndroid && pairingInProgress) {
        await waitForPairingAndUsableLink();
      }
    }

    Future<BleConnection> initializeFreshGatt() async {
      await waitForPairingAndUsableLink();

      if (Platform.isAndroid) {
        try {
          await awaitForAttempt<int>(device.requestMtu(BleConstants.maxMtu));
        } catch (error) {
          if (!device.isConnected || pairingInProgress) rethrow;
          Logger.warn(
            'BLE setup attempt=${attempt.id} could not negotiate MTU '
            '(${error.runtimeType}); continuing with the platform MTU',
            tag: 'BluetoothService',
          );
        }
      }

      await waitForPairingAndUsableLink();
      final setupLinkGeneration = linkGeneration;
      final connection = BleConnection(device: device, isHost: asHost);
      await connection.initialize(
        beforeDiscovery: waitForPairingAndUsableLink,
        beforeSubscription: waitForPairingAndUsableLink,
        onPhase: (phase) {
          switch (phase) {
            case BleConnectionInitializationPhase.discovering:
              attempt.reportPhase(BleSetupPhase.discovering);
              break;
            case BleConnectionInitializationPhase.subscribing:
              attempt.reportPhase(BleSetupPhase.subscribing);
              break;
          }
        },
      );
      await waitForPairingAndUsableLink();
      if (linkGeneration != setupLinkGeneration) {
        throw const BleDisconnectedException(
          'GATT link changed during setup; fresh characteristics are required',
        );
      }
      return connection;
    }

    try {
      await stopScanning();
      await replaceObservedDevice(deviceInfo);
      await connectLink(reconnecting: false);

      while (true) {
        BleConnection? connection;
        try {
          connection = await initializeFreshGatt();
          ensureAttemptActive();
          attempt._completeConnection(connection);
          return;
        } catch (error) {
          if (!attempt.isActive) return;
          if (_isPairingRejected(error)) rethrow;

          final shouldRecover = _isRecoverableInitialSetupFailure(
            error,
            pairingWasObserved: pairingWasObserved,
            linkConnected: linkConnected,
          );
          if (!shouldRecover) rethrow;

          if (connection != null) {
            await connection.disconnect();
          } else if (device.isConnected && !pairingInProgress) {
            try {
              await device.disconnect();
            } catch (_) {
              // The next connect attempt is still valid if this cleanup loses
              // a race with Android's pairing-triggered disconnect.
            }
          }
          updateLinkState(connected: false);

          Logger.warn(
            'BLE setup attempt=${attempt.id} recovering initial GATT setup '
            'after ${error.runtimeType}',
            tag: 'BluetoothService',
          );
          await delayForAttempt(
            const Duration(
              milliseconds: TimingConstants.connectionRetryDelayMs,
            ),
          );
          await connectLink(
            reconnecting: true,
            reconnectDeadline: DateTime.now().add(
              const Duration(
                milliseconds: TimingConstants.pairingReconnectTimeoutMs,
              ),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      if (attempt.isActive) {
        final normalized = error is BleException
            ? error
            : BleConnectionException(
                'Failed to establish Bluetooth connection',
                originalError: error,
              );
        attempt.fail(
          normalized,
          stackTrace: stackTrace,
          reason: _failureReason(error),
        );
      }
    } finally {
      await cancelSubscriptions();
    }
  }

  bool _isRecoverableConnectFailure(Object error) {
    final text = error.toString().toLowerCase();

    // Permission and adapter-state failures need an explicit user action;
    // retrying them for the setup deadline only hides the real problem.
    if (text.contains('permission')) return false;
    if (text.contains('bluetooth is not enabled')) return false;

    // Common transient failures while the OS finishes pairing/bonding or
    // while private addresses rotate and are re-resolved.
    if (text.contains('device not found')) return true;
    if (text.contains('bond')) return true;
    if (text.contains('pair')) return true;
    if (text.contains('status 133')) return true;
    if (text.contains('gatt error')) return true;
    if (text.contains('timeout')) return true;

    // Core Bluetooth does not expose a bond state.  During initial setup, a
    // disconnect or GATT error can simply mean that system pairing UI is still
    // resolving access, so treat it as recoverable until the common deadline.
    if (Platform.isIOS) return true;

    return false;
  }

  bool _isRecoverableInitialSetupFailure(
    Object error, {
    required bool pairingWasObserved,
    required bool linkConnected,
  }) {
    if (_isPairingRejected(error)) return false;
    if (_isRecoverableConnectFailure(error)) return true;
    if (error is BleDisconnectedException || error is BleTimeoutException) {
      return true;
    }

    // Android needs this extra allowance for a service discovery operation
    // interrupted by an asynchronously created bond.
    return pairingWasObserved || !linkConnected;
  }

  bool _isPairingRejected(Object error) {
    return error.toString().toLowerCase().contains('pairing was cancelled');
  }

  bool _shouldRescanForStaleHandle(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('device not found') ||
        text.contains('remote device') ||
        text.contains('invalid handle');
  }

  Future<BleDeviceInfo?> _rescanExactLobby({
    required String expectedName,
    required BleConnectionAttempt attempt,
    required DateTime deadline,
  }) async {
    final candidates = <String, BleDeviceInfo>{};
    final remaining = deadline.difference(DateTime.now());
    if (!attempt.isActive || remaining.inMilliseconds <= 0) return null;

    final scanWindowMs = remaining.inMilliseconds.clamp(
      1,
      BleConstants.scanTimeoutSeconds * 1000,
    );
    final scanWindow = Duration(milliseconds: scanWindowMs.toInt());

    final subscription = FlutterBluePlus.scanResults.listen((results) {
      if (!attempt.isActive) return;
      for (final result in results) {
        final name = _extractDeviceName(result).name;
        // The service UUID filter below and exact name match prevent a stale
        // remote handle from silently switching the user to another lobby.
        if (name != expectedName) continue;
        candidates[result.device.remoteId.str] = BleDeviceInfo(
          id: result.device.remoteId.str,
          name: name,
          rssi: result.rssi,
          device: result.device,
        );
      }
    });

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: scanWindow,
      );
      await _awaitAttemptOperation<void>(
        attempt,
        Future<void>.delayed(scanWindow),
        deadline: deadline,
      );
    } catch (_) {
      // A stale-handle scan is best effort.  The ordinary reconnect loop will
      // continue to use the original device if no unambiguous replacement is
      // found before its deadline.
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await subscription.cancel();
    }

    if (!attempt.isActive || candidates.length != 1) {
      Logger.warn(
        'BLE setup attempt=${attempt.id} stale-handle scan produced '
        '${candidates.isEmpty ? 'no' : 'multiple'} exact matches',
        tag: 'BluetoothService',
      );
      return null;
    }

    Logger.debug(
      'BLE setup attempt=${attempt.id} replaced a stale remote handle after '
      'one exact lobby match',
      tag: 'BluetoothService',
    );
    return candidates.values.single;
  }

  Future<T> _awaitAttemptOperation<T>(
    BleConnectionAttempt attempt,
    Future<T> operation, {
    required DateTime deadline,
  }) {
    final remaining = deadline.difference(DateTime.now());
    if (!attempt.isActive || remaining.inMilliseconds <= 0) {
      return Future<T>.error(
        const BleDisconnectedException('Bluetooth setup attempt is inactive'),
      );
    }

    return Future.any<T>([
      operation,
      Future<T>.delayed(
        remaining,
        () => throw const BleTimeoutException(
          'Bluetooth setup timed out',
          timeout: Duration(
            milliseconds: TimingConstants.connectionSetupTimeoutMs,
          ),
        ),
      ),
      attempt.terminal.then<T>(
        (_) => throw const BleDisconnectedException(
          'Bluetooth setup attempt ended before scan completed',
        ),
      ),
    ]);
  }

  String _failureReason(Object error) {
    final description = error.toString().toLowerCase();
    if (description.contains('reconnect after pairing')) {
      return 'Stale pairing information. Forget this device on both phones, then scan again.';
    }
    if (_isPairingRejected(error)) return 'pairing was rejected or cancelled';
    if (error is BleTimeoutException || error is TimeoutException) {
      return 'setup timed out';
    }
    if (error is BleDisconnectedException) return 'GATT link disconnected';
    return 'setup failed (${error.runtimeType})';
  }

  String get _platformLabel {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  // The peripheral manager for host mode
  BlePeripheralManager get peripheralManager => _peripheralManager;

  // Starts advertising as a host using BlePeripheralManager
  Future<void> startAdvertising(String gameName) async {
    await _peripheralManager.initialize();
    await _peripheralManager.startAdvertising(gameName);
  }

  // Stops advertising
  Future<void> stopAdvertising() async {
    await _peripheralManager.stopAdvertising();
  }

  // Gets currently connected devices
  Future<List<BluetoothDevice>> getConnectedDevices() async {
    return FlutterBluePlus.connectedDevices;
  }

  // Disposes resources
  void dispose() {
    final activeAttempt = _activeCentralAttempt;
    if (activeAttempt != null && activeAttempt.isActive) {
      unawaited(activeAttempt.cancel());
    }
    _activeCentralAttempt = null;
    _scanFallbackTimer?.cancel();
    _scanFallbackTimer = null;
    stopScanning();
    _peripheralManager.dispose();
    _devicesController.close();
  }
}
