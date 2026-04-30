/// Value class carrying the output of a WebAuthn `navigator.credentials.get()` ceremony.
///
/// [PasskeyAssertion] colocates the three fields that `TWBarz.getFormattedSignature`
/// needs. Passing raw `r‖s` bytes where a [PasskeyAssertion] is required is a
/// compile error — enforcing Pitfall 1 prevention (raw r‖s vs Barz-formatted blob).
library;

import 'dart:typed_data';

/// Immutable value object that carries the output of one WebAuthn assertion ceremony.
///
/// All three byte-array fields are defensive-copied at construction time so
/// callers cannot mutate the assertion after the fact.
final class PasskeyAssertion {
  /// Constructs a [PasskeyAssertion].
  ///
  /// [derSignature] — ASN.1 DER-encoded `(r, s)` signature returned by the
  /// platform authenticator (typically 70–72 bytes).
  ///
  /// [challenge] — The 32-byte challenge that was signed. Must match the
  /// digest passed to `IERC1271.isValidSignature` after Barz wrapping.
  ///
  /// [authenticatorData] — Raw authenticator-data blob from the WebAuthn API
  /// (typically ≥37 bytes: rpIdHash + flags + counter).
  ///
  /// [clientDataJSON] — UTF-8 JSON string from the WebAuthn API containing
  /// the challenge, origin, and type fields.
  PasskeyAssertion({
    required Uint8List derSignature,
    required Uint8List challenge,
    required Uint8List authenticatorData,
    required this.clientDataJSON,
  })  : derSignature = Uint8List.fromList(derSignature),
        challenge = Uint8List.fromList(challenge),
        authenticatorData = Uint8List.fromList(authenticatorData) {
    assert(
      challenge.length == 32,
      'PasskeyAssertion.challenge must be exactly 32 bytes '
      '(EVM digest / keccak256 output); got ${challenge.length} bytes. '
      'Ensure the challenge is the raw 32-byte digest, not base64url-encoded.',
    );
  }

  /// ASN.1 DER-encoded `(r, s)` signature from the platform authenticator.
  final Uint8List derSignature;

  /// 32-byte challenge that was embedded in the WebAuthn ceremony.
  final Uint8List challenge;

  /// Raw authenticator-data blob from the WebAuthn API.
  final Uint8List authenticatorData;

  /// UTF-8 JSON string from the WebAuthn API.
  final String clientDataJSON;
}
