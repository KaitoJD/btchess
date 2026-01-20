enum GameMode {
  hotseat,
  bleHost,
  bleClient;

  bool get isBle => this == bleHost || this == bleClient;
  bool get isHotseat => this == hotseat;
  bool get isHost => this == hotseat || this == bleHost;
  bool get allowsUndo => this == hotseat;

  String get displayName {
    switch (this) {
      case GameMode.hotseat:
      return 'Hotseat';
      case GameMode.bleHost:
      return 'Bluetooth (Host)';
      case GameMode.bleClient:
      return 'Bluetooth (Client)';
    }
  }
}
