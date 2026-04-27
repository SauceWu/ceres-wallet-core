import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// `TWString1` and `TWString` are both `typedef = ffi.Void` in the generated
/// bindings — same C type, distinct Dart types. Cast via raw address.
Pointer<raw.TWString1> _toTWString1(String value) {
  final utf8 = value.toNativeUtf8();
  // TWStringCreateWithUTF8Bytes returns Pointer<TWString>; the Base*/Bech32
  // FFIs accept Pointer<TWString1>. Re-cast through the address.
  final ptr = lib.TWStringCreateWithUTF8Bytes(utf8.cast<Char>());
  calloc.free(utf8);
  return Pointer<raw.TWString1>.fromAddress(ptr.address);
}

String _fromTWString1(Pointer<raw.TWString1> ptr) {
  if (ptr == nullptr) return '';
  final asTWString = Pointer<raw.TWString>.fromAddress(ptr.address);
  final cStr = lib.TWStringUTF8Bytes(asTWString);
  final result = cStr.cast<Utf8>().toDartString();
  lib.TWStringDelete(asTWString);
  return result;
}

void _deleteTWString1(Pointer<raw.TWString1> ptr) {
  if (ptr != nullptr) {
    lib.TWStringDelete(Pointer<raw.TWString>.fromAddress(ptr.address));
  }
}

/// Static wrappers around the `TWBase32*` codec FFI surface.
///
/// `encode*` returns the empty string on failure; `decode*` returns an empty
/// `Uint8List` on failure.
class TWBase32 {
  TWBase32._();

  /// Encode raw bytes using the default RFC 4648 alphabet.
  static String encode(Uint8List data) {
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBase32Encode(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Encode raw bytes using a custom alphabet.
  static String encodeWithAlphabet(Uint8List data, String alphabet) {
    final twData = toTWData(data);
    final twAlphabet = _toTWString1(alphabet);
    try {
      return _fromTWString1(
        lib.TWBase32EncodeWithAlphabet(twData, twAlphabet),
      );
    } finally {
      deleteTWData(twData);
      _deleteTWString1(twAlphabet);
    }
  }

  /// Decode a Base32 string with the default RFC 4648 alphabet.
  static Uint8List decode(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBase32Decode(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }

  /// Decode a Base32 string with a custom alphabet.
  static Uint8List decodeWithAlphabet(String input, String alphabet) {
    final twString = _toTWString1(input);
    final twAlphabet = _toTWString1(alphabet);
    try {
      return fromTWData(
        lib.TWBase32DecodeWithAlphabet(twString, twAlphabet),
      );
    } finally {
      _deleteTWString1(twString);
      _deleteTWString1(twAlphabet);
    }
  }
}

/// Static wrappers around the `TWBase58*` codec FFI surface.
class TWBase58 {
  TWBase58._();

  /// Encode raw bytes as Base58 with a 4-byte SHA256d checksum (Base58Check).
  static String encode(Uint8List data) {
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBase58Encode(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Encode raw bytes as plain Base58 (no checksum).
  static String encodeNoCheck(Uint8List data) {
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBase58EncodeNoCheck(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Decode a Base58Check string. Empty list on invalid input or bad checksum.
  static Uint8List decode(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBase58Decode(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }

  /// Decode a plain Base58 string (no checksum). Empty list on invalid input.
  static Uint8List decodeNoCheck(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBase58DecodeNoCheck(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }
}

/// Static wrappers around the `TWBase64*` codec FFI surface.
class TWBase64 {
  TWBase64._();

  /// Encode using the standard alphabet (RFC 4648 `+`, `/`).
  static String encode(Uint8List data) {
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBase64Encode(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Encode using the URL-safe alphabet (RFC 4648 `-`, `_`).
  static String encodeUrl(Uint8List data) {
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBase64EncodeUrl(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Decode using the standard alphabet. Empty list on failure.
  static Uint8List decode(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBase64Decode(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }

  /// Decode using the URL-safe alphabet. Empty list on failure.
  static Uint8List decodeUrl(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBase64DecodeUrl(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }
}

/// Static wrappers around the `TWBech32*` codec FFI surface.
///
/// Note: the underlying `TWBech32Decode`/`TWBech32DecodeM` returns only the
/// decoded data part (not the human-readable prefix). Callers that need the
/// HRP should track it out-of-band.
class TWBech32 {
  TWBech32._();

  /// Encode [data] as Bech32 with the given human-readable part [hrp].
  static String encode(String hrp, Uint8List data) {
    final twHrp = _toTWString1(hrp);
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBech32Encode(twHrp, twData));
    } finally {
      _deleteTWString1(twHrp);
      deleteTWData(twData);
    }
  }

  /// Encode [data] as Bech32m (BIP-350) with the given [hrp].
  static String encodeM(String hrp, Uint8List data) {
    final twHrp = _toTWString1(hrp);
    final twData = toTWData(data);
    try {
      return _fromTWString1(lib.TWBech32EncodeM(twHrp, twData));
    } finally {
      _deleteTWString1(twHrp);
      deleteTWData(twData);
    }
  }

  /// Decode a Bech32 string. Returns only the data part (HRP is dropped by
  /// the underlying FFI). Empty list on invalid input.
  static Uint8List decode(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBech32Decode(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }

  /// Decode a Bech32m (BIP-350) string. Returns only the data part.
  static Uint8List decodeM(String input) {
    final twString = _toTWString1(input);
    try {
      return fromTWData(lib.TWBech32DecodeM(twString));
    } finally {
      _deleteTWString1(twString);
    }
  }
}
