import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';

/// Static helpers for inspecting and modifying Base64-encoded Solana
/// transactions. All mutating methods return a new Base64-encoded
/// transaction, or an empty string on failure.
class TWSolanaTransaction {
  TWSolanaTransaction._();

  /// Returns the compute unit limit set on the transaction, or null if no
  /// `SetComputeUnitLimit` instruction is present.
  static String? getComputeUnitLimit(String encodedTx) {
    final twTx = toTWString(encodedTx);
    try {
      final result = lib.TWSolanaTransactionGetComputeUnitLimit(twTx);
      final value = fromTWString(result);
      return value.isEmpty ? null : value;
    } finally {
      deleteTWString(twTx);
    }
  }

  /// Returns the compute unit price set on the transaction, or null if no
  /// `SetComputeUnitPrice` instruction is present.
  static String? getComputeUnitPrice(String encodedTx) {
    final twTx = toTWString(encodedTx);
    try {
      final result = lib.TWSolanaTransactionGetComputeUnitPrice(twTx);
      final value = fromTWString(result);
      return value.isEmpty ? null : value;
    } finally {
      deleteTWString(twTx);
    }
  }

  /// Sets (or replaces) the `SetComputeUnitLimit` instruction. [limit] is a
  /// stringified u64.
  static String setComputeUnitLimit(String encodedTx, String limit) {
    final twTx = toTWString(encodedTx);
    final twLimit = toTWString(limit);
    try {
      final result = lib.TWSolanaTransactionSetComputeUnitLimit(twTx, twLimit);
      return fromTWString(result);
    } finally {
      deleteTWString(twTx);
      deleteTWString(twLimit);
    }
  }

  /// Sets (or replaces) the `SetComputeUnitPrice` instruction. [price] is a
  /// stringified u64.
  static String setComputeUnitPrice(String encodedTx, String price) {
    final twTx = toTWString(encodedTx);
    final twPrice = toTWString(price);
    try {
      final result = lib.TWSolanaTransactionSetComputeUnitPrice(twTx, twPrice);
      return fromTWString(result);
    } finally {
      deleteTWString(twTx);
      deleteTWString(twPrice);
    }
  }

  /// Sets the fee payer of the transaction to [feePayerBase58].
  static String setFeePayer(String encodedTx, String feePayerBase58) {
    final twTx = toTWString(encodedTx);
    final twPayer = toTWString(feePayerBase58);
    try {
      final result = lib.TWSolanaTransactionSetFeePayer(twTx, twPayer);
      return fromTWString(result);
    } finally {
      deleteTWString(twTx);
      deleteTWString(twPayer);
    }
  }

  /// Inserts [instructionJson] at position [insertAt]. Use -1 to append.
  static String insertInstruction(
    String encodedTx,
    int insertAt,
    String instructionJson,
  ) {
    final twTx = toTWString(encodedTx);
    final twInstr = toTWString(instructionJson);
    try {
      final result = lib.TWSolanaTransactionInsertInstruction(
        twTx,
        insertAt,
        twInstr,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twTx);
      deleteTWString(twInstr);
    }
  }

  /// Decodes the transaction, updates its recent blockhash, and re-signs it
  /// with [privateKeys]. Returns the serialized `Solana::Proto::SigningOutput`
  /// protobuf bytes — callers should parse it and read `encoded` for the new
  /// Base64-encoded transaction. Returns empty bytes on failure.
  static Uint8List updateBlockhashAndSign(
    String encodedTx,
    String recentBlockhash,
    List<Uint8List> privateKeys,
  ) {
    final twTx = toTWString(encodedTx);
    final twBlockhash = toTWString(recentBlockhash);
    final keysVec = _buildDataVector(privateKeys);
    try {
      final result = lib.TWSolanaTransactionUpdateBlockhashAndSign(
        twTx,
        twBlockhash,
        keysVec,
      );
      return fromTWData1(result);
    } finally {
      deleteTWString(twTx);
      deleteTWString(twBlockhash);
      lib.TWDataVectorDelete(keysVec);
    }
  }

  /// Build a TWDataVector from a list of byte arrays.
  /// Caller must release with `lib.TWDataVectorDelete`.
  static Pointer<raw.TWDataVector> _buildDataVector(List<Uint8List> items) {
    final vec = lib.TWDataVectorCreate();
    for (final item in items) {
      final twData = toTWData1(item);
      try {
        lib.TWDataVectorAdd(vec, twData);
      } finally {
        // TWDataVectorAdd copies the data, so free immediately.
        deleteTWData(castTWData1(twData));
      }
    }
    return vec;
  }
}
