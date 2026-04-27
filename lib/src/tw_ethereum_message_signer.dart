import 'native.dart';
import 'tw_private_key.dart';
import 'tw_public_key.dart';
import 'tw_string_helper.dart';

/// Static wrapper around Trust Wallet Core's `TWEthereumMessageSigner`.
///
/// Use this for `personal_sign`, EIP-155 replay-protected signatures, EIP-712
/// typed-data signing, and recovery verification. These entry points are
/// dedicated message signers — do NOT use `TWAnySigner.sign` for messages,
/// since it only consumes a transaction `SigningInput` and silently returns
/// an empty payload when fed a `MessageSigningInput` (the common cause of
/// `0x` signatures from `personal_sign`).
class TWEthereumMessageSigner {
  TWEthereumMessageSigner._();

  /// Legacy `personal_sign` (EIP-191) without chain-id replay protection.
  /// Returns a hex-encoded 65-byte signature, or empty string on failure.
  static String signMessage(TWPrivateKey privateKey, String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWEthereumMessageSignerSignMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// `personal_sign` with EIP-155 replay protection — the `v` byte encodes
  /// `chainId`. This is the call most wallets need for `eth_sign` /
  /// `personal_sign` over an EVM L1/L2.
  static String signMessageEip155(
    TWPrivateKey privateKey,
    String message,
    int chainId,
  ) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWEthereumMessageSignerSignMessageEip155(
        privateKey.pointer,
        twMsg,
        chainId,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Sign an Immutable X message (StarkEx-flavoured personal_sign).
  static String signMessageImmutableX(TWPrivateKey privateKey, String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWEthereumMessageSignerSignMessageImmutableX(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// EIP-712 v4 typed-data signing. [messageJson] is the full JSON typed-data
  /// payload (with `domain`, `types`, `primaryType`, `message`).
  static String signTypedMessage(
    TWPrivateKey privateKey,
    String messageJson,
  ) {
    final twMsg = toTWString(messageJson);
    try {
      final result = lib.TWEthereumMessageSignerSignTypedMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// EIP-712 v4 typed-data with EIP-155 replay protection.
  /// On invalid input the returned string may carry an error message instead
  /// of a signature — callers should validate length before using.
  static String signTypedMessageEip155(
    TWPrivateKey privateKey,
    String messageJson,
    int chainId,
  ) {
    final twMsg = toTWString(messageJson);
    try {
      final result = lib.TWEthereumMessageSignerSignTypedMessageEip155(
        privateKey.pointer,
        twMsg,
        chainId,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Recover and compare against [publicKey]. [signature] must be hex-encoded.
  static bool verifyMessage(
    TWPublicKey publicKey,
    String message,
    String signature,
  ) {
    final twMsg = toTWString(message);
    final twSig = toTWString(signature);
    try {
      return lib.TWEthereumMessageSignerVerifyMessage(
        publicKey.pointer,
        twMsg,
        twSig,
      );
    } finally {
      deleteTWString(twMsg);
      deleteTWString(twSig);
    }
  }
}
