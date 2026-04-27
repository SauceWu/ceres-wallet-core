import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';

/// Cast a TWString pointer to a TWString1 pointer (same underlying type).
Pointer<raw.TWString1> _castToTWString1(Pointer<raw.TWString> ptr) =>
    Pointer<raw.TWString1>.fromAddress(ptr.address);

/// Cast a TWString1 pointer to a TWString pointer (same underlying type).
Pointer<raw.TWString> _castFromTWString1(Pointer<raw.TWString1> ptr) =>
    Pointer<raw.TWString>.fromAddress(ptr.address);

final _abiFunctionFinalizer =
    Finalizer<Pointer<raw.TWEthereumAbiFunction>>((ptr) {
  lib.TWEthereumAbiFunctionDelete(ptr);
});

/// High-level static wrapper for Trust Wallet Core's `TWEthereumAbi*`
/// top-level codec / decoder C API. This mirrors the Solidity ABI
/// codec functions used to encode and decode Ethereum contract calls.
class TWEthereumAbi {
  TWEthereumAbi._();

  /// Encode a function call into ABI binary form.
  static Uint8List encode(TWEthereumAbiFunction fn) {
    final result = lib.TWEthereumAbiEncode(fn.pointer);
    return fromTWData1(result);
  }

  /// Decode function output, filling output parameters of [fn].
  /// Returns true on success.
  static bool decodeOutput(TWEthereumAbiFunction fn, Uint8List encoded) {
    final twEncoded = toTWData1(encoded);
    try {
      return lib.TWEthereumAbiDecodeOutput(fn.pointer, twEncoded);
    } finally {
      deleteTWData(castTWData1(twEncoded));
    }
  }

  /// Decode function call data to human-readable JSON, given an ABI JSON.
  /// Returns the JSON string, or empty on failure.
  static String decodeCall(Uint8List call, String abiJson) {
    final twCall = toTWData1(call);
    final twAbi = toTWString(abiJson);
    try {
      final result = lib.TWEthereumAbiDecodeCall(twCall, twAbi);
      return fromTWString(result);
    } finally {
      deleteTWData(castTWData1(twCall));
      deleteTWString(twAbi);
    }
  }

  /// Decode a contract call, returning serialized
  /// `TW.EthereumAbi.Proto.ContractCallDecodingOutput` proto bytes.
  static Uint8List decodeContractCall(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumAbiDecodeContractCall(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Decode a function input or output proto blob according to a given ABI.
  /// Returns serialized `TW.EthereumAbi.Proto.ParamsDecodingOutput` proto bytes.
  static Uint8List decodeParams(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumAbiDecodeParams(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Decode an Eth ABI value proto blob according to a given type.
  /// Returns serialized `TW.EthereumAbi.Proto.ValueDecodingOutput` proto bytes.
  static Uint8List decodeValue(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumAbiDecodeValue(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Encode an Ethereum ABI function call from a serialized
  /// `TW.EthereumAbi.Proto.FunctionEncodingInput` proto blob.
  /// Returns serialized `TW.EthereumAbi.Proto.FunctionEncodingOutput`.
  static Uint8List encodeFunction(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumAbiEncodeFunction(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Hash an EIP-712 typed message JSON. Returns the encoded hash bytes
  /// (empty on error).
  static Uint8List encodeTyped(String messageJson) {
    final twJson = toTWString(messageJson);
    try {
      final result = lib.TWEthereumAbiEncodeTyped(twJson);
      return fromTWData1(result);
    } finally {
      deleteTWString(twJson);
    }
  }

  /// Get the function signature (e.g. `"baz(int32,uint256)"`) from an ABI JSON.
  static String getFunctionSignature(String abiJson) {
    final twAbi = toTWString(abiJson);
    try {
      final result = lib.TWEthereumAbiGetFunctionSignature(twAbi);
      return fromTWString(result);
    } finally {
      deleteTWString(twAbi);
    }
  }
}

/// Builder/value wrapper around a native `TWEthereumAbiFunction`.
///
/// Owns the underlying pointer and frees it via [Finalizer]; call [delete]
/// for deterministic cleanup.
class TWEthereumAbiFunction {
  Pointer<raw.TWEthereumAbiFunction>? _ptr;

  TWEthereumAbiFunction._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _abiFunctionFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a function builder with the given function name.
  /// Throws [ArgumentError] on invalid input.
  factory TWEthereumAbiFunction.createWithString(String name) {
    final twName = toTWString(name);
    try {
      final ptr =
          lib.TWEthereumAbiFunctionCreateWithString(_castToTWString1(twName));
      if (ptr == nullptr) {
        throw ArgumentError('Invalid Ethereum ABI function name: $name');
      }
      return TWEthereumAbiFunction._wrap(ptr);
    } finally {
      deleteTWString(twName);
    }
  }

  /// Native pointer.
  Pointer<raw.TWEthereumAbiFunction> get pointer => _ptr!;

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _abiFunctionFinalizer.detach(this);
      lib.TWEthereumAbiFunctionDelete(_ptr!);
      _ptr = null;
    }
  }

  /// Get the function type signature, e.g. `"baz(int32,uint256)"`.
  String getType() {
    final result = lib.TWEthereumAbiFunctionGetType(_ptr!);
    return fromTWString(_castFromTWString1(result));
  }

  // ---------------- addParam* (top-level params) ----------------

  /// Add an `address` parameter; returns its 0-based index.
  int addParamAddress(Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamAddress(_ptr!, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `uint8` parameter.
  int addParamUInt8(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamUInt8(_ptr!, val, isOutput);

  /// Add a `uint16` parameter.
  int addParamUInt16(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamUInt16(_ptr!, val, isOutput);

  /// Add a `uint32` parameter.
  int addParamUInt32(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamUInt32(_ptr!, val, isOutput);

  /// Add a `uint64` parameter.
  int addParamUInt64(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamUInt64(_ptr!, val, isOutput);

  /// Add a `uint256` parameter (value is big-endian byte data).
  int addParamUInt256(Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamUInt256(_ptr!, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `uint(bits)` parameter.
  int addParamUIntN(int bits, Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamUIntN(
          _ptr!, bits, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add an `int8` parameter.
  int addParamInt8(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamInt8(_ptr!, val, isOutput);

  /// Add an `int16` parameter.
  int addParamInt16(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamInt16(_ptr!, val, isOutput);

  /// Add an `int32` parameter.
  int addParamInt32(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamInt32(_ptr!, val, isOutput);

  /// Add an `int64` parameter.
  int addParamInt64(int val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamInt64(_ptr!, val, isOutput);

  /// Add an `int256` parameter (value is big-endian byte data).
  int addParamInt256(Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamInt256(_ptr!, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add an `int(bits)` parameter.
  int addParamIntN(int bits, Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamIntN(
          _ptr!, bits, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `bool` parameter.
  int addParamBool(bool val, bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamBool(_ptr!, val, isOutput);

  /// Add a `string` parameter.
  int addParamString(String val, bool isOutput) {
    final twVal = toTWString(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamString(
          _ptr!, _castToTWString1(twVal), isOutput);
    } finally {
      deleteTWString(twVal);
    }
  }

  /// Add a `bytes` parameter.
  int addParamBytes(Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamBytes(_ptr!, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a fixed-size `bytes[N]` parameter of [size] bytes.
  int addParamBytesFix(int size, Uint8List val, bool isOutput) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddParamBytesFix(
          _ptr!, size, twVal, isOutput);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `type[]` (dynamic array) parameter; the inner type is filled by
  /// subsequent `addInArrayParam*` calls. Returns the array's index.
  int addParamArray(bool isOutput) =>
      lib.TWEthereumAbiFunctionAddParamArray(_ptr!, isOutput);

  // ---------------- addInArrayParam* (array element params) ----------------

  /// Add an `address` element to the array at [arrayIdx].
  int addInArrayParamAddress(int arrayIdx, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamAddress(
          _ptr!, arrayIdx, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `uint8` element.
  int addInArrayParamUInt8(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamUInt8(_ptr!, arrayIdx, val);

  /// Add a `uint16` element.
  int addInArrayParamUInt16(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamUInt16(_ptr!, arrayIdx, val);

  /// Add a `uint32` element.
  int addInArrayParamUInt32(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamUInt32(_ptr!, arrayIdx, val);

  /// Add a `uint64` element.
  int addInArrayParamUInt64(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamUInt64(_ptr!, arrayIdx, val);

  /// Add a `uint256` element.
  int addInArrayParamUInt256(int arrayIdx, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamUInt256(
          _ptr!, arrayIdx, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `uint(bits)` element.
  int addInArrayParamUIntN(int arrayIdx, int bits, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamUIntN(
          _ptr!, arrayIdx, bits, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add an `int8` element.
  int addInArrayParamInt8(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamInt8(_ptr!, arrayIdx, val);

  /// Add an `int16` element.
  int addInArrayParamInt16(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamInt16(_ptr!, arrayIdx, val);

  /// Add an `int32` element.
  int addInArrayParamInt32(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamInt32(_ptr!, arrayIdx, val);

  /// Add an `int64` element.
  int addInArrayParamInt64(int arrayIdx, int val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamInt64(_ptr!, arrayIdx, val);

  /// Add an `int256` element.
  int addInArrayParamInt256(int arrayIdx, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamInt256(
          _ptr!, arrayIdx, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add an `int(bits)` element.
  int addInArrayParamIntN(int arrayIdx, int bits, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamIntN(
          _ptr!, arrayIdx, bits, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a `bool` element.
  int addInArrayParamBool(int arrayIdx, bool val) =>
      lib.TWEthereumAbiFunctionAddInArrayParamBool(_ptr!, arrayIdx, val);

  /// Add a `string` element.
  int addInArrayParamString(int arrayIdx, String val) {
    final twVal = toTWString(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamString(
          _ptr!, arrayIdx, _castToTWString1(twVal));
    } finally {
      deleteTWString(twVal);
    }
  }

  /// Add a `bytes` element.
  int addInArrayParamBytes(int arrayIdx, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamBytes(
          _ptr!, arrayIdx, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  /// Add a fixed-size `bytes[N]` element of [size] bytes.
  int addInArrayParamBytesFix(int arrayIdx, int size, Uint8List val) {
    final twVal = toTWData(val);
    try {
      return lib.TWEthereumAbiFunctionAddInArrayParamBytesFix(
          _ptr!, arrayIdx, size, twVal);
    } finally {
      deleteTWData(twVal);
    }
  }

  // ---------------- getParam* ----------------

  /// Get an `address` parameter at [idx]. Returns the raw 20-byte address.
  Uint8List getParamAddress(int idx, bool isOutput) {
    final result =
        lib.TWEthereumAbiFunctionGetParamAddress(_ptr!, idx, isOutput);
    return fromTWData(result);
  }

  /// Get a `uint8` parameter at [idx].
  int getParamUInt8(int idx, bool isOutput) =>
      lib.TWEthereumAbiFunctionGetParamUInt8(_ptr!, idx, isOutput);

  /// Get a `uint64` parameter at [idx].
  int getParamUInt64(int idx, bool isOutput) =>
      lib.TWEthereumAbiFunctionGetParamUInt64(_ptr!, idx, isOutput);

  /// Get a `uint256` parameter at [idx] as big-endian bytes.
  Uint8List getParamUInt256(int idx, bool isOutput) {
    final result =
        lib.TWEthereumAbiFunctionGetParamUInt256(_ptr!, idx, isOutput);
    return fromTWData(result);
  }

  /// Get a `bool` parameter at [idx].
  bool getParamBool(int idx, bool isOutput) =>
      lib.TWEthereumAbiFunctionGetParamBool(_ptr!, idx, isOutput);

  /// Get a `string` parameter at [idx].
  String getParamString(int idx, bool isOutput) {
    final result =
        lib.TWEthereumAbiFunctionGetParamString(_ptr!, idx, isOutput);
    return fromTWString(_castFromTWString1(result));
  }
}

/// Static helpers for encoding / decoding individual ABI primitive values.
class TWEthereumAbiValue {
  TWEthereumAbiValue._();

  /// Encode a bool to 32 bytes.
  static Uint8List encodeBool(bool value) {
    final result = lib.TWEthereumAbiValueEncodeBool(value);
    return fromTWData1(result);
  }

  /// Encode up to 32 bytes (right-padded). Longer arrays are truncated.
  static Uint8List encodeBytes(Uint8List value) {
    final twVal = toTWData1(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeBytes(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twVal));
    }
  }

  /// Encode a dynamic-length byte array by hashing.
  static Uint8List encodeBytesDyn(Uint8List value) {
    final twVal = toTWData1(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeBytesDyn(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twVal));
    }
  }

  /// Encode a 20-byte address into 32 bytes.
  static Uint8List encodeAddress(Uint8List value) {
    final twVal = toTWData1(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeAddress(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twVal));
    }
  }

  /// Encode a string by hashing.
  static Uint8List encodeString(String value) {
    final twVal = toTWString(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeString(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWString(twVal);
    }
  }

  /// Encode a uint32 into 32 bytes.
  static Uint8List encodeUInt32(int value) {
    final result = lib.TWEthereumAbiValueEncodeUInt32(value);
    return fromTWData1(result);
  }

  /// Encode a uint256 (big-endian bytes) into 32 bytes.
  static Uint8List encodeUInt256(Uint8List value) {
    final twVal = toTWData1(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeUInt256(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twVal));
    }
  }

  /// Encode an int32 into 32 bytes.
  static Uint8List encodeInt32(int value) {
    final result = lib.TWEthereumAbiValueEncodeInt32(value);
    return fromTWData1(result);
  }

  /// Encode an int256 (big-endian bytes) into 32 bytes.
  static Uint8List encodeInt256(Uint8List value) {
    final twVal = toTWData1(value);
    try {
      final result = lib.TWEthereumAbiValueEncodeInt256(twVal);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twVal));
    }
  }

  /// Decode a uint256 (input longer than 32 bytes is truncated).
  /// Returns the decimal string representation.
  static String decodeUInt256(Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumAbiValueDecodeUInt256(twInput);
      return fromTWString(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Decode an arbitrary type, returning the value as a string.
  static String decodeValue(Uint8List input, String type) {
    final twInput = toTWData1(input);
    final twType = toTWString(type);
    try {
      final result = lib.TWEthereumAbiValueDecodeValue(twInput, twType);
      return fromTWString(result);
    } finally {
      deleteTWData(castTWData1(twInput));
      deleteTWString(twType);
    }
  }

  /// Decode an array of given simple types. Returns a `\n`-separated string.
  static String decodeArray(Uint8List input, String type) {
    final twInput = toTWData1(input);
    final twType = toTWString(type);
    try {
      final result = lib.TWEthereumAbiValueDecodeArray(twInput, twType);
      return fromTWString(result);
    } finally {
      deleteTWData(castTWData1(twInput));
      deleteTWString(twType);
    }
  }
}
