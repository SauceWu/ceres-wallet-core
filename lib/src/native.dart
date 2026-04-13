// Internal: shared native library loader and bindings singleton.
import 'dart:ffi';
import 'dart:io';

import '../bindings/ceres_wallet_core_bindings.dart';

const String _libName = 'ceres_wallet_core';

final DynamicLibrary nativeLib = () {
  // When using Dart build hooks, the native library is declared as a
  // CodeAsset with id 'package:ceres_wallet_core/ceres_wallet_core.dart'.
  // Flutter/Dart automatically bundles it and makes it available via
  // DynamicLibrary.open with the standard platform naming.
  if (Platform.isIOS) {
    // Hook bundles the .framework into the app — load it by name
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('lib$_libName.dylib');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final CeresWalletCore lib = CeresWalletCore(nativeLib);
