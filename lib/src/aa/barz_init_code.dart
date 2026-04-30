/// ERC-4337 initCode builder for Barz passkey smart accounts.
///
/// AA-09: Provides [BarzInitCode.forPasskey] which returns both the ERC-4337
/// v0.6 monolithic `initCode` and the ERC-4337 v0.7 split
/// `(factory, factoryData)` pair.
library;

import 'dart:typed_data';

import '../_ffi_reachability.dart' show keepAlive;
import '../../bindings/ceres_wallet_core_bindings.dart' as raw;
import '../tw_barz.dart';
import '../tw_public_key.dart';
import 'barz_deployment.dart';

/// The two ERC-4337 initCode representations returned by [BarzInitCode.forPasskey].
///
/// - [initCodeV06]: v0.6 monolithic format — `factory_address_bytes ‖ factoryData`
/// - [factoryV07]: v0.7 factory address string (first 20 bytes of initCodeV06)
/// - [factoryDataV07]: v0.7 factory calldata (bytes after the factory address)
///
/// Invariant: `initCodeV06 == factoryV07_bytes ‖ factoryDataV07`.
final class BarzInitCodeResult {
  /// Creates the result with all three fields.
  const BarzInitCodeResult({
    required this.initCodeV06,
    required this.factoryV07,
    required this.factoryDataV07,
  });

  /// ERC-4337 v0.6 `initCode` field:
  /// 20-byte factory address ‖ `createAccount(verificationFacet, owner, salt)` ABI calldata.
  final Uint8List initCodeV06;

  /// ERC-4337 v0.7 `factory` field (0x-prefixed 40-hex-char address string).
  final String factoryV07;

  /// ERC-4337 v0.7 `factoryData` field
  /// (`createAccount(verificationFacet, owner, salt)` ABI calldata only,
  /// without the factory address prefix).
  final Uint8List factoryDataV07;
}

/// Static utilities for generating ERC-4337 initCode for Barz passkey accounts.
///
/// AA-09: Wraps `TWBarz.getInitCode` and splits the result into both the
/// ERC-4337 v0.6 (monolithic) and v0.7 (factory + factoryData) representations.
///
/// **Input constraints:**
/// - `p256PubKey`: exactly 64 bytes — raw uncompressed P-256 key without the
///   `04` prefix byte (X‖Y). The `04` prefix is added internally before passing
///   to `TWBarz.getInitCode`.
/// - `salt`: valid uint32 value (0 ≤ salt ≤ 0xFFFF_FFFF). Maps directly to
///   the Solidity `uint256 _salt` parameter of `BarzFactory.createAccount`.
abstract final class BarzInitCode {
  /// Generates ERC-4337 initCode in both v0.6 and v0.7 formats for a
  /// passkey-owned Barz smart account.
  ///
  /// Throws [ArgumentError] if [p256PubKey] is not exactly 64 bytes.
  /// Throws [RangeError] if [salt] is outside [0, 0xFFFF_FFFF].
  ///
  /// **Platform note:** Internally calls `TWBarz.getInitCode` via FFI.
  /// On macOS development hosts where the native dylib is not loaded, tests
  /// should use `skip: 'macOS host dylib unavailable — see TODO(P13)'`.
  static BarzInitCodeResult forPasskey(
    BarzDeployment deployment,
    Uint8List p256PubKey,
    int salt,
  ) {
    if (p256PubKey.length != 64) {
      throw ArgumentError.value(
        p256PubKey,
        'p256PubKey',
        'P-256 public key must be 64 bytes (X‖Y without 04 prefix); '
            'got ${p256PubKey.length} bytes',
      );
    }
    if (salt < 0 || salt > 0xFFFFFFFF) {
      throw RangeError.value(salt, 'salt', 'Must be a uint32 (0..0xFFFF_FFFF)');
    }

    // Prepend 0x04 for uncompressed point encoding required by wallet-core.
    final pubKeyUncompressed = Uint8List(65)..[0] = 0x04
      ..setRange(1, 65, p256PubKey);

    final pubKey = TWPublicKey(
      pubKeyUncompressed,
      raw.TWPublicKeyType.TWPublicKeyTypeNIST256p1,
    );
    try {
      final initCodeV06 = TWBarz.getInitCode(
        deployment.factory,
        pubKey,
        deployment.verificationFacet,
        salt,
      );

      // v0.7 split: first 20 bytes = factory address, rest = factoryData.
      // Use deployment.factory directly (EIP-55 checksum preserved) rather than
      // reconstructing the address from raw bytes (which produces lowercase hex).
      final factoryV07 = deployment.factory;
      final factoryDataV07 = initCodeV06.sublist(20);

      return BarzInitCodeResult(
        initCodeV06: initCodeV06,
        factoryV07: factoryV07,
        factoryDataV07: factoryDataV07,
      );
    } finally {
      keepAlive(pubKey);
    }
  }
}
