import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_hd_wallet.dart';
import 'tw_private_key.dart';
import 'tw_string_helper.dart';

final _accountFinalizer = Finalizer<Pointer<raw.TWAccount>>((ptr) {
  lib.TWAccountDelete(ptr);
});

final _storedKeyFinalizer = Finalizer<Pointer<raw.TWStoredKey>>((ptr) {
  lib.TWStoredKeyDelete(ptr);
});

/// A pre-derived per-chain account inside a [TWStoredKey].
///
/// Holds the cached address, derivation path, public key and extended
/// public key for one (coin, derivation) pair so the keystore can return
/// addresses without decrypting the seed every time.
class TWAccount {
  Pointer<raw.TWAccount>? _ptr;

  TWAccount._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _accountFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a new account with explicit fields.
  /// Throws [StateError] if the native call returns null.
  factory TWAccount.create({
    required String address,
    required raw.TWCoinType coin,
    required raw.TWDerivation derivation,
    required String derivationPath,
    required String publicKey,
    required String extendedPublicKey,
  }) {
    final twAddress = toTWString(address);
    final twPath = toTWString(derivationPath);
    final twPub = toTWString(publicKey);
    final twExt = toTWString(extendedPublicKey);
    try {
      final ptr = lib.TWAccountCreate(
        twAddress,
        coin,
        derivation,
        twPath,
        twPub,
        twExt,
      );
      if (ptr == nullptr) throw StateError('Failed to create account');
      return TWAccount._wrap(ptr);
    } finally {
      deleteTWString(twAddress);
      deleteTWString(twPath);
      deleteTWString(twPub);
      deleteTWString(twExt);
    }
  }

  /// Create from a native pointer (internal use). Attaches finalizer —
  /// caller is transferring ownership of [ptr] to this Dart object.
  factory TWAccount.fromPointer(Pointer<raw.TWAccount> ptr) =>
      TWAccount._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWAccount> get pointer => _ptr!;

  /// The cached chain-specific address string.
  String get address => fromTWString(lib.TWAccountAddress(_ptr!));

  /// The coin type.
  raw.TWCoinType get coin => lib.TWAccountCoin(_ptr!);

  /// The derivation flavour (default / segwit / legacy / etc).
  raw.TWDerivation get derivation => lib.TWAccountDerivation(_ptr!);

  /// The BIP44 derivation path.
  String get derivationPath =>
      fromTWString(lib.TWAccountDerivationPath(_ptr!));

  /// The hex-encoded public key.
  String get publicKey => fromTWString(lib.TWAccountPublicKey(_ptr!));

  /// The base58-encoded extended public key (xpub/ypub/zpub etc.).
  String get extendedPublicKey =>
      fromTWString(lib.TWAccountExtendedPublicKey(_ptr!));

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _accountFinalizer.detach(this);
      lib.TWAccountDelete(_ptr!);
      _ptr = null;
    }
  }
}

/// Encrypted multi-coin keystore.
///
/// Implements the standard Ethereum keystore v3 JSON format generalized
/// for multi-coin use. The seed/mnemonic/private key is encrypted at rest
/// with scrypt (or pbkdf2) + AES; pre-derived per-chain [TWAccount]s expose
/// addresses without needing to decrypt.
///
/// **Password convention.** Every `password` parameter on this API is a
/// `TWData` blob (NOT a `TWString`). Pass the raw UTF-8 byte representation
/// of the user's password as a [Uint8List]; e.g. `utf8.encode(passwordText)`.
class TWStoredKey {
  Pointer<raw.TWStoredKey>? _ptr;

  TWStoredKey._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _storedKeyFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create an empty stored key with default encryption level.
  factory TWStoredKey.create(String name, Uint8List password) {
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyCreate(twName, twPass);
      if (ptr == nullptr) throw StateError('Failed to create stored key');
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Create an empty stored key with explicit encryption level.
  factory TWStoredKey.createLevel(
    String name,
    Uint8List password,
    raw.TWStoredKeyEncryptionLevel level,
  ) {
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyCreateLevel(twName, twPass, level);
      if (ptr == nullptr) throw StateError('Failed to create stored key');
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Create an empty stored key with explicit cipher encryption mode.
  /// Encryption level is implicit (default).
  factory TWStoredKey.createEncryption(
    String name,
    Uint8List password,
    raw.TWStoredKeyEncryption encryption,
  ) {
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyCreateEncryption(twName, twPass, encryption);
      if (ptr == nullptr) throw StateError('Failed to create stored key');
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import a BIP39 HD wallet under [coin]'s default derivation.
  factory TWStoredKey.importHDWallet(
    String mnemonic,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
  ) {
    final twMnemonic = toTWString(mnemonic);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportHDWallet(
        twMnemonic,
        twName,
        twPass,
        coin,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import HD wallet (invalid mnemonic?)');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twMnemonic);
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import a BIP39 HD wallet with a specific cipher encryption mode.
  factory TWStoredKey.importHDWalletWithEncryption(
    String mnemonic,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
    raw.TWStoredKeyEncryption encryption,
  ) {
    final twMnemonic = toTWString(mnemonic);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportHDWalletWithEncryption(
        twMnemonic,
        twName,
        twPass,
        coin,
        encryption,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import HD wallet (invalid mnemonic?)');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twMnemonic);
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import a raw private key (binary).
  factory TWStoredKey.importPrivateKey(
    Uint8List privateKey,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
  ) {
    final twPriv = toTWData1(privateKey);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportPrivateKey(
        twPriv,
        twName,
        twPass,
        coin,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import private key');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWData(castTWData1(twPriv));
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import a raw private key with a specific cipher encryption mode.
  factory TWStoredKey.importPrivateKeyWithEncryption(
    Uint8List privateKey,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
    raw.TWStoredKeyEncryption encryption,
  ) {
    final twPriv = toTWData1(privateKey);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportPrivateKeyWithEncryption(
        twPriv,
        twName,
        twPass,
        coin,
        encryption,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import private key');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWData(castTWData1(twPriv));
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import an encoded private key (Base58 for SOL, SS58 for DOT, etc.).
  factory TWStoredKey.importPrivateKeyEncoded(
    String privateKey,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
  ) {
    final twPriv = toTWString(privateKey);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportPrivateKeyEncoded(
        twPriv,
        twName,
        twPass,
        coin,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import encoded private key');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twPriv);
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import an encoded private key with a specific cipher encryption mode.
  factory TWStoredKey.importPrivateKeyEncodedWithEncryption(
    String privateKey,
    String name,
    Uint8List password,
    raw.TWCoinType coin,
    raw.TWStoredKeyEncryption encryption,
  ) {
    final twPriv = toTWString(privateKey);
    final twName = toTWString(name);
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyImportPrivateKeyEncodedWithEncryption(
        twPriv,
        twName,
        twPass,
        coin,
        encryption,
      );
      if (ptr == nullptr) {
        throw ArgumentError('Failed to import encoded private key');
      }
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twPriv);
      deleteTWString(twName);
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Import an existing keystore from its v3 JSON byte representation.
  factory TWStoredKey.importJSON(Uint8List json) {
    final twJson = toTWData1(json);
    try {
      final ptr = lib.TWStoredKeyImportJSON(twJson);
      if (ptr == nullptr) throw ArgumentError('Invalid stored key JSON');
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWData(castTWData1(twJson));
    }
  }

  /// Load a stored key from disk. Returns `null` if the file is missing
  /// or not a valid keystore.
  static TWStoredKey? load(String path) {
    final twPath = toTWString(path);
    try {
      final ptr = lib.TWStoredKeyLoad(twPath);
      if (ptr == nullptr) return null;
      return TWStoredKey._wrap(ptr);
    } finally {
      deleteTWString(twPath);
    }
  }

  /// Create from a native pointer (internal use).
  factory TWStoredKey.fromPointer(Pointer<raw.TWStoredKey> ptr) =>
      TWStoredKey._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWStoredKey> get pointer => _ptr!;

  // --------------------------------------------------------------------- //
  // Persistence + export
  // --------------------------------------------------------------------- //

  /// Save the keystore to [path] as v3 JSON. Returns true on success.
  bool store(String path) {
    final twPath = toTWString(path);
    try {
      return lib.TWStoredKeyStore(_ptr!, twPath);
    } finally {
      deleteTWString(twPath);
    }
  }

  /// Export the keystore as v3 JSON bytes.
  Uint8List exportJSON() {
    return fromTWData1(lib.TWStoredKeyExportJSON(_ptr!));
  }

  /// The KDF/cipher parameters (scrypt or pbkdf2) as a JSON string.
  String get encryptionParameters =>
      fromTWString(lib.TWStoredKeyEncryptionParameters(_ptr!));

  // --------------------------------------------------------------------- //
  // Decrypt
  // --------------------------------------------------------------------- //

  /// Decrypt and return the BIP39 mnemonic.
  /// Throws [StateError] on wrong password or non-mnemonic key.
  String decryptMnemonic(Uint8List password) {
    final twPass = toTWData1(password);
    try {
      final result = fromTWString(
        lib.TWStoredKeyDecryptMnemonic(_ptr!, twPass),
      );
      if (result.isEmpty) {
        throw StateError('Wrong password or not an HD wallet');
      }
      return result;
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Decrypt and return the raw private key bytes.
  /// Throws [StateError] on wrong password or no private key.
  Uint8List decryptPrivateKey(Uint8List password) {
    final twPass = toTWData1(password);
    try {
      final result = fromTWData1(
        lib.TWStoredKeyDecryptPrivateKey(_ptr!, twPass),
      );
      if (result.isEmpty) {
        throw StateError('Wrong password or no private key');
      }
      return result;
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Decrypt and return the encoded private key string (Base58/SS58/etc.).
  /// Throws [StateError] on wrong password or no encoded key.
  String decryptPrivateKeyEncoded(Uint8List password) {
    final twPass = toTWData1(password);
    try {
      final result = fromTWString(
        lib.TWStoredKeyDecryptPrivateKeyEncoded(_ptr!, twPass),
      );
      if (result.isEmpty) {
        throw StateError('Wrong password or no encoded private key');
      }
      return result;
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Decrypt and return the underlying HD wallet for mnemonic-based keys.
  /// Throws [StateError] on failure.
  TWHDWallet wallet(Uint8List password) {
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyWallet(_ptr!, twPass);
      if (ptr == nullptr) {
        throw StateError('Wrong password or not an HD wallet');
      }
      return TWHDWallet.fromPointer(ptr);
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  /// Decrypt and return the private key for [coin].
  /// Throws [StateError] on failure.
  TWPrivateKey privateKey(raw.TWCoinType coin, Uint8List password) {
    final twPass = toTWData1(password);
    try {
      final ptr = lib.TWStoredKeyPrivateKey(_ptr!, coin, twPass);
      if (ptr == nullptr) {
        throw StateError('Wrong password or no private key for coin');
      }
      return TWPrivateKey.fromPointer(ptr);
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  // --------------------------------------------------------------------- //
  // Account management
  // --------------------------------------------------------------------- //

  /// Number of stored per-chain accounts.
  int get accountCount => lib.TWStoredKeyAccountCount(_ptr!);

  /// Account at [index]. Returns `null` if out of range.
  /// Per the C API the returned pointer must be freed with `TWAccountDelete`,
  /// so this returns an owned [TWAccount] (finalizer attached).
  TWAccount? account(int index) {
    if (index < 0 || index >= accountCount) return null;
    final ptr = lib.TWStoredKeyAccount(_ptr!, index);
    if (ptr == nullptr) return null;
    return TWAccount.fromPointer(ptr);
  }

  /// Account for [coin], lazily deriving it from [wallet] if missing.
  /// Returns `null` if no matching account can be produced.
  TWAccount? accountForCoin(raw.TWCoinType coin, TWHDWallet wallet) {
    final ptr = lib.TWStoredKeyAccountForCoin(_ptr!, coin, wallet.pointer);
    if (ptr == nullptr) return null;
    return TWAccount.fromPointer(ptr);
  }

  /// Account for ([coin], [derivation]), lazily derived if missing.
  TWAccount? accountForCoinDerivation(
    raw.TWCoinType coin,
    raw.TWDerivation derivation,
    TWHDWallet wallet,
  ) {
    final ptr = lib.TWStoredKeyAccountForCoinDerivation(
      _ptr!,
      coin,
      derivation,
      wallet.pointer,
    );
    if (ptr == nullptr) return null;
    return TWAccount.fromPointer(ptr);
  }

  /// Add a pre-derived account (deprecated upstream — prefer
  /// [addAccountDerivation]).
  void addAccount({
    required String address,
    required raw.TWCoinType coin,
    required String derivationPath,
    required String publicKey,
    required String extendedPublicKey,
  }) {
    final twAddress = toTWString(address);
    final twPath = toTWString(derivationPath);
    final twPub = toTWString(publicKey);
    final twExt = toTWString(extendedPublicKey);
    try {
      lib.TWStoredKeyAddAccount(
        _ptr!,
        twAddress,
        coin,
        twPath,
        twPub,
        twExt,
      );
    } finally {
      deleteTWString(twAddress);
      deleteTWString(twPath);
      deleteTWString(twPub);
      deleteTWString(twExt);
    }
  }

  /// Add a pre-derived account with explicit derivation flavour.
  void addAccountDerivation({
    required String address,
    required raw.TWCoinType coin,
    required raw.TWDerivation derivation,
    required String derivationPath,
    required String publicKey,
    required String extendedPublicKey,
  }) {
    final twAddress = toTWString(address);
    final twPath = toTWString(derivationPath);
    final twPub = toTWString(publicKey);
    final twExt = toTWString(extendedPublicKey);
    try {
      lib.TWStoredKeyAddAccountDerivation(
        _ptr!,
        twAddress,
        coin,
        derivation,
        twPath,
        twPub,
        twExt,
      );
    } finally {
      deleteTWString(twAddress);
      deleteTWString(twPath);
      deleteTWString(twPub);
      deleteTWString(twExt);
    }
  }

  /// Remove all accounts for [coin].
  void removeAccountForCoin(raw.TWCoinType coin) {
    lib.TWStoredKeyRemoveAccountForCoin(_ptr!, coin);
  }

  /// Remove the account for ([coin], [derivation]).
  void removeAccountForCoinDerivation(
    raw.TWCoinType coin,
    raw.TWDerivation derivation,
  ) {
    lib.TWStoredKeyRemoveAccountForCoinDerivation(_ptr!, coin, derivation);
  }

  /// Remove the account for [coin] at [derivationPath].
  void removeAccountForCoinDerivationPath(
    raw.TWCoinType coin,
    String derivationPath,
  ) {
    final twPath = toTWString(derivationPath);
    try {
      lib.TWStoredKeyRemoveAccountForCoinDerivationPath(_ptr!, coin, twPath);
    } finally {
      deleteTWString(twPath);
    }
  }

  /// Re-derive cached addresses for all accounts on [coin] (after a format
  /// change). Returns `false` if no accounts exist for the coin.
  bool updateAddress(raw.TWCoinType coin) {
    return lib.TWStoredKeyUpdateAddress(_ptr!, coin);
  }

  /// Decrypt and re-derive all cached addresses to repair stale data.
  bool fixAddresses(Uint8List password) {
    final twPass = toTWData1(password);
    try {
      return lib.TWStoredKeyFixAddresses(_ptr!, twPass);
    } finally {
      deleteTWData(castTWData1(twPass));
    }
  }

  // --------------------------------------------------------------------- //
  // Metadata
  // --------------------------------------------------------------------- //

  /// User-visible name of the keystore.
  String get name => fromTWString(lib.TWStoredKeyName(_ptr!));

  /// Stable UUID identifier of the keystore.
  String get identifier => fromTWString(lib.TWStoredKeyIdentifier(_ptr!));

  /// True if this stores an HD mnemonic seed.
  bool get isMnemonic => lib.TWStoredKeyIsMnemonic(_ptr!);

  /// True if this stores an encoded private key (e.g. SOL Base58).
  bool get hasPrivateKeyEncoded =>
      lib.TWStoredKeyHasPrivateKeyEncoded(_ptr!);

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _storedKeyFinalizer.detach(this);
      lib.TWStoredKeyDelete(_ptr!);
      _ptr = null;
    }
  }
}
