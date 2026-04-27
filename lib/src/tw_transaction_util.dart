import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_string_helper.dart';

/// Static utility class for transaction-level helpers.
class TWTransactionUtil {
  TWTransactionUtil._();

  /// Calculate the transaction hash of an encoded transaction.
  /// [coin] Target coin type.
  /// [encodedTx] Encoded transaction string (chain-specific format).
  /// Returns the hex-encoded transaction hash, or empty string if unsupported.
  static String calcTxHash(raw.TWCoinType coin, String encodedTx) {
    final twInput = toTWString(encodedTx);
    try {
      final result = lib.TWTransactionUtilCalcTxHash(coin, twInput);
      return fromTWString(result);
    } finally {
      deleteTWString(twInput);
    }
  }
}
