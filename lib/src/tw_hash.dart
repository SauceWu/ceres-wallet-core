import 'dart:typed_data';
import 'native.dart';
import 'tw_data_helper.dart';

/// Static wrappers around the `TWHash*` cryptographic-hash FFI surface.
///
/// Each method takes a `Uint8List` of input bytes and returns the digest as
/// a `Uint8List`. Native `TWData` allocations are always freed in `finally`
/// blocks.
class TWHash {
  TWHash._();

  /// Keccak-256 (Ethereum-style; not NIST SHA3-256).
  static Uint8List keccak256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashKeccak256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Keccak-512.
  static Uint8List keccak512(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashKeccak512(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA-1 (legacy; do not use for security).
  static Uint8List sha1(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA1(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA-256.
  static Uint8List sha256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA-512.
  static Uint8List sha512(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA512(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA-512/256 (truncated SHA-512).
  static Uint8List sha512_256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA512_256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// NIST SHA3-256.
  static Uint8List sha3_256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA3_256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// NIST SHA3-512.
  static Uint8List sha3_512(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA3_512(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA3-256 followed by RIPEMD-160.
  static Uint8List sha3_256RIPEMD(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA3_256RIPEMD(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// RIPEMD-160.
  static Uint8List ripemd(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashRIPEMD(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Blake-256.
  static Uint8List blake256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashBlake256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Blake-256 applied twice (Blake256(Blake256(x))).
  static Uint8List blake256Blake256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashBlake256Blake256(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Blake-256 followed by RIPEMD-160.
  static Uint8List blake256RIPEMD(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashBlake256RIPEMD(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// BLAKE2b with the requested digest [size] in bytes.
  static Uint8List blake2b(Uint8List data, int size) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashBlake2b(twData, size));
    } finally {
      deleteTWData(twData);
    }
  }

  /// BLAKE2b with a personalization salt and a digest length [outlen] in bytes.
  static Uint8List blake2bPersonal(
    Uint8List data,
    Uint8List personal,
    int outlen,
  ) {
    final twData = toTWData(data);
    final twPersonal = toTWData(personal);
    try {
      return fromTWData(
        lib.TWHashBlake2bPersonal(twData, twPersonal, outlen),
      );
    } finally {
      deleteTWData(twData);
      deleteTWData(twPersonal);
    }
  }

  /// Groestl-512.
  static Uint8List groestl512(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashGroestl512(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Groestl-512 applied twice.
  static Uint8List groestl512Groestl512(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashGroestl512Groestl512(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// SHA-256 followed by RIPEMD-160 (Bitcoin "HASH160").
  static Uint8List sha256RIPEMD(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA256RIPEMD(twData));
    } finally {
      deleteTWData(twData);
    }
  }

  /// Double SHA-256 (Bitcoin "HASH256").
  static Uint8List sha256SHA256(Uint8List data) {
    final twData = toTWData(data);
    try {
      return fromTWData(lib.TWHashSHA256SHA256(twData));
    } finally {
      deleteTWData(twData);
    }
  }
}
