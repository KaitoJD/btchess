import '../enums/game_end_reason.dart';
import '../enums/winner.dart';
import '../models/game_result.dart';
import '../models/move.dart';

class PgnHeaders {
  final String? event;
  final String? site;
  final String? date;
  final String? round;
  final String? white;
  final String? black;
  final String? result;
  final Map<String, String> additional;

  const PgnHeaders({
    this.event,
    this.site,
    this.date,
    this.round,
    this.white,
    this.black,
    this.result,
    this.additional = const {},
  });

  factory PgnHeaders.newGame({
    String? whiteName,
    String? blackName,
    String? event,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return PgnHeaders(
      event: event ?? 'BTChess Game',
      site: 'BTChess App',
      date: dateStr,
      round: '?',
      white: whiteName ?? 'White',
      black: blackName ?? 'Black',
      result: '*',
    );
  }

  PgnHeaders withResult(String result) {
    return PgnHeaders(
      event: event,
      site: site,
      date: date,
      round: round,
      white: white,
      black: black,
      result: result,
      additional: additional,
    );
  }

  String format() {
    final buffer = StringBuffer();

    void addTag(String name, String? value) {
      if (value != null && value.isNotEmpty) {
        buffer.writeln('[$name "$value"]');
      }
    }

    addTag('Event', event ?? '?');
    addTag('Site', site ?? '?');
    addTag('Date', date ?? '????.??.??');
    addTag('Round', round ?? '?');
    addTag('White', white ?? '?');
    addTag('Black', black ?? '?');
    addTag('Result', result ?? '*');

    for (final entry in additional.entries) {
      addTag(entry.key, entry.value);
    }

    return buffer.toString();
  }
}

class ParsedPgn {
  final PgnHeaders headers;
  final List<String> moves;
  final String? result;
  final List<String> comments;

  const ParsedPgn({
    required this.headers,
    required this.moves,
    this.result,
    this.comments = const [],
  });
}

class PgnService {
  const PgnService();

  /* Generates a PGN string from a list of moves
   *
   * moves - List of moves with SAN notation
   * headers - Optional PGN headers. If null, default headers are used
   * result - The game result ("1-0", "0-1", "1/2-1/2", "*")
   */
  String generate({
    required List<Move> moves,
    PgnHeaders? headers,
    GameResult? result,
  }) {
    final buffer = StringBuffer();
    final pgnHeaders = headers ?? PgnHeaders.newGame();
    final resultStr = result?.pgnResult ?? '*';

    buffer.write(pgnHeaders.withResult(resultStr).format());
    buffer.writeln();
    buffer.write(_formatMovetext(moves, resultStr));

    return buffer.toString();
  }

  // Generates a simple move list string (without headers)
  // Example: "1. e4 e5 2. Nf3 Nc6"
  String generateMovetext(List<Move> moves) {
    return _formatMovetext(moves, null);
  }

  String generateMovetextFromSan(List<String> sanMoves) {
    final buffer = StringBuffer();

    for (int i = 0; i < sanMoves.length; i++) {
      final moveNumber = (i ~/ 2) + 1;

      if (i % 2 == 0) {
        if (i > 0) buffer.write(' ');
        buffer.write('$moveNumber. ${sanMoves[i]}');
      } else {
        buffer.write(' ${sanMoves[i]}');
      }
    }

    return buffer.toString();
  }

  ParsedPgn parse(String pgn) {
    final lines = pgn.split('\n');
    final headerLines = <String>[];
    final movetextLines = <String>[];

    bool inMovetext = false;

    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.isEmpty) {
        if (headerLines.isNotEmpty) {
          inMovetext = true;
        }
        continue;
      }

      if (!inMovetext && trimmed.startsWith('[')) {
        headerLines.add(trimmed);
      } else {
        inMovetext = true;
        movetextLines.add(trimmed);
      }
    }

    final headers = _parseHeaders(headerLines);
    final movetext = movetextLines.join(' ');
    final moveAndResult = _parseMovetext(movetext);

    return ParsedPgn(
      headers: headers,
      moves: moveAndResult.moves,
      result: moveAndResult.result ?? headers.result,
    );
  }

  List<String> extractMoves(String pgn) {
    return parse(pgn).moves;
  }

  String getResultString(GameResult? result) {
    if (result == null) return '*';

    return result.pgnResult;
  }

  String getResultStringFromWinner(Winner? winner) {
    if (winner == null) return '*';
    switch (winner) {
      case Winner.white:
        return '1-0';
      case Winner.black:
        return '0-1';
      case Winner.draw:
        return '1/2-1/2';
    }
  }

  Winner? parseResult(String result) {
    switch (result.trim()) {
      case '1-0':
        return Winner.white;
      case '0-1':
        return Winner.black;
      case '1/2-1/2':
        return Winner.draw;
      default:
        return null;
    }
  }

  String getGameEndComment(GameEndReason reason) {
    switch (reason) {
      case GameEndReason.checkmate:
        return '';  // Checkmate is obvious from the notation
      case GameEndReason.stalemate:
        return '{Stalemate}';
      case GameEndReason.resign:
        return '{Resignation}';
      case GameEndReason.drawAgreement:
        return '{Draw by agreement}';
      case GameEndReason.fiftyMoveRule:
        return '{Draw by fifty-move rule}';
      case GameEndReason.threefoldRepetition:
        return '{Draw by threefold repetition}';
      case GameEndReason.insufficientMaterial:
        return '{Draw by insufficient material}';
      case GameEndReason.timeout:
        return '{Time forfeit}';
      case GameEndReason.disconnect:
        return '{Disconnection}';
    }
  }

  bool isValid(String pgn) {
    try {
      final parsed = parse(pgn);

      return parsed.moves.isNotEmpty || parsed.headers.result == '*';
    } catch (_) {
      return false;
    }
  }

  String _formatMovetext(List<Move> moves, String? result) {
    final buffer = StringBuffer();
    final lineLength = 80;
    var currentLineLength = 0;

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      final san = move.san ?? move.uci;
      final moveNumber = (i ~/ 2) + 1;

      String moveStr;

      if (i % 2 == 0) {
        moveStr = '$moveNumber. $san';
      } else {
        moveStr = san;
      }

      if (currentLineLength > 0) {
        if (currentLineLength + moveStr.length + 1 > lineLength) {
          buffer.writeln();
          currentLineLength = 0;
        } else {
          buffer.write(' ');
          currentLineLength += 1;
        }
      }

      buffer.write(moveStr);
      currentLineLength += moveStr.length;
    }

    if (result != null) {
      if (currentLineLength > 0) {
        if (currentLineLength + result.length + 1 > lineLength) {
          buffer.writeln();
        } else {
          buffer.write(' ');
        }
      }
      buffer.write(result);
    }

    return buffer.toString();
  }

  PgnHeaders _parseHeaders(List<String> headerLines) {
    String? event, site, date, round, white, black, result;
    final additional = <String, String>{};

    for (final line in headerLines) {
      final match = RegExp(r'\[(\w+)\s+"(.*)"\]').firstMatch(line);

      if (match != null) {
        final tag = match.group(1)!;
        final value = match.group(2)!;

        switch (tag) {
          case 'Event':
            event = value;
            break;
          case 'Site':
            site = value;
            break;
          case 'Date':
            date = value;
            break;
          case 'Round':
            round = value;
            break;
          case 'White':
            white = value;
            break;
          case 'Black':
            black = value;
            break;
          case 'Result':
            result = value;
            break;
          default:
            additional[tag] = value;
        }
      }
    }

    return PgnHeaders(
      event: event,
      site: site,
      date: date,
      round: round,
      white: white,
      black: black,
      result: result,
      additional: additional,
    );
  }

  ({List<String> moves, String? result}) _parseMovetext(String movetext) {
    final moves = <String>[];
    String? result;

    var cleaned = movetext.replaceAll(RegExp(r'\{[^}]*\}'), ' ');
    cleaned = _removeVariations(cleaned);
    cleaned = cleaned.replaceAll(RegExp(r'\$\d+'), ' ');

    final tokens = cleaned.split(RegExp(r'\s+'));

    for (final token in tokens) {
      if (token.isEmpty) continue;

      if (token == '1-0' || token == '0-1' || token == '1/2-1/2' || token == '*') {
        result = token;
        continue;
      }

      if (RegExp(r'^\d+\.+$').hasMatch(token)) {
        continue;
      }

      final moveMatch = RegExp(r'^\d+\.+(.+)$').firstMatch(token);

      if (moveMatch != null) {
        moves.add(moveMatch.group(1)!);
        continue;
      }

      if (_isValidSan(token)) {
        moves.add(token);
      }
    }

    return (moves: moves, result: result);
  }

  String _removeVariations(String movetext) {
    var result = movetext;
    var prevLength = 0;

    while (result.length != prevLength) {
      prevLength = result.length;
      result = result.replaceAll(RegExp(r'\([^()]*\)'), ' ');
    }

    return result;
  }

  bool _isValidSan(String san) {
    // Basic SAN validation
    // Matches: e4, Nf3, Bxc6, O-O, O-O-O, Qxh7+, Rxa8#, e8=Q, etc
    final sanPattern = RegExp(
      r'^([KQRBN])?([a-h])?([1-8])?(x)?([a-h][1-8])(=[QRBN])?([+#])?$|^O-O(-O)?[+#]?$',
      caseSensitive: true,
    );

    return sanPattern.hasMatch(san);
  }
}