import '../models/piece.dart';
import '../models/square.dart';

const String standardStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class FenComponents {
  final String piecePlacement;
  final String activeColor;
  final String castling;
  final String enPassant;
  final int halfMoveClock;
  final int fullMoveNumber;

  const FenComponents({
    required this.piecePlacement,
    required this.activeColor,
    required this.castling,
    required this.enPassant,
    required this.halfMoveClock,
    required this.fullMoveNumber,
  });

  String toFen() {
    return '$piecePlacement $activeColor $castling $enPassant $halfMoveClock $fullMoveNumber';
  }

  bool get isWhiteTurn => activeColor == 'w';
  bool get isBlackTurn => activeColor == 'b';
  bool get whiteCanCastleKingside => castling.contains('K');
  bool get whiteCanCastleQueenside => castling.contains('Q');
  bool get blackCanCastleKingside => castling.contains('k');
  bool get blackCanCastleQueenside => castling.contains('q');
  bool get hasEnPassant => enPassant != '-';

  Square? get enPassantSquare {
    if (!hasEnPassant) return null;

    return Square.tryFromAlgebraic(enPassant);
  }

  FenComponents copyWith({
    String? piecePlacement,
    String? activeColor,
    String? castling,
    String? enPassant,
    int? halfMoveClock,
    int? fullMoveNumber,
  }) {
    return FenComponents(
      piecePlacement: piecePlacement ?? this.piecePlacement,
      activeColor: activeColor ?? this.activeColor,
      castling: castling ?? this.castling,
      enPassant: enPassant ?? this.enPassant,
      halfMoveClock: halfMoveClock ?? this.halfMoveClock,
      fullMoveNumber: fullMoveNumber ?? this.fullMoveNumber,
    );
  }
}

class FenValidationResult {
  final bool isValid;
  final String? error;

  const FenValidationResult._(this.isValid, this.error);

  factory FenValidationResult.valid() => const FenValidationResult._(true, null);
  factory FenValidationResult.invalid(String error) => FenValidationResult._(false, error);
}

class FenService {
  FenComponents parse(String fen) {
    final validation = validate(fen);
    if (!validation.isValid) {
      throw FormatException('Invalid FEN: ${validation.error}');
    }

    final parts = fen.trim().split(RegExp(r'\s+'));

    return FenComponents(
      piecePlacement: parts[0],
      activeColor: parts[1],
      castling: parts[2],
      enPassant: parts[3],
      halfMoveClock: int.parse(parts[4]),
      fullMoveNumber: int.parse(parts[5]),
    );
  }

  FenComponents? tryParse(String fen) {
    try {
      return parse(fen);
    } catch (_) {
      return null;
    }
  }

  FenValidationResult validate(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));

    if (parts.length != 6) {
      return FenValidationResult.invalid('FEN must have 6 space-separated parts, got ${parts.length}');
    }

    final placementValidation = _validatePiecePlacement(parts[0]);
    if (!placementValidation.isValid) {
      return placementValidation;
    }

    if (parts[1] != 'w' && parts[1] != 'b') {
      return FenValidationResult.invalid('Active color must be "w" or "b", got "${parts[1]}"');
    }

    if (!_isValidCastling(parts[2])) {
      return FenValidationResult.invalid('Invalid castling rights: "${parts[2]}"');
    }

    if (!_isValidEnPassant(parts[3])) {
      return FenValidationResult.invalid('Invalid en passant square: "${parts[3]}"');
    }

    final halfMove = int.tryParse(parts[4]);
    if (halfMove == null || halfMove < 0) {
      return FenValidationResult.invalid('Half-move clock must be a non-negative integer, got "${parts[4]}');
    }

    final fullMove = int.tryParse(parts[5]);
    if (fullMove == null || fullMove < 1) {
      return FenValidationResult.invalid('Full move number must be a positive integer, got "${parts[5]}"');
    }

    return FenValidationResult.valid();
  }

  bool isValid(String fen) => validate(fen).isValid;

  List<List<Piece?>> getBoard(String fen) {
    final components = tryParse(fen);
    if (components == null) {
      return List.generate(8, (_) => List.filled(8, null));
    }

    final board = <List<Piece?>>[];
    final ranks = components.piecePlacement.split('/');

    for (final rank in ranks) {
      final row = <Piece?>[];

      for (final char in rank.split('')) {
        final digit = int.tryParse(char);

        if (digit != null) {
          row.addAll(List.filled(digit, null));
        } else {
          row.add(Piece.fromFenChar(char));
        }
      }

      board.add(row);
    }

    return board;
  }

  Map<Square, Piece> getPieces(String fen) {
    final board = getBoard(fen);
    final pieces = <Square, Piece>{};

    for (int rankIndex = 0; rankIndex < 8; rankIndex++) {
      for (int fileIndex = 0; fileIndex < 8; fileIndex++) {
        final piece = board[rankIndex][fileIndex];

        if (piece != null) {
          final rank = 7 - rankIndex;
          pieces[Square(fileIndex, rank)] = piece;
        }
      }
    }

    return pieces;
  }

  Piece? getPieceAt(String fen, Square square) {
    final pieces = getPieces(fen);
    return pieces[square];
  }

  PieceColor getTurn(String fen) {
    final components = tryParse(fen);
    if (components == null) return PieceColor.white;

    return components.isWhiteTurn ? PieceColor.white : PieceColor.black;
  }

  int getHalfMoveClock(String fen) {
    final components = tryParse(fen);

    return components?.halfMoveClock ?? 0;
  }

  int getFullMoveNumber(String fen) {
    final components = tryParse(fen);
    
    return components?.fullMoveNumber ?? 1;
  }

  String createFen({
    required Map<Square, Piece> pieces,
    required PieceColor turn,
    String castling = 'KQkq',
    String enPassant = '-',
    int haftMoveClock = 0,
    int fullMoveNumber = 1,
  }) {
    final placement = _createPiecePlacement(pieces);
    final activeColor = turn == PieceColor.white ? 'w' : 'b';

    return '$placement $activeColor $castling $enPassant $haftMoveClock $fullMoveNumber';
  }

  FenValidationResult _validatePiecePlacement(String placement) {
    final ranks = placement.split('/');

    if (ranks.length != 8) {
      return FenValidationResult.invalid('Piece placement must have 8 ranks, got ${ranks.length}');
    }

    for (int i = 0; i < ranks.length; i++) {
      final rank = ranks[i];
      int squareCount = 0;

      for (final char in rank.split('')) {
        final digit = int.tryParse(char);
        
        if (digit != null) {
          if (digit < 1 || digit > 8) {
            return FenValidationResult.invalid('Invalid digit in rank ${8 - i}: $digit');
          }
          squareCount += digit;
        } else if (_isValidPieceChar(char)) {
          squareCount += 1;
        } else {
          return FenValidationResult.invalid('Invalid character in rank ${8 - i}: "$char"');
        }
      }

      if (squareCount != 8) {
        return FenValidationResult.invalid('Rank ${8 - i} has $squareCount squares, expected 8');
      }
    }

    return FenValidationResult.valid();
  }

  bool _isValidPieceChar(String char) {
    return 'KQRBNPkqrbnp'.contains(char);
  }

  bool _isValidCastling(String castling) {
    if (castling == '-') return true;
    if (castling.isEmpty) return false;

    final validChars = {'K', 'Q', 'k', 'q'};
    final seen = <String>{};

    for (final char in castling.split('')) {
      if (!validChars.contains(char)) return false;
      if (seen.contains(char)) return false;
      seen.add(char);
    }

    return true;
  }

  bool _isValidEnPassant(String enPassant) {
    if (enPassant == '-') return true;
    if (enPassant.length != 2) return false;

    final file = enPassant[0];
    final rank = enPassant[1];

    if (!RegExp(r'[a-h]').hasMatch(file)) return false;
    if (rank != '3' && rank != '6') return false;

    return true;
  }

  String _createPiecePlacement(Map<Square, Piece> pieces) {
    final ranks = <String>[];

    for (int rank = 7; rank >= 0; rank--) {
      final rankStr = StringBuffer();
      int emptyCount = 0;

      for (int file = 0; file < 8; file++) {
        final square = Square(file, rank);
        final piece = pieces[square];

        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rankStr.write(emptyCount);
            emptyCount = 0;
          }
          rankStr.write(piece.fenChar);
        }
      }

      if (emptyCount > 0) {
        rankStr.write(emptyCount);
      }

      ranks.add(rankStr.toString());
    }

    return ranks.join('/');
  }
}