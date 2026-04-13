import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';

/// Static utility class for signing transactions.
class TWAnySigner {
  TWAnySigner._();

  /// Sign a transaction using protobuf-serialized input.
  /// [input] Serialized SigningInput protobuf bytes.
  /// [coin] Target coin type.
  /// Returns serialized SigningOutput protobuf bytes.
  static Uint8List sign(Uint8List input, raw.TWCoinType coin) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWAnySignerSign(twInput, coin);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Sign using JSON input.
  /// Returns JSON string output.
  static String signJSON({
    required String json,
    required Uint8List key,
    required raw.TWCoinType coin,
  }) {
    final twJson = toTWString(json);
    final twKey = toTWData(key);
    try {
      final result = lib.TWAnySignerSignJSON(twJson, twKey, coin);
      return fromTWString(result);
    } finally {
      deleteTWString(twJson);
      deleteTWData(twKey);
    }
  }

  /// Check if a coin supports JSON signing.
  static bool supportsJSON(raw.TWCoinType coin) {
    return lib.TWAnySignerSupportsJSON(coin);
  }

  /// Plan a transaction (UTXO chains).
  static Uint8List plan(Uint8List input, raw.TWCoinType coin) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWAnySignerPlan(twInput, coin);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }
}
