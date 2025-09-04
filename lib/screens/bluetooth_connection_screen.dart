import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/platform_bluetooth_service.dart';
import 'game_screen.dart';

class BluetoothConnectionScreen extends StatefulWidget {
  final bool isHost;

  const BluetoothConnectionScreen({super.key, required this.isHost});

  @override
  State<BluetoothConnectionScreen> createState() => _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  bool _isScanning = false;
  bool _bluetoothInitialized = false;
  String _statusMessage = '';
  List<BluetoothDeviceInfo> _availableDevices = [];

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    setState(() {
      _statusMessage = 'Initializing Bluetooth...';
    });

    final initialized = await gameProvider.initializeBluetooth();
    
    if (initialized) {
      setState(() {
        _bluetoothInitialized = true;
        _statusMessage = widget.isHost 
            ? 'Waiting for guest to connect...' 
            : 'Scanning for host devices...';
      });

      if (widget.isHost) {
        // Host mode - start advertising
        await gameProvider.hostGame();
        _waitForConnection();
      } else {
        // Guest mode - start scanning
        _startScanning();
      }
    } else {
      setState(() {
        _statusMessage = 'Failed to initialize Bluetooth. Please check permissions and try again.';
      });
    }
  }

  void _waitForConnection() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Listen for game state changes
    gameProvider.addListener(() {
      if (gameProvider.gameState == GameState.playing) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    });
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for devices...';
      _availableDevices.clear();
    });

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Listen for discovered devices
    gameProvider.deviceStream.listen((device) {
      setState(() {
        if (!_availableDevices.any((d) => d.address == device.address)) {
          _availableDevices.add(device);
        }
      });
    });

    await gameProvider.scanForDevices();

    setState(() {
      _isScanning = false;
      _statusMessage = _availableDevices.isEmpty 
          ? 'No devices found. Make sure the host is advertising.'
          : 'Select a device to connect:';
    });
  }

  Future<void> _connectToDevice(BluetoothDeviceInfo device) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    setState(() {
      _statusMessage = 'Connecting to ${device.name}...';
    });

    final connected = await gameProvider.connectAsGuest(device);

    if (connected) {
      setState(() {
        _statusMessage = 'Connected! Waiting for game to start...';
      });

      // Wait for game to start
      gameProvider.addListener(() {
        if (gameProvider.gameState == GameState.playing) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GameScreen()),
          );
        }
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to connect. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHost ? 'Host Game' : 'Join Game'),
        backgroundColor: Colors.brown[200],
        foregroundColor: Colors.brown[800],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown[50]!, Colors.brown[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        widget.isHost ? Icons.wifi_tethering : Icons.bluetooth_searching,
                        size: 48,
                        color: Colors.brown[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isHost ? 'Hosting Game' : 'Looking for Games',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.brown[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Device List (for guests)
              if (!widget.isHost && _bluetoothInitialized) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Devices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.brown[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _isScanning ? null : _startScanning,
                      icon: const Icon(Icons.refresh),
                      color: Colors.brown[600],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _availableDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No devices found',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Make sure the host device is nearby and advertising',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _availableDevices.length,
                          itemBuilder: (context, index) {
                            final device = _availableDevices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  device.isClassic ? Icons.bluetooth : Icons.bluetooth_connected,
                                  color: Colors.brown[600],
                                ),
                                title: Text(
                                  device.name.isNotEmpty ? device.name : 'Unknown Device',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${device.address}\n${device.isClassic ? 'Classic Bluetooth' : 'Bluetooth LE'}',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _connectToDevice(device),
                              ),
                            );
                          },
                        ),
                ),
              ],

              // Instructions for host
              if (widget.isHost && _bluetoothInitialized) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 64,
                          color: Colors.brown[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your device is now discoverable',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.brown[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Other players can find and connect to your game',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Back button
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final gameProvider = Provider.of<GameProvider>(context, listen: false);
                    gameProvider.returnToMenu();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
