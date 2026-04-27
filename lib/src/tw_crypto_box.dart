import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// NaCl `crypto_box_easy` authenticated public-key encryption.
///
/// Combines X25519 ECDH key agreement with XSalsa20-Poly1305 to provide
/// end-to-end encrypted messages between two key-pair owners.
///
/// To send a message: use the sender's secret key together with the
/// recipient's public key. To open a message: use the recipient's secret
/// key together with the sender's public key. The 24-byte nonce is
/// generated randomly by [TWCryptoBox.encryptEasy] and prepended to the
/// ciphertext, so [TWCryptoBox.decryptEasy] expects nonce-prepended input.

final _secretKeyFinalizer = Finalizer<Pointer<raw.TWCryptoBoxSecretKey>>((ptr) {
  lib.TWCryptoBoxSecretKeyDelete(ptr);
});

final _publicKeyFinalizer = Finalizer<Pointer<raw.TWCryptoBoxPublicKey>>((ptr) {
  lib.TWCryptoBoxPublicKeyDelete(ptr);
});

/// `crypto_box` X25519 secret key (32 bytes).
class TWCryptoBoxSecretKey {
  Pointer<raw.TWCryptoBoxSecretKey>? _ptr;

  TWCryptoBoxSecretKey._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _secretKeyFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Generate a random secret key.
  factory TWCryptoBoxSecretKey.create() {
    final ptr = lib.TWCryptoBoxSecretKeyCreate();
    if (ptr == nullptr) {
      throw StateError('Failed to create crypto_box secret key');
    }
    return TWCryptoBoxSecretKey._wrap(ptr);
  }

  /// Create a secret key from raw 32-byte data.
  factory TWCryptoBoxSecretKey.createWithData(Uint8List data) {
    final twData = toTWData(data);
    try {
      final ptr = lib.TWCryptoBoxSecretKeyCreateWithData(twData);
      if (ptr == nullptr) {
        throw ArgumentError('Invalid crypto_box secret key data');
      }
      return TWCryptoBoxSecretKey._wrap(ptr);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Wrap an existing native pointer (internal use).
  factory TWCryptoBoxSecretKey.fromPointer(
          Pointer<raw.TWCryptoBoxSecretKey> ptr) =>
      TWCryptoBoxSecretKey._wrap(ptr);

  /// Whether [data] is a valid secret key.
  static bool isValid(Uint8List data) {
    final twData = toTWData(data);
    try {
      return lib.TWCryptoBoxSecretKeyIsValid(twData);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Native pointer.
  Pointer<raw.TWCryptoBoxSecretKey> get pointer => _ptr!;

  /// Raw key bytes.
  Uint8List get data {
    final twData = lib.TWCryptoBoxSecretKeyData(_ptr!);
    return fromTWData(twData);
  }

  /// Derive the matching public key.
  TWCryptoBoxPublicKey getPublicKey() {
    final ptr = lib.TWCryptoBoxSecretKeyGetPublicKey(_ptr!);
    return TWCryptoBoxPublicKey.fromPointer(ptr);
  }

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _secretKeyFinalizer.detach(this);
      lib.TWCryptoBoxSecretKeyDelete(_ptr!);
      _ptr = null;
    }
  }
}

/// `crypto_box` X25519 public key (32 bytes).
class TWCryptoBoxPublicKey {
  Pointer<raw.TWCryptoBoxPublicKey>? _ptr;

  TWCryptoBoxPublicKey._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _publicKeyFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a public key from raw 32-byte data.
  factory TWCryptoBoxPublicKey.createWithData(Uint8List data) {
    final twData = toTWData(data);
    try {
      final ptr = lib.TWCryptoBoxPublicKeyCreateWithData(twData);
      if (ptr == nullptr) {
        throw ArgumentError('Invalid crypto_box public key data');
      }
      return TWCryptoBoxPublicKey._wrap(ptr);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Wrap an existing native pointer (internal use).
  factory TWCryptoBoxPublicKey.fromPointer(
          Pointer<raw.TWCryptoBoxPublicKey> ptr) =>
      TWCryptoBoxPublicKey._wrap(ptr);

  /// Whether [data] is a valid public key.
  static bool isValid(Uint8List data) {
    final twData = toTWData(data);
    try {
      return lib.TWCryptoBoxPublicKeyIsValid(twData);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Native pointer.
  Pointer<raw.TWCryptoBoxPublicKey> get pointer => _ptr!;

  /// Raw key bytes.
  Uint8List get data {
    final twData = lib.TWCryptoBoxPublicKeyData(_ptr!);
    return fromTWData(twData);
  }

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _publicKeyFinalizer.detach(this);
      lib.TWCryptoBoxPublicKeyDelete(_ptr!);
      _ptr = null;
    }
  }
}

/// Static helpers for `crypto_box_easy` encrypt / decrypt.
class TWCryptoBox {
  TWCryptoBox._();

  /// Encrypt [message] with the sender's [mySecret] key and the recipient's
  /// [theirPublic] key. A random 24-byte nonce is prepended to the returned
  /// ciphertext.
  static Uint8List encryptEasy(
    TWCryptoBoxSecretKey mySecret,
    TWCryptoBoxPublicKey theirPublic,
    Uint8List message,
  ) {
    final twMsg = toTWData(message);
    try {
      final result = lib.TWCryptoBoxEncryptEasy(
        mySecret.pointer,
        theirPublic.pointer,
        twMsg,
      );
      return fromTWData(result);
    } finally {
      deleteTWData(twMsg);
    }
  }

  /// Decrypt [ciphertext] (with a 24-byte nonce prepended) using the
  /// recipient's [mySecret] key and the sender's [theirPublic] key.
  /// Returns `null` if authentication / decryption fails.
  static Uint8List? decryptEasy(
    TWCryptoBoxSecretKey mySecret,
    TWCryptoBoxPublicKey theirPublic,
    Uint8List ciphertext,
  ) {
    final twCipher = toTWData(ciphertext);
    try {
      final result = lib.TWCryptoBoxDecryptEasy(
        mySecret.pointer,
        theirPublic.pointer,
        twCipher,
      );
      if (result == nullptr) return null;
      final bytes = fromTWData(result);
      if (bytes.isEmpty) return null;
      return bytes;
    } finally {
      deleteTWData(twCipher);
    }
  }
}
