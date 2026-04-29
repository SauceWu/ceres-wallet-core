/// `signDigest(Uint8List digest32)` takes a raw 32-byte EVM digest (e.g.
/// keccak256 of RLP-encoded tx, or userOpHash). The signer does NOT add
/// `\x19Ethereum Signed Message:\n32` prefix — that's the responsibility
/// of `Erc1271Helper` (Phase 10) when the digest comes from `personal_sign`
/// or typed-data. The 32-byte length is asserted on entry; passing a
/// 60-byte EIP-191-prefixed buffer triggers AssertionError immediately.
///
/// **Subclass contract:**
/// SUBCLASSES: override _doSign, never signDigest. The single-flight
/// invariant lives here.
///
/// **Single-flight semantics:** concurrent calls receive the same in-flight
/// `Future<EvmSignature>`. This is correct for AA — one ceremony per signer
/// per moment. If two callers pass DIFFERENT digests in parallel, the
/// second silently receives a signature for the FIRST digest. Use multiple
/// signer instances for parallel-different-digests workflows.
/// (Pitfall 7 prevention.)
///
/// **References:**
/// - PITFALLS.md Pitfall 3 (challenge contract / EIP-191 prefix ownership)
/// - PITFALLS.md Pitfall 7 (concurrent passkey ceremonies)
/// - CONTEXT.md D-18 (subclass-only-override discipline)
/// - CONTEXT.md D-19 (single-flight implementation)
/// - CONTEXT.md D-20 (no queue — fresh ceremony after completion)
/// - CONTEXT.md D-24 (no owner-address getter; signature contract only)
/// - CONTEXT.md D-34 (verbatim Pitfall 3 docstring above)
//
// `evm_signer.dart` is `part of 'evm_signature.dart';` because Dart 3
// sealed-class semantics + library-private `_doSign` require this file to
// share a library with `evm_signature.dart` and the future
// `secp256k1_signer.dart` / `passkey_signer.dart`. Imports are declared in
// the library root (`evm_signature.dart`); `part of` files cannot have
// their own imports.
part of 'evm_signature.dart';

/// Abstract template for an EVM signer producing an [EvmSignature].
///
/// (See file-level doc block above for the Pitfall 3 challenge contract
/// and the single-flight invariant.)
///
/// `EvmSigner` is a SIGNATURE contract, not an identity contract — it
/// exposes no owner-address getter (D-24). Subclasses (e.g. Plan 03's
/// `Secp256k1Signer`, Phase 11's `PasskeySigner`) override the protected
/// template method [_doSign]; the base class wraps every invocation in
/// single-flight semantics via [signDigest] for free.
///
/// SUBCLASSES: override `_doSign`, never `signDigest`. The single-flight
/// invariant lives here.
abstract class EvmSigner {
  EvmSigner();

  Future<EvmSignature>? _pending;

  /// Single-flight signing entry point. **Do not override.** Override
  /// [_doSign] in subclasses; this method enforces the single-flight
  /// invariant for every subclass for free.
  ///
  /// Concurrent callers awaiting an in-flight `signDigest` receive the
  /// SAME `EvmSignature` instance. If digests differ across concurrent
  /// callers, the second caller silently receives the first caller's
  /// result — see file-level doc block.
  Future<EvmSignature> signDigest(Uint8List digest32) {
    assert(
      digest32.length == 32,
      'digest32 must be exactly 32 bytes (got ${digest32.length}). '
      'See PITFALLS.md Pitfall 3: signDigest takes a raw 32-byte EVM '
      'digest; do NOT prepend `\\x19Ethereum Signed Message:\\n32`.',
    );
    final inflight = _pending;
    if (inflight != null) return inflight;
    final fresh = _doSign(digest32).whenComplete(() => _pending = null);
    _pending = fresh;
    return fresh;
  }

  /// Subclasses override this template method. The base class wraps every
  /// invocation in single-flight semantics via [signDigest]. Subclasses
  /// MUST NOT override [signDigest].
  @protected
  Future<EvmSignature> _doSign(Uint8List digest32);
}
