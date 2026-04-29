/// Concrete [EvmSigner] for secp256k1 EOAs.
///
/// D-21: Composes onto a caller-supplied [TWPrivateKey]; borrows the
/// reference and never calls `pk.delete()`. The caller manages the
/// [TWPrivateKey] lifecycle.
///
/// D-22: The `try { ... } finally { keepAlive(_privateKey); }` pattern around
/// the FFI call satisfies Phase 6 D-06: even though the current body has no
/// `await` between `_privateKey.sign` and the return, the wrapping [signDigest]
/// holds the Future across an `await` AND any future Phase-13-era extension
/// that adds an `await` to this body inherits the keepAlive discipline without
/// retrofit.
///
/// D-23: Each [Secp256k1Signer] instance has its own [_pending] field
/// (inherited from [EvmSigner]); the single-flight invariant is per-instance.
/// Multiple [Secp256k1Signer] instances over the SAME [TWPrivateKey] can sign
/// in parallel — this is the documented escape hatch for
/// parallel-different-digests workflows.
// `secp256k1_signer.dart` is a `part` of `evm_signature.dart`'s library
// so that it can override the library-scoped `_doSign` template method
// declared in `evm_signer.dart`. All imports (TWCurve, keepAlive,
// TWPrivateKey, etc.) are declared in the library root `evm_signature.dart`.
part of 'evm_signature.dart';

/// Concrete `EvmSigner` for secp256k1 EOAs. Composes onto a caller-supplied
/// [TWPrivateKey]; the signer borrows the reference and never calls
/// `pk.delete()`. The 65-byte output (`r ‖ s ‖ v`) wraps `TWPrivateKey.sign`
/// for `TWCurve.TWCurveSECP256k1`.
///
/// SAFE TO INSTANTIATE MULTIPLE TIMES OVER THE SAME [TWPrivateKey]: each
/// instance has its own single-flight `_pending` field, so two signers
/// over the same private key can sign different digests in parallel.
class Secp256k1Signer extends EvmSigner {
  Secp256k1Signer(this._privateKey);

  final TWPrivateKey _privateKey;

  @override
  Future<EvmSignature> _doSign(Uint8List digest32) async {
    try {
      // TWPrivateKey.sign(digest, TWCurve.TWCurveSECP256k1) returns 65
      // bytes (r ‖ s ‖ v) for secp256k1 (verified at lib/src/tw_private_key.dart:124).
      final rsv = _privateKey.sign(digest32, TWCurve.TWCurveSECP256k1);
      return Secp256k1Signature.fromRsv(rsv);
    } finally {
      // Phase 6 D-06: keepAlive forces _privateKey to live until at least
      // here, even if Dart 3 escape analysis would otherwise mark it dead
      // after its last `.pointer` read inside `_privateKey.sign`. This
      // future-proofs the body against any later extension that adds an
      // `await` between the FFI call and the return.
      keepAlive(_privateKey);
    }
  }
}
