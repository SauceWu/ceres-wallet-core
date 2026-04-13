import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../bindings/ceres_wallet_core_bindings.dart';
import 'native.dart';

/// Create a TWData from Uint8List. Caller must call [deleteTWData].
Pointer<TWData> toTWData(Uint8List bytes) {
  final ptr = calloc<Uint8>(bytes.length);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  final result = lib.TWDataCreateWithBytes(ptr, bytes.length);
  calloc.free(ptr);
  return result;
}

/// Read a TWData into Uint8List, then delete it.
/// Works with both TWData and TWData1 (same native type, aliased by ffigen).
Uint8List fromTWData(Pointer<TWData> ptr) {
  if (ptr == nullptr) return Uint8List(0);
  final size = lib.TWDataSize(ptr);
  if (size == 0) {
    lib.TWDataDelete(ptr);
    return Uint8List(0);
  }
  final bytesPtr = lib.TWDataBytes(ptr);
  final result = Uint8List.fromList(bytesPtr.asTypedList(size));
  lib.TWDataDelete(ptr);
  return result;
}

/// Cast TWData1 pointer to TWData pointer (same underlying type).
Pointer<TWData> castTWData1(Pointer<TWData1> ptr) {
  return Pointer<TWData>.fromAddress(ptr.address);
}

/// Cast TWData pointer to TWData1 pointer (same underlying type).
Pointer<TWData1> castToTWData1(Pointer<TWData> ptr) {
  return Pointer<TWData1>.fromAddress(ptr.address);
}

/// Read a TWData1 into Uint8List, then delete it.
Uint8List fromTWData1(Pointer<TWData1> ptr) {
  return fromTWData(castTWData1(ptr));
}

/// Create a TWData1 from Uint8List.
Pointer<TWData1> toTWData1(Uint8List bytes) {
  return castToTWData1(toTWData(bytes));
}

/// Delete a TWData if non-null.
void deleteTWData(Pointer<TWData> ptr) {
  if (ptr != nullptr) {
    lib.TWDataDelete(ptr);
  }
}
