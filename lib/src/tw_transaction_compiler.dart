import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import '../bindings/ceres_wallet_core_bindings.dart';
import 'native.dart';
import 'tw_data_helper.dart';

/// Static utility class for compiling transactions from external signatures.
class TWTransactionCompiler {
  TWTransactionCompiler._();

  /// Obtains pre-signing hashes of a transaction.
  /// [coin] Target coin type.
  /// [txInputData] Serialized SigningInput protobuf bytes.
  /// Returns serialized `PreSigningOutput` protobuf bytes.
  static Uint8List preImageHashes(raw.TWCoinType coin, Uint8List txInputData) {
    final twInput = toTWData1(txInputData);
    try {
      final result = lib.TWTransactionCompilerPreImageHashes(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Compiles a complete transaction from external signatures and public keys.
  /// [coin] Target coin type.
  /// [txInputData] Serialized SigningInput protobuf bytes.
  /// [signatures] Signatures matching the order of pre-image hashes.
  /// [publicKeys] Public keys for matching signers.
  /// Returns serialized `SigningOutput` protobuf bytes.
  static Uint8List compileWithSignatures(
    raw.TWCoinType coin,
    Uint8List txInputData,
    List<Uint8List> signatures,
    List<Uint8List> publicKeys,
  ) {
    final twInput = toTWData1(txInputData);
    final sigVec = _buildDataVector(signatures);
    final pubKeyVec = _buildDataVector(publicKeys);
    try {
      final result = lib.TWTransactionCompilerCompileWithSignatures(
        coin,
        twInput,
        sigVec,
        pubKeyVec,
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
      lib.TWDataVectorDelete(sigVec);
      lib.TWDataVectorDelete(pubKeyVec);
    }
  }

  /// Compiles a complete transaction with an explicit public key type.
  /// [coin] Target coin type.
  /// [txInputData] Serialized SigningInput protobuf bytes.
  /// [signatures] Signatures matching pre-image hash order.
  /// [publicKeys] Public keys for matching signers.
  /// [pubKeyType] Public key type used for the signers.
  /// Returns serialized `SigningOutput` protobuf bytes.
  static Uint8List compileWithSignaturesAndPubKeyType(
    raw.TWCoinType coin,
    Uint8List txInputData,
    List<Uint8List> signatures,
    List<Uint8List> publicKeys,
    raw.TWPublicKeyType pubKeyType,
  ) {
    final twInput = toTWData1(txInputData);
    final sigVec = _buildDataVector(signatures);
    final pubKeyVec = _buildDataVector(publicKeys);
    try {
      final result = lib.TWTransactionCompilerCompileWithSignaturesAndPubKeyType(
        coin,
        twInput,
        sigVec,
        pubKeyVec,
        pubKeyType,
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
      lib.TWDataVectorDelete(sigVec);
      lib.TWDataVectorDelete(pubKeyVec);
    }
  }

  /// Build a TWDataVector from a list of byte arrays.
  /// Caller must release with `lib.TWDataVectorDelete`.
  static Pointer<TWDataVector> _buildDataVector(List<Uint8List> items) {
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
