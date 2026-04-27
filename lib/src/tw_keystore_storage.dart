import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tw_stored_key.dart';

/// Mobile / desktop platform-aware default location for [TWStoredKey] JSON
/// files plus a few convenience operations.
///
/// **iOS:** files land in `<App>/Library/Application Support/keystores/`.
/// This directory is included in iCloud / iTunes backups by default. If you
/// don't want keystores syncing to iCloud, exclude the URL via Swift:
///
/// ```swift
/// var url = URL(fileURLWithPath: path)
/// var values = URLResourceValues()
/// values.isExcludedFromBackup = true
/// try url.setResourceValues(&values)
/// ```
///
/// or place the keystore in `getApplicationCacheDirectory()` (system may
/// purge it).
///
/// **Android:** files land in `<App>/files/keystores/` (`Context.getFilesDir()`),
/// which is **app-private** and not readable by other apps. ADB backup is
/// allowed unless the manifest opts out via `android:allowBackup="false"`.
///
/// **Important — password handling:** never persist the keystore password
/// alongside the JSON. Store it via the platform secure store
/// (iOS Keychain / Android Keystore) — `flutter_secure_storage` is a common
/// option. The JSON file alone is useless without the password.
class TWKeystoreStorage {
  TWKeystoreStorage._();

  static const String _subdir = 'keystores';
  static const String _ext = '.json';

  /// Resolve (and lazily create) the default keystore directory for the
  /// current platform.
  static Future<Directory> defaultDirectory() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Default path for a keystore named [name]. Adds `.json` if missing.
  static Future<String> defaultPath(String name) async {
    final dir = await defaultDirectory();
    final fileName = name.endsWith(_ext) ? name : '$name$_ext';
    return p.join(dir.path, fileName);
  }

  /// List all keystore names in the default directory (no extension).
  static Future<List<String>> listKeystores() async {
    final dir = await defaultDirectory();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(_ext))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList(growable: false);
  }

  /// Whether a keystore with [name] exists in the default directory.
  static Future<bool> exists(String name) async {
    return File(await defaultPath(name)).existsSync();
  }

  /// Persist [key] under [name] in the default directory.
  /// Returns `true` on success.
  static Future<bool> store(TWStoredKey key, String name) async {
    final path = await defaultPath(name);
    return key.store(path);
  }

  /// Load a keystore by [name] from the default directory.
  /// Returns `null` if the file is missing or invalid JSON.
  static Future<TWStoredKey?> load(String name) async {
    final path = await defaultPath(name);
    if (!File(path).existsSync()) return null;
    return TWStoredKey.load(path);
  }

  /// Delete a keystore file by [name]. Returns `true` if the file existed
  /// and was deleted.
  static Future<bool> deleteKeystore(String name) async {
    final file = File(await defaultPath(name));
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// Convenience: take a JSON byte payload (e.g. exported from another
  /// wallet, downloaded, or shipped via deep link), parse it through
  /// [TWStoredKey.importJSON], and persist under [name].
  static Future<TWStoredKey> importAndStore(Uint8List json, String name) async {
    final key = TWStoredKey.importJSON(json);
    await store(key, name);
    return key;
  }

  /// Convenience: read a keystore [name] and return its raw JSON bytes
  /// (the bytes you'd hand to another wallet for import). Returns `null`
  /// if the file is missing.
  static Future<Uint8List?> exportJSON(String name) async {
    final file = File(await defaultPath(name));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Convert a string password to the byte buffer the [TWStoredKey] API
  /// expects. Always UTF-8.
  static Uint8List passwordToBytes(String password) =>
      Uint8List.fromList(utf8.encode(password));

  static Future<Directory> _baseDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS / macOS — Application Support, sandboxed, survives app updates,
      // not visible via Files.app.
      return getApplicationSupportDirectory();
    }
    if (Platform.isAndroid) {
      // Android — internal files dir (Context.getFilesDir()), app-private.
      return getApplicationSupportDirectory();
    }
    // Linux / Windows / web fallback — same API.
    return getApplicationSupportDirectory();
  }
}
