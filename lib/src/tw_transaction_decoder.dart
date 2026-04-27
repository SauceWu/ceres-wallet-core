import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// Static utility class for decoding raw encoded transactions.
class TWTransactionDecoder {
  TWTransactionDecoder._();

  /// Decode a binary-encoded transaction into a chain-specific protobuf message.
  /// [coin] Target coin type.
  /// [encodedTx] Raw encoded transaction bytes.
  /// Returns serialized chain-specific decoded transaction protobuf bytes.
  static Uint8List decode(raw.TWCoinType coin, Uint8List encodedTx) {
    final twInput = toTWData1(encodedTx);
    try {
      final result = lib.TWTransactionDecoderDecode(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }
}
