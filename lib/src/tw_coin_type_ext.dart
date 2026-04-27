import 'dart:ffi';
import '../bindings/ceres_wallet_core_bindings.dart';
import 'native.dart';
import 'tw_string_helper.dart';

/// Extension on TWCoinType enum to add convenience properties and methods
/// matching the wallet_core_bindings API.
extension TWCoinTypeExt on TWCoinType {
  /// Elliptic curve used by this coin.
  TWCurve get curve => lib.TWCoinTypeCurve(this);

  /// Public key type for this coin.
  TWPublicKeyType get publicKeyType => lib.TWCoinTypePublicKeyType(this);

  /// Default derivation path.
  String get derivationPath => fromTWString(lib.TWCoinTypeDerivationPath(this));

  /// Derivation path with specific derivation type.
  String derivationPathWithDerivation(TWDerivation derivation) =>
      fromTWString(lib.TWCoinTypeDerivationPathWithDerivation(this, derivation));

  /// Blockchain type.
  TWBlockchain get blockchain => lib.TWCoinTypeBlockchain(this);

  /// BIP44 purpose.
  TWPurpose get purpose => lib.TWCoinTypePurpose(this);

  /// Validate an address string for this coin.
  bool validate(String address) {
    final twAddr = toTWString(address);
    try {
      return lib.TWCoinTypeValidate(this, twAddr);
    } finally {
      deleteTWString(twAddr);
    }
  }

  /// Derive address from private key.
  String deriveAddress(Pointer privateKey) =>
      fromTWString(lib.TWCoinTypeDeriveAddress(this, privateKey.cast()));

  /// Derive address from public key.
  String deriveAddressFromPublicKey(Pointer publicKey) =>
      fromTWString(lib.TWCoinTypeDeriveAddressFromPublicKey(this, publicKey.cast()));

  /// Derive address from public key with explicit derivation flavour.
  String deriveAddressFromPublicKeyAndDerivation(
    Pointer publicKey,
    TWDerivation derivation,
  ) =>
      fromTWString(
        lib.TWCoinTypeDeriveAddressFromPublicKeyAndDerivation(
          this,
          publicKey.cast(),
          derivation,
        ),
      );

  // ──────────────── Chain metadata ────────────────

  /// EVM chain id (hex/decimal string). Empty for non-EVM chains.
  String get chainId => fromTWString(lib.TWCoinTypeChainId(this));

  /// SLIP-0044 coin index used in BIP44 derivation paths.
  int get slip44Id => lib.TWCoinTypeSlip44Id(this);

  /// Bitcoin-family P2PKH version byte. 0 for non-BTC chains.
  int get p2pkhPrefix => lib.TWCoinTypeP2pkhPrefix(this);

  /// Bitcoin-family P2SH version byte. 0 for non-BTC chains.
  int get p2shPrefix => lib.TWCoinTypeP2shPrefix(this);

  /// Bitcoin-family static address prefix byte (e.g. cosmos `0x00`).
  int get staticPrefix => lib.TWCoinTypeStaticPrefix(this);

  /// Bech32 HRP for this chain. Returns the special `TWHRP.unknown` for
  /// chains that don't use Bech32.
  TWHRP get hrp => lib.TWCoinTypeHRP(this);

  /// Substrate SS58 prefix. 0 for non-Substrate chains.
  int get ss58Prefix => lib.TWCoinTypeSS58Prefix(this);

  /// Default extended-private-key version (xprv / yprv / zprv flavour).
  TWHDVersion get xprvVersion => lib.TWCoinTypeXprvVersion(this);

  /// Default extended-public-key version (xpub / ypub / zpub flavour).
  TWHDVersion get xpubVersion => lib.TWCoinTypeXpubVersion(this);

  // ──────────────── Display configuration ────────────────

  /// Stable string identifier (e.g. `ethereum`, `solana`).
  String get id => fromTWString(lib.TWCoinTypeConfigurationGetID(this));

  /// Human-readable chain name.
  String get name => fromTWString(lib.TWCoinTypeConfigurationGetName(this));

  /// Native asset ticker (e.g. `ETH`, `SOL`).
  String get symbol => fromTWString(lib.TWCoinTypeConfigurationGetSymbol(this));

  /// Decimals of the native asset.
  int get decimals => lib.TWCoinTypeConfigurationGetDecimals(this);

  /// Block-explorer URL template for an account.
  String accountURL(String accountID) {
    final twId = toTWString(accountID);
    try {
      return fromTWString(
        lib.TWCoinTypeConfigurationGetAccountURL(this, twId),
      );
    } finally {
      deleteTWString(twId);
    }
  }

  /// Block-explorer URL template for a transaction.
  String transactionURL(String transactionID) {
    final twId = toTWString(transactionID);
    try {
      return fromTWString(
        lib.TWCoinTypeConfigurationGetTransactionURL(this, twId),
      );
    } finally {
      deleteTWString(twId);
    }
  }
}
