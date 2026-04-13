// Internal: shared native library loader and bindings singleton.
import 'dart:ffi';
import 'dart:io';

import '../bindings/ceres_wallet_core_bindings.dart';

const String _libName = 'ceres_wallet_core';

final DynamicLibrary nativeLib = () {
  if (Platform.isIOS) {
    // XCFramework embeds into Runner.app/Frameworks/ceres_wallet_core.framework
    // Try multiple candidate paths for simulator/device compatibility
    final candidates = <String>[
      'Frameworks/$_libName.framework/$_libName',
      '$_libName.framework/$_libName',
    ];
    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (_) {
        // try next
      }
    }
    return DynamicLibrary.process();
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

/// Initialize the native wallet core library.
///
/// Call this once at app startup before using any other API.
/// Throws if the native library cannot be loaded.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await CeresWalletCoreInit.initialize();
///   runApp(MyApp());
/// }
/// ```
class CeresWalletCoreInit {
  static bool _initialized = false;

  /// Initialize the native library. Safe to call multiple times.
  static Future<void> initialize() async {
    if (_initialized) return;
    // Trigger native library load — throws immediately if missing
    nativeLib;
    _initialized = true;
  }

  /// Whether the library has been initialized.
  static bool get isInitialized => _initialized;
}
