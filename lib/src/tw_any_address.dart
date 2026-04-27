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

  /// Parse a Bech32 address with a custom HRP. Used for chains where the
  /// canonical HRP isn't the wallet-core default (e.g. Cosmos sub-chains).
  factory TWAnyAddress.createBech32(
    String string,
    raw.TWCoinType coin,
    String hrp,
  ) {
    final twStr = toTWString(string);
    final twHrp = toTWString(hrp);
    try {
      final ptr = lib.TWAnyAddressCreateBech32(twStr, coin, twHrp);
      if (ptr == nullptr) throw ArgumentError('Invalid Bech32 address: $string');
      return TWAnyAddress._wrap(ptr);
    } finally {
      deleteTWString(twStr);
      deleteTWString(twHrp);
    }
  }

  /// Build a Bech32 address from a public key with a custom HRP.
  factory TWAnyAddress.createBech32WithPublicKey({
    required TWPublicKey publicKey,
    required raw.TWCoinType coin,
    required String hrp,
  }) {
    final twHrp = toTWString(hrp);
    try {
      final ptr = lib.TWAnyAddressCreateBech32WithPublicKey(
        publicKey.pointer,
        coin,
        twHrp,
      );
      if (ptr == nullptr) throw StateError('Failed to create Bech32 address');
      return TWAnyAddress._wrap(ptr);
    } finally {
      deleteTWString(twHrp);
    }
  }

  /// Parse an SS58 address (Substrate / Polkadot family) with a custom prefix.
  factory TWAnyAddress.createSS58(
    String string,
    raw.TWCoinType coin,
    int ss58Prefix,
  ) {
    final twStr = toTWString(string);
    try {
      final ptr = lib.TWAnyAddressCreateSS58(twStr, coin, ss58Prefix);
      if (ptr == nullptr) throw ArgumentError('Invalid SS58 address: $string');
      return TWAnyAddress._wrap(ptr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Build an SS58 address from a public key with a custom prefix.
  factory TWAnyAddress.createSS58WithPublicKey({
    required TWPublicKey publicKey,
    required raw.TWCoinType coin,
    required int ss58Prefix,
  }) {
    final ptr = lib.TWAnyAddressCreateSS58WithPublicKey(
      publicKey.pointer,
      coin,
      ss58Prefix,
    );
    if (ptr == nullptr) throw StateError('Failed to create SS58 address');
    return TWAnyAddress._wrap(ptr);
  }

  /// Build a Filecoin address with explicit address-type variant.
  factory TWAnyAddress.createWithPublicKeyFilecoinAddressType({
    required TWPublicKey publicKey,
    required raw.TWFilecoinAddressType filecoinAddressType,
  }) {
    final ptr = lib.TWAnyAddressCreateWithPublicKeyFilecoinAddressType(
      publicKey.pointer,
      filecoinAddressType,
    );
    if (ptr == nullptr) throw StateError('Failed to create Filecoin address');
    return TWAnyAddress._wrap(ptr);
  }

  /// Build a Firo address with explicit address-type variant.
  factory TWAnyAddress.createWithPublicKeyFiroAddressType({
    required TWPublicKey publicKey,
    required raw.TWFiroAddressType firoAddressType,
  }) {
    final ptr = lib.TWAnyAddressCreateWithPublicKeyFiroAddressType(
      publicKey.pointer,
      firoAddressType,
    );
    if (ptr == nullptr) throw StateError('Failed to create Firo address');
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

  /// Validate a Bech32 address string with a custom HRP.
  static bool isValidBech32(String string, raw.TWCoinType coin, String hrp) {
    final twStr = toTWString(string);
    final twHrp = toTWString(hrp);
    try {
      return lib.TWAnyAddressIsValidBech32(twStr, coin, twHrp);
    } finally {
      deleteTWString(twStr);
      deleteTWString(twHrp);
    }
  }

  /// Validate an SS58 address string with a custom prefix.
  static bool isValidSS58(String string, raw.TWCoinType coin, int ss58Prefix) {
    final twStr = toTWString(string);
    try {
      return lib.TWAnyAddressIsValidSS58(twStr, coin, ss58Prefix);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Native equality (delegates to TWAnyAddressEqual). Faster than the
  /// description-based `==` operator when comparing many addresses.
  bool nativeEqual(TWAnyAddress other) =>
      lib.TWAnyAddressEqual(_ptr!, other._ptr!);

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
