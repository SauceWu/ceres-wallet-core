/// EIP-7702 authorization builder for upgrading EOAs to Barz smart accounts.
///
/// AA-12: Provides [Eip7702Upgrader] which computes the authorization hash
/// and signs it with a secp256k1 signer. PasskeySigner is explicitly rejected
/// (Pitfall 1 prevention — EIP-7702 requires secp256k1).
library;

import 'dart:typed_data';

import '../tw_barz.dart';
import 'evm_signature.dart';

/// Result of a signed EIP-7702 authorization.
///
/// Contains the raw authorization parameters and the secp256k1 signature.
/// Callers encode this into the EIP-7702 transaction's `authorization_list`.
final class Eip7702Authorization {
  /// Creates a signed authorization.
  const Eip7702Authorization({
    required this.chainId,
    required this.contractAddress,
    required this.nonce,
    required this.signature,
  });

  /// Big-endian compact chain ID bytes.
  final Uint8List chainId;

  /// EIP-55 hex address of the Barz implementation contract.
  final String contractAddress;

  /// Big-endian compact nonce bytes (the EOA's transaction nonce).
  final Uint8List nonce;

  /// secp256k1 signature over the authorization hash.
  final Secp256k1Signature signature;
}

/// Static helper for EIP-7702 EOA-to-Barz upgrade authorization.
///
/// **secp256k1 only (Pitfall 1 prevention):**
/// EIP-7702 authorization MUST be signed with secp256k1. Passing a
/// [PasskeySigner] throws [ArgumentError] immediately. This prevents the
/// silent failure where a P-256 signature is submitted as a secp256k1
/// authorization and the transaction is rejected on-chain.
abstract final class Eip7702Upgrader {
  /// Returns the 32-byte EIP-7702 authorization hash for the given parameters.
  ///
  /// [chainId] — big-endian compact chain ID bytes (e.g., `[0x01]` for mainnet).
  /// [contractAddress] — EIP-55 address of the Barz implementation contract.
  /// [nonce] — big-endian compact transaction nonce bytes.
  ///
  /// Delegates to [TWBarz.getAuthorizationHash].
  static Uint8List authorizationHash({
    required Uint8List chainId,
    required String contractAddress,
    required Uint8List nonce,
  }) =>
      TWBarz.getAuthorizationHash(chainId, contractAddress, nonce);

  /// Signs an EIP-7702 authorization with the given [signer].
  ///
  /// [signer] must be a [Secp256k1Signer] — throws [ArgumentError] if a
  /// [PasskeySigner] is passed (EIP-7702 requires secp256k1 — PITFALLS.md
  /// Pitfall 1).
  ///
  /// Returns an [Eip7702Authorization] containing the hash inputs and the
  /// secp256k1 signature. Callers must encode this into the `authorization_list`
  /// of an EIP-7702 `SetCode` transaction.
  static Future<Eip7702Authorization> buildAuthorization({
    required Uint8List chainId,
    required String contractAddress,
    required Uint8List nonce,
    required EvmSigner signer,
  }) async {
    if (signer is PasskeySigner) {
      throw ArgumentError(
        'Eip7702Upgrader.buildAuthorization requires a Secp256k1Signer. '
        'PasskeySigner is not supported for EIP-7702 — EIP-7702 authorization '
        'must use secp256k1 (PITFALLS.md Pitfall 1). Use Secp256k1Signer.',
      );
    }
    final hash = authorizationHash(
      chainId: chainId,
      contractAddress: contractAddress,
      nonce: nonce,
    );
    final sig = await signer.signDigest(hash);
    // EvmSigner is not sealed — a third-party implementation could return a
    // non-Secp256k1Signature even after the PasskeySigner guard above.
    // Validate the result type explicitly to surface a clear error instead of
    // a CastError with no context.
    if (sig is! Secp256k1Signature) {
      throw ArgumentError(
        'Eip7702Upgrader.buildAuthorization: signer returned ${sig.runtimeType} '
        'but EIP-7702 requires Secp256k1Signature. '
        'Only Secp256k1Signer is supported.',
      );
    }
    return Eip7702Authorization(
      chainId: chainId,
      contractAddress: contractAddress,
      nonce: nonce,
      signature: sig,
    );
  }
}
