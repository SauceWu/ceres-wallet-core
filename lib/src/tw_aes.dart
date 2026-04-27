import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// Static wrappers around the `TWAES*` symmetric-cipher FFI surface.
///
/// AES-CBC takes a [raw.TWAESPaddingMode] (`Zero` or `PKCS7`); AES-CTR is a
/// stream mode and takes no padding. [key] must be 16, 24, or 32 bytes.
class TWAES {
  TWAES._();

  /// Encrypt [data] with AES in CBC mode.
  static Uint8List encryptCBC(
    Uint8List key,
    Uint8List data,
    Uint8List iv,
    raw.TWAESPaddingMode mode,
  ) {
    final twKey = toTWData(key);
    final twData = toTWData(data);
    final twIv = toTWData(iv);
    try {
      return fromTWData(lib.TWAESEncryptCBC(twKey, twData, twIv, mode));
    } finally {
      deleteTWData(twKey);
      deleteTWData(twData);
      deleteTWData(twIv);
    }
  }

  /// Decrypt [data] with AES in CBC mode.
  static Uint8List decryptCBC(
    Uint8List key,
    Uint8List data,
    Uint8List iv,
    raw.TWAESPaddingMode mode,
  ) {
    final twKey = toTWData(key);
    final twData = toTWData(data);
    final twIv = toTWData(iv);
    try {
      return fromTWData(lib.TWAESDecryptCBC(twKey, twData, twIv, mode));
    } finally {
      deleteTWData(twKey);
      deleteTWData(twData);
      deleteTWData(twIv);
    }
  }

  /// Encrypt [data] with AES in CTR mode.
  static Uint8List encryptCTR(Uint8List key, Uint8List data, Uint8List iv) {
    final twKey = toTWData(key);
    final twData = toTWData(data);
    final twIv = toTWData(iv);
    try {
      return fromTWData(lib.TWAESEncryptCTR(twKey, twData, twIv));
    } finally {
      deleteTWData(twKey);
      deleteTWData(twData);
      deleteTWData(twIv);
    }
  }

  /// Decrypt [data] with AES in CTR mode.
  static Uint8List decryptCTR(Uint8List key, Uint8List data, Uint8List iv) {
    final twKey = toTWData(key);
    final twData = toTWData(data);
    final twIv = toTWData(iv);
    try {
      return fromTWData(lib.TWAESDecryptCTR(twKey, twData, twIv));
    } finally {
      deleteTWData(twKey);
      deleteTWData(twData);
      deleteTWData(twIv);
    }
  }
}
