/// Session-key facet calldata encoder for Barz smart accounts.
///
/// AA-14: Provides [BarzSessionKey.installCalldata] which ABI-encodes a
/// session-key installation call for the Barz session-key facet.
///
/// **ABI assumption:**
/// The Barz session-key facet function signature used here is:
///   `addSessionKey(address,uint256,address[])`
/// (`addSessionKey(address key, uint256 validUntil, address[] allowedTargets)`)
///
/// If the deployed Barz session-key facet uses a different signature, update
/// [BarzSessionKey.functionSignature] and the selector will be recomputed
/// automatically on the next call.
library;

import 'dart:typed_data';

import '../tw_ethereum_abi.dart';

/// Static encoder for Barz session-key facet calldata.
abstract final class BarzSessionKey {
  /// The Solidity function signature used to compute the 4-byte selector.
  ///
  /// Change this constant if the deployed Barz session-key facet uses a
  /// different signature — the ABI encoding and selector are recomputed.
  static const String functionSignature =
      'addSessionKey(address,uint256,address[])';

  /// Encodes an `addSessionKey(...)` call for the Barz session-key facet.
  ///
  /// [key] — the session key address (20-byte hex string, EIP-55 format).
  /// [validUntil] — Unix timestamp after which the session key expires.
  /// [allowedTargets] — list of contract addresses the session key may call;
  ///   pass an empty list for unrestricted target access.
  ///
  /// Returns the 4-byte selector + ABI-encoded parameters, ready to be used
  /// as `callData` in a `UserOperation` targeting the Barz account.
  static Uint8List installCalldata({
    required String key,
    required BigInt validUntil,
    List<String> allowedTargets = const [],
  }) {
    assert(
      validUntil > BigInt.zero,
      'BarzSessionKey: validUntil=$validUntil means the session key expires '
      'immediately (UNIX timestamp 0 = 1970-01-01). Pass a future timestamp.',
    );
    final fn = TWEthereumAbiFunction.createWithString(functionSignature);
    try {
      // address key
      fn.addParamAddress(_hexAddressToBytes(key), false);
      // uint256 validUntil
      fn.addParamUInt256(_bigIntToUint256(validUntil), false);
      // address[] allowedTargets
      final arrayIdx = fn.addParamArray(false);
      for (final t in allowedTargets) {
        fn.addInArrayParamAddress(arrayIdx, _hexAddressToBytes(t));
      }
      return TWEthereumAbi.encode(fn);
    } finally {
      fn.delete();
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Parse a 0x-prefixed 40-hex-char Ethereum address into 20 bytes.
  static Uint8List _hexAddressToBytes(String address) {
    var s = address;
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length != 40) {
      throw ArgumentError.value(
        address,
        'address',
        'must be a 0x-prefixed 40-hex-char Ethereum address (got "$address")',
      );
    }
    final out = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      final byte = int.tryParse(s.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid hex character at position ${i * 2}',
        );
      }
      out[i] = byte;
    }
    return out;
  }

  /// Encode a non-negative [BigInt] as big-endian 32-byte uint256.
  static Uint8List _bigIntToUint256(BigInt v) {
    if (v < BigInt.zero) {
      throw RangeError.value(v.toInt(), 'validUntil', 'must be non-negative');
    }
    final out = Uint8List(32);
    var rem = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (rem & BigInt.from(0xff)).toInt();
      rem >>= 8;
    }
    return out;
  }
}
