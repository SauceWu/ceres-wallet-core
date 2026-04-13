import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_string_helper.dart';
import 'tw_data_helper.dart';
import 'tw_public_key.dart';

final _finalizer = Finalizer<Pointer<raw.TWAnyAddress>>((ptr) {
  lib.TWAnyAddressDelete(ptr);
});

class TWAnyAddress {
  Pointer<raw.TWAnyAddress>? _ptr;

  TWAnyAddress._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Parse an address string for a coin type.
  factory TWAnyAddress(String string, raw.TWCoinType coin) {
    final twStr = toTWString(string);
    try {
      final ptr = lib.TWAnyAddressCreateWithString(twStr, coin);
      if (ptr == nullptr) throw ArgumentError('Invalid address: $string');
      return TWAnyAddress._wrap(ptr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Create address from public key and coin type.
  factory TWAnyAddress.createWithPublicKey(
      TWPublicKey publicKey, raw.TWCoinType coin) {
    final ptr = lib.TWAnyAddressCreateWithPublicKey(publicKey.pointer, coin);
    if (ptr == nullptr) throw StateError('Failed to create address');
    return TWAnyAddress._wrap(ptr);
  }

  /// Create address from public key with specific derivation.
  factory TWAnyAddress.createWithPublicKeyDerivation({
    required TWPublicKey publicKey,
    required raw.TWCoinType coin,
    required raw.TWDerivation derivation,
  }) {
    final ptr = lib.TWAnyAddressCreateWithPublicKeyDerivation(
        publicKey.pointer, coin, derivation);
    if (ptr == nullptr) throw StateError('Failed to create address');
    return TWAnyAddress._wrap(ptr);
  }

  /// Create from a native pointer (internal use).
  factory TWAnyAddress.fromPointer(Pointer<raw.TWAnyAddress> ptr) =>
      TWAnyAddress._wrap(ptr);

  /// Validate an address string for a coin type.
  static bool isValid(String string, raw.TWCoinType coin) {
    final twStr = toTWString(string);
    try {
      return lib.TWAnyAddressIsValid(twStr, coin);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// The address string.
  String get description => fromTWString(lib.TWAnyAddressDescription(_ptr!));

  /// Underlying address data.
  Uint8List get data => fromTWData1(lib.TWAnyAddressData(_ptr!));

  /// Coin type of this address.
  raw.TWCoinType get coin => lib.TWAnyAddressCoin(_ptr!);

  @override
  String toString() => description;

  @override
  bool operator ==(Object other) =>
      other is TWAnyAddress && description == other.description;

  @override
  int get hashCode => description.hashCode;

  /// Release native resources.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.detach(this);
      lib.TWAnyAddressDelete(_ptr!);
      _ptr = null;
    }
  }
}
