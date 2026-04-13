import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';
import 'tw_public_key.dart';

final _finalizer = Finalizer<Pointer<raw.TWPrivateKey>>((ptr) {
  lib.TWPrivateKeyDelete(ptr);
});

class TWPrivateKey {
  Pointer<raw.TWPrivateKey>? _ptr;

  TWPrivateKey._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a random private key.
  factory TWPrivateKey() {
    final ptr = lib.TWPrivateKeyCreate();
    if (ptr == nullptr) throw StateError('Failed to create private key');
    return TWPrivateKey._wrap(ptr);
  }

  /// Create from raw bytes (32 bytes).
  factory TWPrivateKey.createWithData(Uint8List data) {
    final twData = toTWData(data);
    try {
      final ptr = lib.TWPrivateKeyCreateWithData(twData);
      if (ptr == nullptr) throw ArgumentError('Invalid private key data');
      return TWPrivateKey._wrap(ptr);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Create from hex string.
  factory TWPrivateKey.createWithHexString(String hex) {
    return TWPrivateKey.createWithData(_hexToBytes(hex));
  }

  /// Create from a native pointer (internal use).
  factory TWPrivateKey.fromPointer(Pointer<raw.TWPrivateKey> ptr) =>
      TWPrivateKey._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWPrivateKey> get pointer => _ptr!;

  /// Check if data is a valid private key for the given curve.
  static bool isValid(Uint8List data, raw.TWCurve curve) {
    final twData = toTWData(data);
    try {
      return lib.TWPrivateKeyIsValid(twData, curve);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Raw 32-byte key data.
  Uint8List get data {
    final twData = lib.TWPrivateKeyData(_ptr!);
    return fromTWData(twData);
  }

  /// Get public key for a coin type.
  TWPublicKey getPublicKey(raw.TWCoinType coinType) {
    final ptr = lib.TWPrivateKeyGetPublicKey(_ptr!, coinType);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Get public key by explicit type.
  TWPublicKey getPublicKeyByType(raw.TWPublicKeyType type) {
    final ptr = lib.TWPrivateKeyGetPublicKeyByType(_ptr!, type);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Get secp256k1 public key.
  TWPublicKey getPublicKeySecp256k1(bool compressed) {
    final ptr = lib.TWPrivateKeyGetPublicKeySecp256k1(_ptr!, compressed);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Get ed25519 public key.
  TWPublicKey getPublicKeyEd25519() {
    final ptr = lib.TWPrivateKeyGetPublicKeyEd25519(_ptr!);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Sign data with the given curve.
  Uint8List sign(Uint8List digest, raw.TWCurve curve) {
    final twDigest = toTWData(digest);
    try {
      final result = lib.TWPrivateKeySign(
          _ptr!, twDigest, curve);
      return fromTWData(result);
    } finally {
      deleteTWData(twDigest);
    }
  }

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.detach(this);
      lib.TWPrivateKeyDelete(_ptr!);
      _ptr = null;
    }
  }
}

Uint8List _hexToBytes(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  final length = h.length ~/ 2;
  final result = Uint8List(length);
  for (var i = 0; i < length; i++) {
    result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
