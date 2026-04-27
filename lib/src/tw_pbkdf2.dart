import 'dart:typed_data';
import 'native.dart';
import 'tw_data_helper.dart';

/// Static wrappers around the `TWPBKDF2*` key-derivation FFI surface.
///
/// [iterations] is the PBKDF2 round count and [dkLen] is the requested
/// derived-key length in bytes.
class TWPBKDF2 {
  TWPBKDF2._();

  /// PBKDF2 with HMAC-SHA256 as the underlying PRF.
  static Uint8List hmacSha256(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) {
    final twPassword = toTWData(password);
    final twSalt = toTWData(salt);
    try {
      return fromTWData(
        lib.TWPBKDF2HmacSha256(twPassword, twSalt, iterations, dkLen),
      );
    } finally {
      deleteTWData(twPassword);
      deleteTWData(twSalt);
    }
  }

  /// PBKDF2 with HMAC-SHA512 as the underlying PRF.
  static Uint8List hmacSha512(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) {
    final twPassword = toTWData(password);
    final twSalt = toTWData(salt);
    try {
      return fromTWData(
        lib.TWPBKDF2HmacSha512(twPassword, twSalt, iterations, dkLen),
      );
    } finally {
      deleteTWData(twPassword);
      deleteTWData(twSalt);
    }
  }
}
