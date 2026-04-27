import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// Static wrapper around Trust Wallet Core's generic `TWMessageSigner`.
///
/// Proto-based, multi-chain dispatcher. Each chain that supports off-chain
/// message signing exposes a `MessageSigningInput` proto (e.g.
/// `TW.Ethereum.Proto.MessageSigningInput`,
/// `TW.Solana.Proto.MessageSigningInput`). Pass the serialized proto bytes
/// here together with the matching [TWCoinType].
///
/// Note: `TWAnySigner.sign` is for transactions only — it does NOT understand
/// `MessageSigningInput` and will silently return empty bytes. Use this class
/// for off-chain message signing, or use the chain-specific helpers (e.g.
/// `TWEthereumMessageSigner`) for direct hex-string APIs.
class TWMessageSigner {
  TWMessageSigner._();

  /// Sign a message described by a serialized chain-specific
  /// `MessageSigningInput` proto.
  ///
  /// Returns the serialized `MessageSigningOutput` proto bytes (chain-specific).
  /// Callers should deserialize into the chain's `MessageSigningOutput` and
  /// inspect the `error` / `signature` fields.
  static Uint8List sign(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWMessageSignerSign(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Compute the pre-image hashes for a chain-specific `MessageSigningInput`.
  /// Useful when signing is performed by an external signer (HSM, hardware
  /// wallet, MPC) — feed the resulting hash to the signer, then recombine via
  /// `TWTransactionCompiler.compileWithSignatures`.
  static Uint8List preImageHashes(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWMessageSignerPreImageHashes(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Verify a signature using a serialized chain-specific
  /// `MessageVerifyingInput` proto. Returns `false` on any invalid input
  /// (does not throw).
  static bool verify(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      return lib.TWMessageSignerVerify(coin, twInput);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }
}
