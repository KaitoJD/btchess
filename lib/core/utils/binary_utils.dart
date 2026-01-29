import 'dart:typed_data';

// Utility functions for binary data manipulation

abstract class BinaryUtils {
  // Converts a Uint8List to a hex string
  static String toHexString(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  // Converts a hex string to Uint8List
  static Uint8List fromHexString(String hex) {
    final cleaned = hex.replaceAll(' ', '');
    if (cleaned.length % 2 != 0) {
      throw ArgumentError('Hex string must have even length');
    }

    final bytes = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return bytes;
  }

  // Read a uint16 from bytes at the given offset (big-endian)
  static int readUint16(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) {
      throw RangeError('Not enough bytes to read uint16');
    }
    return (bytes[offset] << 8 | bytes[offset + 1]);
  }

  // Writes a uint16 to bytes at the given offset (big-endian)
  static void writeUint16(Uint8List bytes, int offset, int value) {
    if (offset + 2 > bytes.length) {
      throw RangeError('Not enough space to write uint16');
    }
    bytes[offset] = (value >> 8) & 0xFF;
    bytes[offset + 1] = value & 0xFF;
  }

  // Reads a uint32 from bytes at the given offset (big-endian)
  static int readUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) {
      throw RangeError('Not enough bytes to read uint32');
    }
    return  (bytes[offset] << 24) |
            (bytes[offset + 1] << 16) |
            (bytes[offset + 2] << 8) |
            bytes[offset + 3];
  }

  // Writes a uint32 to bytes at the given offset (big-endian)
  static void writeUint32(Uint8List bytes, int offset, int value) {
    if (offset + 4 > bytes.length) {
      throw RangeError('Not enough space to write uint32');
    }
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }
}

// A builder for constructing byte arrays
class ByteBufferBuilder {
  final List<int> _bytes = [];

  // Adds a single byte
  ByteBufferBuilder addByte(int byte) {
    _bytes.add(byte & 0xFF);
    return this;
  }

  // Add a uint16 (big-endian)
  ByteBufferBuilder addUint16(int value) {
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add(value & 0xFF);
    return this;
  }

  // Adds a uint32 (big-endian)
  ByteBufferBuilder addUint32(int value) {
    _bytes.add((value >> 24) & 0xFF);
    _bytes.add((value >> 16) & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add(value & 0xFF);
    return this;
  }

  // Adds raw bytes
  ByteBufferBuilder addBytes(List<int> bytes) {
    _bytes.addAll(bytes);
    return this;
  }

  // Adds a UTF-8 encoded string
  ByteBufferBuilder addString(String str) {
    _bytes.addAll(str.codeUnits);
    return this;
  }

  int get length => _bytes.length;

  // Builds the final Uint8List
  Uint8List build() => Uint8List.fromList(_bytes);
}

// A reader for parsing byte array
class ByteBufferReader {
  ByteBufferReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  // Returns the current read offset
  int get offset => _offset;

  // Returns the number of remaining bytes
  int get remaining => _bytes.length - _offset;
  
  // Returns true if there are more bytes to read
  bool get hasMore => _offset < _bytes.length;

  // Reads a single byte
  int readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError('No more bytes to read');
    }
    return _bytes[_offset++];
  }

  // Reads a uint16 (big-endian)
  int readUint16() {
    final value = BinaryUtils.readUint16(_bytes, _offset);
    _offset += 2;
    return value;
  }

  // Reads a uint32 (big-endian)
  int readUint32() {
    final value = BinaryUtils.readUint32(_bytes, _offset);
    _offset += 4;
    return value;
  }

  // Reads the specified number of bytes
  Uint8List readBytes(int count) {
    if (_offset + count > _bytes.length) {
      throw RangeError('Not enough bytes to read');
    }
    final result = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return result;
  }

  // Reads all remaining bytes
  Uint8List readRemaining() {
    final result = _bytes.sublist(_offset);
    _offset = _bytes.length;
    return result;
  }

  // Reads remaining bytes as a UTF-8 string
  String readRemainingAsString() {
    return String.fromCharCodes(readRemaining());
  }
}