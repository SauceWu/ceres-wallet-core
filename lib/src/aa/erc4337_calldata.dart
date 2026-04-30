/// ABI calldata encoders for ERC-4337 smart-account `execute` / `executeBatch`
/// calls.
///
/// AA-06: Provides `Erc4337Calldata.executeCall` / `.executeBatch` static
/// encoders + centrally-managed selector constants. The selector for each
/// function is derived by constructing an empty `TWEthereumAbiFunction` with
/// the exact Solidity signature string and comparing the first 4 bytes of the
/// encoded output against the keccak256-derived expected value — verified at
/// runtime in tests.
///
/// **Cleanup discipline (Phase 6 D-06):** every call site wraps
/// `TWEthereumAbiFunction` usage in `try { ... } finally { fn.delete(); }` to
/// guarantee deterministic native-handle release regardless of exceptions.
///
/// Pure Dart composition layer; no new FFI bindings. Reuses
/// `TWEthereumAbiFunction` + `TWEthereumAbi` from `lib/src/tw_ethereum_abi.dart`.
library;

import 'dart:typed_data';

import '../tw_ethereum_abi.dart';

/// Static calldata encoders for ERC-4337 smart-account execute calls.
///
/// Both methods return the complete ABI-encoded calldata (4-byte selector +
/// ABI-encoded parameters). Selector constants are private to this file.
///
/// Downstream consumers (Phase 12 `Erc4337Builder`) compose these encoders
/// into `callData` fields of `UserOperation` / `UserOperationV0_7` protos.
class Erc4337Calldata {
  Erc4337Calldata._();

  // ── Private Solidity function signatures ────────────────────────────────
  // These are the canonical ABI strings whose keccak256[:4] values define
  // the on-chain selectors. Private: consumers MUST NOT hard-code these
  // strings; they must go through this class.
  static const String _executeSignature = 'execute(address,uint256,bytes)';
  static const String _executeBatchSignature =
      'executeBatch(address[],uint256[],bytes[])';

  /// Encodes a single `execute(address,uint256,bytes)` call.
  ///
  /// [target] — EIP-55 hex address string (e.g., "0xb16D...").
  /// [value] — ETH value in wei (uint256).
  /// [data] — inner calldata bytes.
  ///
  /// Returns complete ABI calldata: 4-byte selector + encoded params.
  /// The first 4 bytes equal `keccak256("[_executeSignature]")[:4]`.
  static Uint8List executeCall(
    String target,
    BigInt value,
    Uint8List data,
  ) {
    final targetBytes = _hexAddressToBytes(target);
    final valueBytes = _bigIntToUint256(value);
    final fn = TWEthereumAbiFunction.createWithString(_executeSignature);
    try {
      fn.addParamAddress(targetBytes, false);
      fn.addParamUInt256(valueBytes, false);
      fn.addParamBytes(data, false);
      return TWEthereumAbi.encode(fn);
    } finally {
      fn.delete();
    }
  }

  /// Encodes a batch `executeBatch(address[],uint256[],bytes[])` call.
  ///
  /// [targets] — list of EIP-55 hex address strings.
  /// [values] — list of ETH values in wei (uint256), one per target.
  /// [datas] — list of inner calldata bytes, one per target.
  ///
  /// Returns complete ABI calldata: 4-byte selector + encoded params.
  /// The first 4 bytes equal `keccak256("[_executeBatchSignature]")[:4]`.
  ///
  /// All three lists must have the same length; an [ArgumentError] is thrown
  /// if lengths differ.
  static Uint8List executeBatch(
    List<String> targets,
    List<BigInt> values,
    List<Uint8List> datas,
  ) {
    if (targets.length != values.length || targets.length != datas.length) {
      throw ArgumentError(
        'targets, values, and datas must all have the same length '
        '(got ${targets.length}, ${values.length}, ${datas.length})',
      );
    }
    final fn = TWEthereumAbiFunction.createWithString(_executeBatchSignature);
    try {
      // address[] array
      final targetIdx = fn.addParamArray(false);
      for (final t in targets) {
        fn.addInArrayParamAddress(targetIdx, _hexAddressToBytes(t));
      }
      // uint256[] array
      final valueIdx = fn.addParamArray(false);
      for (final v in values) {
        fn.addInArrayParamUInt256(valueIdx, _bigIntToUint256(v));
      }
      // bytes[] array
      final dataIdx = fn.addParamArray(false);
      for (final d in datas) {
        fn.addInArrayParamBytes(dataIdx, d);
      }
      return TWEthereumAbi.encode(fn);
    } finally {
      fn.delete();
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Parse a 0x-prefixed 40-hex-char Ethereum address into 20 bytes.
  ///
  /// Throws [ArgumentError] in all build modes (debug, profile, release) if:
  /// - the hex body is not exactly 40 characters, or
  /// - any character is not a valid hex digit.
  static Uint8List _hexAddressToBytes(String address) {
    var s = address;
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length != 40) {
      throw ArgumentError.value(
        address,
        'address',
        'Ethereum address must be 40 hex chars after 0x prefix (got ${s.length})',
      );
    }
    final out = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      final byte = int.tryParse(s.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid hex character at position ${i * 2}: "${s.substring(i * 2, i * 2 + 2)}"',
        );
      }
      out[i] = byte;
    }
    return out;
  }

  /// Encode a non-negative [BigInt] as a big-endian 32-byte uint256 buffer.
  ///
  /// Throws [ArgumentError] in all build modes if [v] is negative or overflows
  /// uint256. Using `assert` here is insufficient — asserts are removed in
  /// release builds, allowing negative values to silently encode as 0xFF…FF.
  static Uint8List _bigIntToUint256(BigInt v) {
    if (v < BigInt.zero) {
      throw ArgumentError.value(v, 'value', 'value must be non-negative');
    }
    final out = Uint8List(32);
    var rem = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (rem & BigInt.from(0xff)).toInt();
      rem >>= 8;
    }
    if (rem != BigInt.zero) {
      throw ArgumentError.value(v, 'value', 'value overflows uint256');
    }
    return out;
  }
}
