import 'package:equatable/equatable.dart';
import 'piece.dart';

class Player extends Equatable {

  const Player({
    required this.id,
    required this.name,
    required this.color,
    this.isLocal = true,
    this.isHost = false,
  });

  factory Player.local({
    required String name,
    required PieceColor color,
    bool isHost = false,
  }) {
    return Player(
      id: 'local_${color.name}',
      name: name,
      color: color,
      isHost: isHost,
    );
  }

  factory Player.remote({
    required String id,
    required String name,
    required PieceColor color,
  }) {
    return Player(
      id: id,
      name: name,
      color: color,
      isLocal: false,
    );
  }

  factory Player.white([String name = 'White']) {
    return Player(
      id: 'white',
      name: name,
      color: PieceColor.white,
    );
  }

  factory Player.black([String name = 'Black']) {
    return Player(
      id: 'black',
      name: name,
      color: PieceColor.black,
    );
  }
  final String id;
  final String name;
  final PieceColor color;
  final bool isLocal;
  final bool isHost;

  bool get isWhite => color == PieceColor.white;
  bool get isBlack => color == PieceColor.black;

  Player copyWith({
    String? id,
    String? name,
    PieceColor? color,
    bool? isLocal,
    bool? isHost,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isLocal: isLocal ?? this.isLocal,
      isHost: isHost ?? this.isHost,
    );
  }

  @override
  List<Object?> get props => [id, name, color, isLocal, isHost];

  @override
  String toString() => '$name (${color.name})';
}