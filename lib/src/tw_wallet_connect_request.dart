import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';

/// Static utility class for parsing WalletConnect requests.
class TWWalletConnectRequest {
  TWWalletConnectRequest._();

  /// Parse a WalletConnect request into a chain-specific signing payload.
  /// [coin] Target coin type.
  /// [input] Serialized `WalletConnect::Proto::ParseRequestInput` bytes.
  /// Returns serialized `ParseRequestOutput` protobuf bytes.
  static Uint8List parse(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWWalletConnectRequestParse(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }
}
