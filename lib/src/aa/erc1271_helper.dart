/// Per-(barzAddress, chainId) helper for ERC-1271 signature preparation.
///
/// AA-10, AA-11: Provides [Erc1271Helper] which computes personal_sign /
/// typed-data digests and formats Barz-shaped signature blobs for smart-account
/// message signing.
///
/// **Design decisions:**
/// - Verifies via `IERC1271.isValidSignature`, NOT `ecrecover`.
/// - No domain separator caching — every call routes through
///   `TWBarz.getPrefixedMsgHash` to guarantee per-(account, chain) isolation
///   (Pitfall 6 prevention).
/// - No public surface returns a 65-byte EOA-style `r‖s‖v` (Pitfall 5
///   prevention).
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

import '../tw_barz.dart';
import '../tw_ethereum_abi.dart';
import '../tw_hash.dart';
import 'barz_deployment.dart';
import 'evm_signature.dart';
import 'passkey_assertion.dart';

/// Per-(barzAddress, chainId) ERC-1271 helper for Barz smart accounts.
///
/// Verifies via `IERC1271.isValidSignature`, NOT `ecrecover`.
///
/// Each instance is immutably bound to one smart-account address and one
/// chain. There is no setter or mutator for either field after construction.
///
/// **No domain separator caching**: every digest call invokes
/// `TWBarz.getPrefixedMsgHash` fresh — see Pitfall 6 in PITFALLS.md.
///
/// Usage:
/// ```dart
/// final helper = Erc1271Helper(
///   barzAddress: '0xYourBarzWallet',
///   chainId: 1,
/// );
/// final digest = helper.personalSignDigest(utf8.encode('Hello'));
/// ```
final class Erc1271Helper {
  /// Constructs an [Erc1271Helper] bound to [barzAddress] on [chainId].
  ///
  /// [barzAddress] must be a 0x-prefixed 40-hex-char Ethereum address.
  /// [chainId] must be a positive integer (e.g., 1 for Ethereum mainnet).
  const Erc1271Helper({
    required this.barzAddress,
    required this.chainId,
  });

  /// The smart-account address this instance is bound to.
  final String barzAddress;

  /// The chain ID this instance is bound to.
  final int chainId;

  // ── Private Solidity ABI signature ────────────────────────────────────────

  // IERC-1271: isValidSignature(bytes32,bytes) → bytes4
  static const String _isValidSignatureSig = 'isValidSignature(bytes32,bytes)';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Computes the ERC-1271 digest for an Ethereum personal_sign message.
  ///
  /// Applies EIP-191 personal-sign prefix to [message], hashes with
  /// `keccak256`, then wraps with `TWBarz.getPrefixedMsgHash` using this
  /// instance's [barzAddress] and [chainId].
  ///
  /// The returned 32 bytes are what the smart account's ERC-1271
  /// `isValidSignature` implementation expects as its `hash` argument.
  ///
  /// No caching: every call re-invokes `getPrefixedMsgHash`.
  Uint8List personalSignDigest(Uint8List message) {
    // EIP-191: "\x19Ethereum Signed Message:\n{len}{message}"
    final prefixBytes = utf8.encode('\x19Ethereum Signed Message:\n${message.length}');
    final buf = Uint8List(prefixBytes.length + message.length);
    buf.setRange(0, prefixBytes.length, prefixBytes);
    buf.setRange(prefixBytes.length, buf.length, message);
    final msgHash = TWHash.keccak256(buf);
    return TWBarz.getPrefixedMsgHash(msgHash, barzAddress, chainId);
  }

  /// Computes the ERC-1271 digest for an EIP-712 typed-data payload.
  ///
  /// [domainSeparatorHash] — the 32-byte EIP-712 domain separator hash
  /// (`keccak256` of the domain struct, typically computed off-chain).
  ///
  /// [structHash] — the 32-byte EIP-712 struct hash (`hashStruct(message)`).
  ///
  /// Builds `keccak256("\x19\x01" ‖ domainSeparatorHash ‖ structHash)`
  /// then wraps with `TWBarz.getPrefixedMsgHash`.
  ///
  /// No caching: every call re-invokes `getPrefixedMsgHash`.
  Uint8List typedDataDigest(
    Uint8List domainSeparatorHash,
    Uint8List structHash,
  ) {
    if (domainSeparatorHash.length != 32) {
      throw ArgumentError.value(
        domainSeparatorHash,
        'domainSeparatorHash',
        'must be 32 bytes (got ${domainSeparatorHash.length})',
      );
    }
    if (structHash.length != 32) {
      throw ArgumentError.value(
        structHash,
        'structHash',
        'must be 32 bytes (got ${structHash.length})',
      );
    }
    // EIP-712 typed-data prefix: 0x19 0x01
    final buf = Uint8List(66);
    buf[0] = 0x19;
    buf[1] = 0x01;
    buf.setRange(2, 34, domainSeparatorHash);
    buf.setRange(34, 66, structHash);
    final eip712Hash = TWHash.keccak256(buf);
    return TWBarz.getPrefixedMsgHash(eip712Hash, barzAddress, chainId);
  }

  /// Formats a WebAuthn [assertion] into a Barz-shaped [PasskeySignature].
  ///
  /// Calls `TWBarz.getFormattedSignature` with the assertion's DER signature,
  /// challenge, authenticator data, and client-data JSON. The result is
  /// guaranteed to be ≥ 200 bytes (the typical Barz envelope is ~290 bytes).
  ///
  /// The returned [PasskeySignature] is the value to pass as the `signature`
  /// argument to `isValidSignature`.
  PasskeySignature formatPasskeySignature(PasskeyAssertion assertion) {
    final blob = TWBarz.getFormattedSignature(
      assertion.derSignature,
      assertion.challenge,
      assertion.authenticatorData,
      assertion.clientDataJSON,
    );
    return PasskeySignature.fromBarzFormatted(blob);
  }

  /// ABI-encodes an `isValidSignature(bytes32,bytes)` call.
  ///
  /// [hash32] must be exactly 32 bytes (the ERC-1271 message hash).
  /// [sig] is the Barz-formatted signature blob.
  ///
  /// Returns the complete 4-byte selector + ABI-encoded calldata, suitable
  /// for use as `data` in an `eth_call` targeting the Barz account.
  ///
  /// The 4-byte selector is `keccak256("isValidSignature(bytes32,bytes)")[:4]`
  /// = `0x1626ba7e`.
  Uint8List encodeIsValidSignature(Uint8List hash32, Uint8List sig) {
    if (hash32.length != 32) {
      throw ArgumentError.value(
        hash32,
        'hash32',
        'must be exactly 32 bytes (got ${hash32.length})',
      );
    }
    final fn = TWEthereumAbiFunction.createWithString(_isValidSignatureSig);
    try {
      fn.addParamBytesFix(32, hash32, false);
      fn.addParamBytes(sig, false);
      return TWEthereumAbi.encode(fn);
    } finally {
      fn.delete();
    }
  }

  /// Convenience factory that derives [barzAddress] and [chainId] from a
  /// [BarzDeployment] and a pre-computed [barzAddress] string.
  ///
  /// Use this when you have already resolved the counterfactual address (e.g.,
  /// via [PasskeyBarzAddress.compute]) and want a ready-to-use helper.
  factory Erc1271Helper.forDeployment({
    required BarzDeployment deployment,
    required String barzAddress,
  }) =>
      Erc1271Helper(barzAddress: barzAddress, chainId: deployment.chainId);

  @override
  String toString() =>
      'Erc1271Helper(barzAddress: $barzAddress, chainId: $chainId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Erc1271Helper &&
          other.barzAddress == barzAddress &&
          other.chainId == chainId;

  @override
  int get hashCode => Object.hash(barzAddress, chainId);
}
