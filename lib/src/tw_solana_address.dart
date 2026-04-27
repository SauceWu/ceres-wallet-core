import 'dart:ffi';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_string_helper.dart';

final _finalizer = Finalizer<Pointer<raw.TWSolanaAddress>>((ptr) {
  lib.TWSolanaAddressDelete(ptr);
});

/// Wrapper around a native Solana address.
class TWSolanaAddress {
  Pointer<raw.TWSolanaAddress>? _ptr;

  TWSolanaAddress._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a Solana address from its Base58 string representation.
  /// Throws [ArgumentError] if [addressBase58] is not a valid Solana address.
  factory TWSolanaAddress.createWithString(String addressBase58) {
    final twStr = toTWString(addressBase58);
    try {
      final ptr = lib.TWSolanaAddressCreateWithString(twStr);
      if (ptr == nullptr) {
        throw ArgumentError('Invalid Solana address: $addressBase58');
      }
      return TWSolanaAddress._wrap(ptr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Native pointer to the underlying Solana address.
  Pointer<raw.TWSolanaAddress> get pointer => _ptr!;

  /// Returns the Base58 string representation of this address.
  String get description {
    final result = lib.TWSolanaAddressDescription(_ptr!);
    return fromTWString(result);
  }

  /// Derive the default SPL Associated Token Account address for the given
  /// token mint address.
  String defaultTokenAddress(String tokenMintAddress) {
    final twMint = toTWString(tokenMintAddress);
    try {
      final result = lib.TWSolanaAddressDefaultTokenAddress(_ptr!, twMint);
      return fromTWString(result);
    } finally {
      deleteTWString(twMint);
    }
  }

  /// Derive the Token-2022 program associated address for the given token
  /// mint address.
  String token2022Address(String tokenMintAddress) {
    final twMint = toTWString(tokenMintAddress);
    try {
      final result = lib.TWSolanaAddressToken2022Address(_ptr!, twMint);
      return fromTWString(result);
    } finally {
      deleteTWString(twMint);
    }
  }

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.detach(this);
      lib.TWSolanaAddressDelete(_ptr!);
      _ptr = null;
    }
  }
}
