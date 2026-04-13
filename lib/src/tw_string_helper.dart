import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../bindings/ceres_wallet_core_bindings.dart';
import 'native.dart';

/// Create a TWString from Dart String. Caller must call [deleteTWString].
Pointer<TWString> toTWString(String value) {
  final utf8 = value.toNativeUtf8();
  final ptr = lib.TWStringCreateWithUTF8Bytes(utf8.cast<Char>());
  calloc.free(utf8);
  return ptr;
}

/// Read a TWString into Dart String, then delete it.
String fromTWString(Pointer<TWString> ptr) {
  if (ptr == nullptr) return '';
  final cStr = lib.TWStringUTF8Bytes(ptr);
  final result = cStr.cast<Utf8>().toDartString();
  lib.TWStringDelete(ptr);
  return result;
}

/// Read a TWString into Dart String WITHOUT deleting it.
String peekTWString(Pointer<TWString> ptr) {
  if (ptr == nullptr) return '';
  final cStr = lib.TWStringUTF8Bytes(ptr);
  return cStr.cast<Utf8>().toDartString();
}

/// Delete a TWString if non-null.
void deleteTWString(Pointer<TWString> ptr) {
  if (ptr != nullptr) {
    lib.TWStringDelete(ptr);
  }
}
