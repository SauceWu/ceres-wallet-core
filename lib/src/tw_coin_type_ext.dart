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
}
