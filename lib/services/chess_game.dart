import '../models/chess_piece.dart';
import '../models/position.dart';
import '../models/move.dart';

class ChessBoard {
  static const int boardSize = 8;
  List<List<ChessPiece?>> _board = List.generate(
    boardSize,
    (row) => List.generate(boardSize, (col) => null),
  );

  PieceColor _currentPlayer = PieceColor.white;
  List<Move> _moveHistory = [];
  Position? _enPassantTarget;
  bool _whiteKingMoved = false;
  bool _blackKingMoved = false;
  bool _whiteRookKingsideMoved = false;
  bool _whiteRookQueensideMoved = false;
  bool _blackRookKingsideMoved = false;
  bool _blackRookQueensideMoved = false;

  ChessBoard() {
    _initializeBoard();
  }

  // Getters
  List<List<ChessPiece?>> get board => _board;
  PieceColor get currentPlayer => _currentPlayer;
  List<Move> get moveHistory => _moveHistory;
  bool get isGameOver => isCheckmate(_currentPlayer) || isStalemate(_currentPlayer);

  void _initializeBoard() {
    // Initialize pawns
    for (int col = 0; col < boardSize; col++) {
      _board[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
      _board[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
    }

    // Initialize other pieces
    const pieceOrder = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int col = 0; col < boardSize; col++) {
      _board[0][col] = ChessPiece(type: pieceOrder[col], color: PieceColor.black);
      _board[7][col] = ChessPiece(type: pieceOrder[col], color: PieceColor.white);
    }
  }

  ChessPiece? getPieceAt(Position position) {
    if (!position.isValid) return null;
    return _board[position.row][position.col];
  }

  void setPieceAt(Position position, ChessPiece? piece) {
    if (position.isValid) {
      _board[position.row][position.col] = piece;
    }
  }

  bool isValidMove(Move move) {
    ChessPiece? piece = getPieceAt(move.from);
    if (piece == null || piece.color != _currentPlayer) return false;

    List<Position> validMoves = getValidMovesForPiece(move.from);
    return validMoves.contains(move.to);
  }

  List<Position> getValidMovesForPiece(Position position) {
    ChessPiece? piece = getPieceAt(position);
    if (piece == null) return [];

    List<Position> moves = [];

    switch (piece.type) {
      case PieceType.pawn:
        moves = _getPawnMoves(position, piece);
        break;
      case PieceType.rook:
        moves = _getRookMoves(position, piece);
        break;
      case PieceType.knight:
        moves = _getKnightMoves(position, piece);
        break;
      case PieceType.bishop:
        moves = _getBishopMoves(position, piece);
        break;
      case PieceType.queen:
        moves = _getQueenMoves(position, piece);
        break;
      case PieceType.king:
        moves = _getKingMoves(position, piece);
        break;
    }

    // Filter out moves that would put own king in check
    return moves.where((to) {
      return !wouldBeInCheckAfterMove(Move(from: position, to: to));
    }).toList();
  }

  List<Position> _getPawnMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    int direction = piece.color == PieceColor.white ? -1 : 1;
    int startRow = piece.color == PieceColor.white ? 6 : 1;

    // Forward move
    Position oneForward = Position(position.row + direction, position.col);
    if (oneForward.isValid && getPieceAt(oneForward) == null) {
      moves.add(oneForward);

      // Two squares forward from starting position
      if (position.row == startRow) {
        Position twoForward = Position(position.row + 2 * direction, position.col);
        if (twoForward.isValid && getPieceAt(twoForward) == null) {
          moves.add(twoForward);
        }
      }
    }

    // Diagonal captures
    for (int deltaCol in [-1, 1]) {
      Position capturePos = Position(position.row + direction, position.col + deltaCol);
      if (capturePos.isValid) {
        ChessPiece? targetPiece = getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != piece.color) {
          moves.add(capturePos);
        }
        // En passant
        else if (_enPassantTarget == capturePos) {
          moves.add(capturePos);
        }
      }
    }

    return moves;
  }

  List<Position> _getRookMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    
    // Horizontal and vertical directions
    List<List<int>> directions = [
      [0, 1], [0, -1], [1, 0], [-1, 0]
    ];

    for (List<int> direction in directions) {
      for (int i = 1; i < boardSize; i++) {
        Position newPos = Position(
          position.row + direction[0] * i,
          position.col + direction[1] * i,
        );

        if (!newPos.isValid) break;

        ChessPiece? targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(newPos);
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(newPos);
          }
          break;
        }
      }
    }

    return moves;
  }

  List<Position> _getKnightMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    
    List<List<int>> knightMoves = [
      [2, 1], [2, -1], [-2, 1], [-2, -1],
      [1, 2], [1, -2], [-1, 2], [-1, -2]
    ];

    for (List<int> move in knightMoves) {
      Position newPos = Position(position.row + move[0], position.col + move[1]);
      if (newPos.isValid) {
        ChessPiece? targetPiece = getPieceAt(newPos);
        if (targetPiece == null || targetPiece.color != piece.color) {
          moves.add(newPos);
        }
      }
    }

    return moves;
  }

  List<Position> _getBishopMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    
    // Diagonal directions
    List<List<int>> directions = [
      [1, 1], [1, -1], [-1, 1], [-1, -1]
    ];

    for (List<int> direction in directions) {
      for (int i = 1; i < boardSize; i++) {
        Position newPos = Position(
          position.row + direction[0] * i,
          position.col + direction[1] * i,
        );

        if (!newPos.isValid) break;

        ChessPiece? targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(newPos);
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(newPos);
          }
          break;
        }
      }
    }

    return moves;
  }

  List<Position> _getQueenMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    moves.addAll(_getRookMoves(position, piece));
    moves.addAll(_getBishopMoves(position, piece));
    return moves;
  }

  List<Position> _getKingMoves(Position position, ChessPiece piece) {
    List<Position> moves = [];
    
    // Normal king moves
    for (int deltaRow = -1; deltaRow <= 1; deltaRow++) {
      for (int deltaCol = -1; deltaCol <= 1; deltaCol++) {
        if (deltaRow == 0 && deltaCol == 0) continue;
        
        Position newPos = Position(position.row + deltaRow, position.col + deltaCol);
        if (newPos.isValid) {
          ChessPiece? targetPiece = getPieceAt(newPos);
          if (targetPiece == null || targetPiece.color != piece.color) {
            moves.add(newPos);
          }
        }
      }
    }

    // Castling
    if (!isInCheck(_currentPlayer)) {
      moves.addAll(_getCastlingMoves(position, piece));
    }

    return moves;
  }

  List<Position> _getCastlingMoves(Position kingPosition, ChessPiece king) {
    List<Position> moves = [];
    
    if (king.hasMoved) return moves;

    int row = king.color == PieceColor.white ? 7 : 0;
    
    // Kingside castling
    if (!_hasRookMoved(king.color, true)) {
      bool canCastle = true;
      for (int col = 5; col <= 6; col++) {
        if (getPieceAt(Position(row, col)) != null) {
          canCastle = false;
          break;
        }
      }
      if (canCastle) {
        moves.add(Position(row, 6));
      }
    }

    // Queenside castling
    if (!_hasRookMoved(king.color, false)) {
      bool canCastle = true;
      for (int col = 1; col <= 3; col++) {
        if (getPieceAt(Position(row, col)) != null) {
          canCastle = false;
          break;
        }
      }
      if (canCastle) {
        moves.add(Position(row, 2));
      }
    }

    return moves;
  }

  bool _hasRookMoved(PieceColor color, bool kingside) {
    if (color == PieceColor.white) {
      return kingside ? _whiteRookKingsideMoved : _whiteRookQueensideMoved;
    } else {
      return kingside ? _blackRookKingsideMoved : _blackRookQueensideMoved;
    }
  }

  bool makeMove(Move move) {
    if (!isValidMove(move)) return false;

    ChessPiece? piece = getPieceAt(move.from);
    if (piece == null) return false;

    // Handle special moves
    _handleSpecialMoves(move, piece);

    // Make the move
    setPieceAt(move.to, piece.copyWith(hasMoved: true));
    setPieceAt(move.from, null);

    // Update move history
    _moveHistory.add(move);

    // Switch players
    _currentPlayer = _currentPlayer == PieceColor.white 
        ? PieceColor.black 
        : PieceColor.white;

    return true;
  }

  void _handleSpecialMoves(Move move, ChessPiece piece) {
    // Update castling rights
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _whiteKingMoved = true;
      } else {
        _blackKingMoved = true;
      }

      // Handle castling
      if ((move.to.col - move.from.col).abs() == 2) {
        int row = move.from.row;
        if (move.to.col == 6) { // Kingside
          ChessPiece? rook = getPieceAt(Position(row, 7));
          setPieceAt(Position(row, 5), rook);
          setPieceAt(Position(row, 7), null);
        } else if (move.to.col == 2) { // Queenside
          ChessPiece? rook = getPieceAt(Position(row, 0));
          setPieceAt(Position(row, 3), rook);
          setPieceAt(Position(row, 0), null);
        }
      }
    }

    // Update rook castling rights
    if (piece.type == PieceType.rook) {
      if (piece.color == PieceColor.white) {
        if (move.from.col == 0) _whiteRookQueensideMoved = true;
        if (move.from.col == 7) _whiteRookKingsideMoved = true;
      } else {
        if (move.from.col == 0) _blackRookQueensideMoved = true;
        if (move.from.col == 7) _blackRookKingsideMoved = true;
      }
    }

    // Handle en passant
    _enPassantTarget = null;
    if (piece.type == PieceType.pawn) {
      // Set en passant target
      if ((move.to.row - move.from.row).abs() == 2) {
        _enPassantTarget = Position(
          (move.from.row + move.to.row) ~/ 2,
          move.from.col,
        );
      }
      // Capture en passant
      else if (move.to.col != move.from.col && getPieceAt(move.to) == null) {
        setPieceAt(Position(move.from.row, move.to.col), null);
      }
    }
  }

  bool isInCheck(PieceColor color) {
    Position? kingPosition = _findKing(color);
    if (kingPosition == null) return false;

    return _isPositionAttacked(kingPosition, color == PieceColor.white 
        ? PieceColor.black 
        : PieceColor.white);
  }

  bool wouldBeInCheckAfterMove(Move move) {
    // Make temporary move
    ChessPiece? originalPiece = getPieceAt(move.from);
    ChessPiece? capturedPiece = getPieceAt(move.to);
    
    setPieceAt(move.to, originalPiece);
    setPieceAt(move.from, null);

    bool inCheck = isInCheck(_currentPlayer);

    // Restore board state
    setPieceAt(move.from, originalPiece);
    setPieceAt(move.to, capturedPiece);

    return inCheck;
  }

  Position? _findKing(PieceColor color) {
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        ChessPiece? piece = _board[row][col];
        if (piece != null && 
            piece.type == PieceType.king && 
            piece.color == color) {
          return Position(row, col);
        }
      }
    }
    return null;
  }

  bool _isPositionAttacked(Position position, PieceColor attackerColor) {
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        ChessPiece? piece = _board[row][col];
        if (piece != null && piece.color == attackerColor) {
          List<Position> moves = _getRawMovesForPiece(Position(row, col), piece);
          if (moves.contains(position)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<Position> _getRawMovesForPiece(Position position, ChessPiece piece) {
    // Similar to getValidMovesForPiece but without check filtering
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnAttacks(position, piece);
      case PieceType.rook:
        return _getRookMoves(position, piece);
      case PieceType.knight:
        return _getKnightMoves(position, piece);
      case PieceType.bishop:
        return _getBishopMoves(position, piece);
      case PieceType.queen:
        return _getQueenMoves(position, piece);
      case PieceType.king:
        return _getKingMoves(position, piece);
    }
  }

  List<Position> _getPawnAttacks(Position position, ChessPiece piece) {
    List<Position> attacks = [];
    int direction = piece.color == PieceColor.white ? -1 : 1;

    for (int deltaCol in [-1, 1]) {
      Position attackPos = Position(position.row + direction, position.col + deltaCol);
      if (attackPos.isValid) {
        attacks.add(attackPos);
      }
    }

    return attacks;
  }

  bool isCheckmate(PieceColor color) {
    if (!isInCheck(color)) return false;
    return _hasNoLegalMoves(color);
  }

  bool isStalemate(PieceColor color) {
    if (isInCheck(color)) return false;
    return _hasNoLegalMoves(color);
  }

  bool _hasNoLegalMoves(PieceColor color) {
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        ChessPiece? piece = _board[row][col];
        if (piece != null && piece.color == color) {
          List<Position> moves = getValidMovesForPiece(Position(row, col));
          if (moves.isNotEmpty) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'board': _board.map((row) => 
          row.map((piece) => piece?.toJson()).toList()
      ).toList(),
      'currentPlayer': _currentPlayer.index,
      'moveHistory': _moveHistory.map((move) => move.toJson()).toList(),
      'enPassantTarget': _enPassantTarget?.toJson(),
      'whiteKingMoved': _whiteKingMoved,
      'blackKingMoved': _blackKingMoved,
      'whiteRookKingsideMoved': _whiteRookKingsideMoved,
      'whiteRookQueensideMoved': _whiteRookQueensideMoved,
      'blackRookKingsideMoved': _blackRookKingsideMoved,
      'blackRookQueensideMoved': _blackRookQueensideMoved,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    // Restore board state
    List<List<dynamic>> boardData = json['board'];
    _board = boardData.map((row) => 
        row.map((pieceData) => pieceData != null 
            ? ChessPiece.fromJson(pieceData) 
            : null).toList().cast<ChessPiece?>()
    ).toList();

    _currentPlayer = PieceColor.values[json['currentPlayer']];
    
    _moveHistory = (json['moveHistory'] as List)
        .map((moveData) => Move.fromJson(moveData))
        .toList();
    
    _enPassantTarget = json['enPassantTarget'] != null 
        ? Position.fromJson(json['enPassantTarget']) 
        : null;
    
    _whiteKingMoved = json['whiteKingMoved'];
    _blackKingMoved = json['blackKingMoved'];
    _whiteRookKingsideMoved = json['whiteRookKingsideMoved'];
    _whiteRookQueensideMoved = json['whiteRookQueensideMoved'];
    _blackRookKingsideMoved = json['blackRookKingsideMoved'];
    _blackRookQueensideMoved = json['blackRookQueensideMoved'];
  }
}
