import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_string_helper.dart';
import 'tw_data_helper.dart';
import 'tw_private_key.dart';

final _finalizer = Finalizer<Pointer<raw.TWHDWallet>>((ptr) {
  lib.TWHDWalletDelete(ptr);
});

class TWHDWallet {
  Pointer<raw.TWHDWallet>? _ptr;

  TWHDWallet._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a new wallet with random mnemonic.
  /// [strength] 128 = 12 words, 256 = 24 words.
  factory TWHDWallet({int strength = 128, String passphrase = ''}) {
    final twPass = toTWString(passphrase);
    try {
      final ptr = lib.TWHDWalletCreate(strength, twPass);
      if (ptr == nullptr) throw StateError('Failed to create HD wallet');
      return TWHDWallet._wrap(ptr);
    } finally {
      deleteTWString(twPass);
    }
  }

  /// Import wallet from BIP39 mnemonic.
  factory TWHDWallet.createWithMnemonic(String mnemonic,
      {String passphrase = ''}) {
    final twMnemonic = toTWString(mnemonic);
    final twPass = toTWString(passphrase);
    try {
      final ptr = lib.TWHDWalletCreateWithMnemonic(twMnemonic, twPass);
      if (ptr == nullptr) throw ArgumentError('Invalid mnemonic');
      return TWHDWallet._wrap(ptr);
    } finally {
      deleteTWString(twMnemonic);
      deleteTWString(twPass);
    }
  }

  /// Import wallet from entropy.
  factory TWHDWallet.createWithEntropy(Uint8List entropy,
      {String passphrase = ''}) {
    final twEntropy = toTWData1(entropy);
    final twPass = toTWString(passphrase);
    try {
      final ptr = lib.TWHDWalletCreateWithEntropy(twEntropy, twPass);
      if (ptr == nullptr) throw ArgumentError('Invalid entropy');
      return TWHDWallet._wrap(ptr);
    } finally {
      deleteTWData(castTWData1(twEntropy));
      deleteTWString(twPass);
    }
  }

  /// Create from a native pointer (internal use).
  factory TWHDWallet.fromPointer(Pointer<raw.TWHDWallet> ptr) =>
      TWHDWallet._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWHDWallet> get pointer => _ptr!;

  /// The BIP39 mnemonic.
  String get mnemonic => fromTWString(lib.TWHDWalletMnemonic(_ptr!));

  /// The master seed.
  Uint8List get seed => fromTWData1(lib.TWHDWalletSeed(_ptr!));

  /// The original entropy.
  Uint8List get entropy => fromTWData1(lib.TWHDWalletEntropy(_ptr!));

  /// Get default private key for a coin.
  TWPrivateKey getKeyForCoin(raw.TWCoinType coin) {
    final ptr = lib.TWHDWalletGetKeyForCoin(_ptr!, coin);
    return TWPrivateKey.fromPointer(ptr);
  }

  /// Get private key for a coin with custom derivation path.
  TWPrivateKey getKey(raw.TWCoinType coin, String derivationPath) {
    final twPath = toTWString(derivationPath);
    try {
      final ptr = lib.TWHDWalletGetKey(_ptr!, coin, twPath);
      return TWPrivateKey.fromPointer(ptr);
    } finally {
      deleteTWString(twPath);
    }
  }

  /// Get private key for a coin with specific derivation type.
  TWPrivateKey getKeyDerivation(raw.TWCoinType coin, raw.TWDerivation derivation) {
    final ptr = lib.TWHDWalletGetKeyDerivation(_ptr!, coin, derivation);
    return TWPrivateKey.fromPointer(ptr);
  }

  /// Get address string for a coin (convenience).
  String getAddressForCoin(raw.TWCoinType coin) {
    return fromTWString(lib.TWHDWalletGetAddressForCoin(_ptr!, coin));
  }

  /// Get address with specific derivation.
  String getAddressDerivation(raw.TWCoinType coin, raw.TWDerivation derivation) {
    return fromTWString(
        lib.TWHDWalletGetAddressDerivation(_ptr!, coin, derivation));
  }

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _finalizer.detach(this);
      lib.TWHDWalletDelete(_ptr!);
      _ptr = null;
    }
  }
}
