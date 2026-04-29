/// Forward-declared `PasskeySignature` placeholder for the AA sealed union.
///
/// Decisions: D-16 (Phase 7 ships only the `fromBarzFormatted` constructor;
/// no public 64-byte raw `r‖s` ctor), D-31 (file lives at
/// `lib/src/aa/passkey_signature.dart`; Phase 11 grows it independently
/// without touching the union root), D-33 (no `TW` prefix on AA-namespace
/// class names — pure-Dart composition layer).
///
/// Phase 7 ships ONLY [PasskeySignature.fromBarzFormatted]. Phase 11 will add a
/// private `_fromAssertion` factory whose only call site is
/// `PasskeySigner._doSign`. There is NO public 64-byte constructor — feeding
/// raw `r‖s` into a passkey path is a compile error.
///
/// This shape is the load-bearing prevention site for PITFALLS.md
/// Pitfall 1: by refusing to accept a 64-byte buffer at construction, the
/// type system forbids the most common AA mistake (returning raw r‖s where
/// Barz expects an ABI-encoded `(authenticatorData, clientDataJSON, r, s)`
/// blob ~290 bytes long).
// `passkey_signature.dart` is a `part` of `evm_signature.dart`'s library
// because Dart 3 sealed-class semantics require every direct subtype of
// `EvmSignature` to live in the SAME library as the sealed base. The
// per-file separation is preserved so Plan 11 can grow this file
// (adding a private `_fromAssertion` factory) without touching the
// union root. Plan 02 will reshape into a named-library / part-of-name
// structure when `evm_signer.dart` joins.
part of 'evm_signature.dart';

/// Forward-declared placeholder for the WebAuthn / Barz-formatted signature.
/// Phase 7 ships only the fully-formatted-blob constructor. Phase 11 grows
/// the file with a private `_fromAssertion` factory.
final class PasskeySignature extends EvmSignature {
  PasskeySignature._(this.formattedBlob);

  /// Wrap a Barz-formatted signature blob. Typical Barz envelope is
  /// ~290 bytes (auth data + clientDataJSON + r + s + ABI overhead).
  /// The 200-byte minimum hard-rejects the 64-byte `r‖s` mistake at
  /// construction time (PITFALLS.md Pitfall 1).
  factory PasskeySignature.fromBarzFormatted(Uint8List blob) {
    assert(
      blob.length >= 200,
      'PasskeySignature blob must be Barz-formatted (>=200 bytes); '
      'got ${blob.length}. A 64-byte r||s buffer is NOT a valid passkey '
      'signature — see PITFALLS.md Pitfall 1.',
    );
    return PasskeySignature._(Uint8List.fromList(blob));
  }

  final Uint8List formattedBlob;
}
