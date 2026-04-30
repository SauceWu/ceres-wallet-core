/// Concrete [EvmSigner] for P-256 / WebAuthn passkey flows.
///
/// AA-03: Composes [EvmSigner] onto a caller-injected platform passkey
/// adapter, enforcing the ~290-byte Barz-formatted signature contract.
///
/// **Adapter injection (Pitfall 1 prevention):**
/// The SDK does NOT depend on any platform passkey plugin. Instead,
/// [PasskeySigner] accepts a caller-supplied
/// `Future<PasskeyAssertion> Function(Uint8List challenge)` adapter that
/// bridges whatever platform API the host app uses. This keeps the SDK
/// platform-agnostic while enforcing the [PasskeyAssertion] value type as
/// the sole entry point — raw `r‖s` bytes cannot be passed here.
///
/// **Signature length assertion (Pitfall 1 prevention):**
/// Every `_doSign` call passes the assertion through
/// `TWBarz.getFormattedSignature` and asserts the result is ≥ 200 bytes.
/// The 64-byte raw `r‖s` path is impossible to reach — the
/// [PasskeySignature.fromBarzFormatted] factory enforces this invariant
/// with a compile-time-visible assertion.
///
/// **Single-flight semantics (Pitfall 7 prevention):**
/// Inherited from [EvmSigner]: concurrent `signDigest` calls coalesce
/// into a single in-flight passkey ceremony. A second caller that arrives
/// while a ceremony is in progress receives the same [PasskeySignature]
/// produced by that ceremony, regardless of its own `digest32` argument.
/// See file-level doc block of `evm_signer.dart` for details.
///
/// D-22 keepAlive discipline: no native handles are held by this class;
/// the adapter is pure Dart. `TWBarz.getFormattedSignature` owns its
/// temporary FFI handles internally, so no `keepAlive` is needed here.
part of 'evm_signature.dart';

/// Concrete `EvmSigner` for P-256 / WebAuthn passkey flows.
///
/// The caller injects a [PasskeyAdapter] function that wraps the platform
/// passkey API. [PasskeySigner] passes the raw 32-byte `digest32` as the
/// challenge, invokes [TWBarz.getFormattedSignature] on the resulting
/// [PasskeyAssertion], and returns a [PasskeySignature] whose blob is
/// guaranteed to be ≥ 200 bytes.
///
/// Single-flight semantics are inherited from [EvmSigner] — override
/// [_doSign], never [signDigest].
///
/// Example:
/// ```dart
/// final signer = PasskeySigner(
///   adapter: (challenge) async {
///     final assertion = await myPlatformPasskeyApi.sign(challenge);
///     return PasskeyAssertion(
///       derSignature: assertion.signature,
///       challenge: challenge,
///       authenticatorData: assertion.authenticatorData,
///       clientDataJSON: assertion.clientDataJSON,
///     );
///   },
/// );
/// final sig = await signer.signDigest(userOpHash);
/// ```
class PasskeySigner extends EvmSigner {
  /// Constructs a [PasskeySigner] with the given platform [adapter].
  ///
  /// [adapter] is called with the raw 32-byte `digest32` as the challenge.
  /// It must return a [PasskeyAssertion] carrying the platform
  /// authenticator's DER signature, authenticator data, and client-data JSON.
  PasskeySigner({required PasskeyAdapter adapter}) : _adapter = adapter;

  final PasskeyAdapter _adapter;

  @override
  Future<EvmSignature> _doSign(Uint8List digest32) async {
    // Invoke the platform adapter with digest32 as the WebAuthn challenge.
    final assertion = await _adapter(digest32);

    // Pitfall 3 prevention (first-line defence): the adapter must embed the
    // exact digest32 bytes as the challenge inside PasskeyAssertion.challenge.
    // A buggy or hijacked adapter returning a stale / different challenge is
    // caught here in debug builds before the signature is even formatted.
    // Release builds rely on the secondary check in Erc4337Builder.attachSignature.
    assert(
      _bytesEqual(assertion.challenge, digest32),
      'PasskeyAdapter returned an assertion whose challenge does not match the '
      'digest32 that was sent (Pitfall 3). The adapter must write the challenge '
      'argument verbatim into PasskeyAssertion.challenge.',
    );

    // TWBarz.getFormattedSignature converts ASN.1-DER (r, s) + authenticator
    // data + clientDataJSON into the Barz-specific ABI-encoded blob.
    // Pitfall 1 prevention: result is asserted ≥ 200 bytes inside
    // PasskeySignature.fromBarzFormatted — the 64-byte raw r‖s path cannot
    // reach this line.
    final blob = TWBarz.getFormattedSignature(
      assertion.derSignature,
      assertion.challenge,
      assertion.authenticatorData,
      assertion.clientDataJSON,
    );
    return PasskeySignature.fromBarzFormatted(blob);
  }

  // Constant-time bytes comparison to avoid timing side-channels.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Adapter type alias: a function that accepts a 32-byte WebAuthn challenge
/// and returns a [PasskeyAssertion] from the platform authenticator.
///
/// The host app supplies this function to [PasskeySigner] so the SDK
/// stays platform-agnostic.
typedef PasskeyAdapter = Future<PasskeyAssertion> Function(
  Uint8List challenge,
);
