import 'dart:typed_data';

import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_public_key.dart';

/// Helpers for **WebAuthn / passkey-based wallet authentication**.
///
/// Typical passkey-wallet flow:
///
/// 1. **Register** — the device produces an `AuthenticatorAttestationResponse`.
///    Call [getPublicKey] on the raw `attestationObject` (CBOR bytes) to
///    extract the P-256 public key. Store the public key + credential id.
/// 2. **Sign** — the device produces an `AuthenticatorAssertionResponse`
///    with `signature`, `authenticatorData`, and `clientDataJSON`.
/// 3. **Recover the signed payload** — call [reconstructOriginalMessage]
///    with `authenticatorData` and `clientDataJSON`. The returned bytes are
///    what the authenticator actually signed (already SHA-256 hashed by
///    WebAuthn semantics — pass directly to [TWPublicKey.verify]).
/// 4. **Unpack the signature** — call [getRSValues] on the ASN.1 / DER
///    signature to obtain the canonical 64-byte `r ‖ s` pair, suitable for
///    on-chain verifiers (e.g. ERC-4337 + Barz, EIP-7212 P-256 precompile).
///
/// Underlying curve is **NIST P-256 (`secp256r1`)** — use
/// `TWPublicKey.fromPointer(...)` returned by [getPublicKey], or build one
/// from raw bytes via `TWPublicKey(data, TWPublicKeyType.TWPublicKeyTypeNIST256p1)`.
class TWWebAuthn {
  TWWebAuthn._();

  /// Extract the P-256 public key from a WebAuthn registration
  /// `attestationObject` (CBOR-encoded bytes from `navigator.credentials.create`).
  ///
  /// Returns `null` if the attestation can't be parsed or doesn't contain
  /// a P-256 credential public key.
  static TWPublicKey? getPublicKey(Uint8List attestationObject) {
    final twData = toTWData(attestationObject);
    try {
      final ptr = lib.TWWebAuthnGetPublicKey(twData);
      if (ptr.address == 0) return null;
      return TWPublicKey.fromPointer(ptr);
    } finally {
      deleteTWData(twData);
    }
  }

  /// Extract the canonical `r ‖ s` (64 bytes total) from an ASN.1 / DER
  /// WebAuthn signature.
  ///
  /// Spec: <https://www.w3.org/TR/webauthn-2/#sctn-signature-attestation-types>
  ///
  /// Returns an empty list on parse failure.
  static Uint8List getRSValues(Uint8List derSignature) {
    final twSig = toTWData(derSignature);
    try {
      final result = lib.TWWebAuthnGetRSValues(twSig);
      return fromTWData(result);
    } finally {
      deleteTWData(twSig);
    }
  }

  /// Reconstruct the bytes the authenticator actually signed:
  /// `authenticatorData ‖ SHA-256(clientDataJSON)`.
  ///
  /// Feed the result to a P-256 verifier (`TWPublicKey.verify(signatureRS,
  /// reconstructed)`, an EIP-7212 precompile, or an ERC-4337 / Barz
  /// validation flow).
  ///
  /// Returns an empty list on invalid input.
  static Uint8List reconstructOriginalMessage(
    Uint8List authenticatorData,
    Uint8List clientDataJSON,
  ) {
    final twAuth = toTWData(authenticatorData);
    final twClient = toTWData(clientDataJSON);
    try {
      final result = lib.TWWebAuthnReconstructOriginalMessage(
        twAuth,
        twClient,
      );
      return fromTWData(result);
    } finally {
      deleteTWData(twAuth);
      deleteTWData(twClient);
    }
  }
}
