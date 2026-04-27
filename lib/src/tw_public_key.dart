import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';

final _finalizer = Finalizer<Pointer<raw.TWPublicKey>>((ptr) {
  lib.TWPublicKeyDelete(ptr);
});

class TWPublicKey {
  Pointer<raw.TWPublicKey>? _ptr;

  TWPublicKey._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create from raw bytes and type.
  factory TWPublicKey(Uint8List data, raw.TWPublicKeyType type) {
    return TWPublicKey.createWithData(data, type);
  }

  /// Create from raw bytes and type.
  factory TWPublicKey.createWithData(Uint8List data, raw.TWPublicKeyType type) {
    final twData = toTWData(data);
    try {
      final ptr = lib.TWPublicKeyCreateWithData(twData, type);
      if (ptr == nullptr) throw ArgumentError('Invalid public key data');
      return TWPublicKey._wrap(ptr);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Create from a native pointer (internal use).
  factory TWPublicKey.fromPointer(Pointer<raw.TWPublicKey> ptr) =>
      TWPublicKey._wrap(ptr);

  /// Recover the public key from a [signature] over [message].
  /// Returns `null` if recovery fails.
  static TWPublicKey? recover(Uint8List signature, Uint8List message) {
    final twSig = toTWData1(signature);
    final twMsg = toTWData1(message);
    try {
      final ptr = lib.TWPublicKeyRecover(twSig, twMsg);
      if (ptr == nullptr) return null;
      return TWPublicKey.fromPointer(ptr);
    } finally {
      deleteTWData(castTWData1(twSig));
      deleteTWData(castTWData1(twMsg));
    }
  }

  /// Native pointer.
  Pointer<raw.TWPublicKey> get pointer => _ptr!;

  /// Check if data is a valid public key of the given type.
  static bool isValid(Uint8List data, raw.TWPublicKeyType type) {
    final twData = toTWData(data);
    try {
      return lib.TWPublicKeyIsValid(twData, type);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Raw key bytes.
  Uint8List get data {
    final twData = lib.TWPublicKeyData(_ptr!);
    return fromTWData(twData);
  }

  /// Whether this is a compressed key.
  bool get isCompressed => lib.TWPublicKeyIsCompressed(_ptr!);

  /// Key type.
  raw.TWPublicKeyType get type => lib.TWPublicKeyKeyType(_ptr!);

  /// Human-readable description.
  String get description => fromTWString(lib.TWPublicKeyDescription(_ptr!));

  /// Compressed version of this key.
  TWPublicKey compressed() {
    final ptr = lib.TWPublicKeyCompressed(_ptr!);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Uncompressed version of this key.
  TWPublicKey uncompressed() {
    final ptr = lib.TWPublicKeyUncompressed(_ptr!);
    return TWPublicKey.fromPointer(ptr);
  }

  /// Verify a signature against a message.
  bool verify(Uint8List signature, Uint8List message) {
    final twSig = toTWData(signature);
    final twMsg = toTWData(message);
    try {
      return lib.TWPublicKeyVerify(_ptr!, twSig, twMsg);
    } finally {
      deleteTWData(twSig);
      deleteTWData(twMsg);
    }
  }

  /// Verify a DER (ASN.1)-encoded ECDSA signature.
  bool verifyAsDER(Uint8List signature, Uint8List message) {
    final twSig = toTWData1(signature);
    final twMsg = toTWData1(message);
    try {
      return lib.TWPublicKeyVerifyAsDER(_ptr!, twSig, twMsg);
    } finally {
      deleteTWData(castTWData1(twSig));
      deleteTWData(castTWData1(twMsg));
    }
  }

  /// Verify a Zilliqa Schnorr signature.
  bool verifyZilliqaSchnorr(Uint8List signature, Uint8List message) {
    final twSig = toTWData1(signature);
    final twMsg = toTWData1(message);
    try {
      return lib.TWPublicKeyVerifyZilliqaSchnorr(_ptr!, twSig, twMsg);
    } finally {
      deleteTWData(castTWData1(twSig));
      deleteTWData(castTWData1(twMsg));
    }
  }

  /// Release native resources.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.detach(this);
      lib.TWPublicKeyDelete(_ptr!);
      _ptr = null;
    }
  }
}
