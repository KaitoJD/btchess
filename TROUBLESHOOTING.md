# 🛠️ BTChess Troubleshooting Guide

## Common Issues

### 1. Bluetooth not working
- Ensure Bluetooth is enabled on both devices
- Grant all requested permissions when prompted
- Try restarting the app
- Check if Bluetooth is properly functioning on your device

### 2. Devices not found
- Make sure both devices have the app open
- Check if devices are within Bluetooth range (typically 10 meters)
- Try refreshing the device scan
- Ensure the host device is in discoverable mode

### 3. Connection drops
- Ensure devices stay within Bluetooth range
- Check for interference from other Bluetooth devices
- Restart the Bluetooth service if needed
- Try reconnecting through the app

### 4. Build issues
- Run `flutter clean` and `flutter pub get`
- Ensure all dependencies are properly installed
- Check Flutter and Android SDK versions
- See [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions

### 5. Permission issues
- Grant all Bluetooth and location permissions
- On Android 12+, ensure new Bluetooth permissions are granted
- Check app settings if permissions were previously denied

### 6. Game synchronization issues
- Ensure both devices have stable Bluetooth connection
- Try restarting the game if moves aren't syncing
- Check for app updates

## Development Troubleshooting

### Flutter SDK issues
```bash
flutter doctor
flutter clean
flutter pub get
```

### Platform-specific issues
- **Android**: Ensure Android SDK is properly installed and licenses accepted
- **iOS**: Make sure Xcode is up to date and licenses accepted
- **Linux**: Install required development packages
- **Windows**: Ensure Visual Studio with C++ tools is installed

### Dependency issues
```bash
flutter pub cache repair
flutter pub get
```

## Development Tips

### Testing Bluetooth functionality
- Requires physical devices (emulators don't support Bluetooth)
- Use two physical devices for complete testing

### Debugging
```bash
flutter logs          # View runtime logs
flutter analyze       # Static analysis
flutter test          # Run tests
flutter doctor        # Check setup issues
```

### Performance profiling
```bash
flutter run --profile  # Profile mode
```

## Getting Help

If you continue to experience issues:

1. Check the [GitHub Issues](repository-url/issues) for known problems
2. Search for similar issues in the Flutter community
3. Create a new issue with detailed information about your problem
4. Include device information, Flutter version, and error logs

## Common Error Messages

### "Bluetooth adapter not found"
- Your device doesn't have Bluetooth capability
- Bluetooth drivers may not be installed properly

### "Permission denied"
- Grant all required permissions in device settings
- Restart the app after granting permissions

### "Connection timeout"
- Devices may be too far apart
- Bluetooth interference from other devices
- Try moving closer and reconnecting
