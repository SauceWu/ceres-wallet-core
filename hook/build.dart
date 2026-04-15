// hook/build.dart
// Downloads pre-built native libraries from GitHub Releases
// and declares them as code assets for Flutter to bundle.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const String _repo = 'SauceWu/ceres-wallet-core';
const String _libName = 'ceres_wallet_core';

void main(List<String> args) async {
  await build(args, _build);
}

Future<void> _build(BuildInput input, BuildOutputBuilder output) async {
  if (!input.config.buildCodeAssets) return;

  final codeConfig = input.config.code;
  final targetOS = codeConfig.targetOS;
  final targetArch = codeConfig.targetArchitecture;
  final packageName = input.packageName;
  final outputDir = input.outputDirectoryShared;

  // Determine the native library file name
  final String libFileName;
  final String archiveFileName;

  switch (targetOS) {
    case OS.android:
      final abi = _androidAbi(targetArch);
      libFileName = 'lib$_libName.so';
      archiveFileName = 'android-$abi.tar.gz';
    case OS.iOS:
      // Download xcframework, then pick the right slice (device or simulator)
      final iosSdk = codeConfig.iOS.targetSdk;
      final isSimulator = iosSdk == IOSSdk.iPhoneSimulator;
      final xcfSlice = isSimulator
          ? '$_libName.xcframework/ios-arm64-simulator'
          : '$_libName.xcframework/ios-arm64';
      libFileName = '$xcfSlice/$_libName.framework/$_libName';
      archiveFileName = 'ios-xcframework.tar.gz';
    case OS.macOS:
      libFileName = 'lib$_libName.dylib';
      archiveFileName = 'macos-${targetArch.toString()}.tar.gz';
    case OS.linux:
      libFileName = 'lib$_libName.so';
      archiveFileName = 'linux-${targetArch.toString()}.tar.gz';
    case OS.windows:
      libFileName = '$_libName.dll';
      archiveFileName = 'windows-${targetArch.toString()}.tar.gz';
    default:
      throw UnsupportedError('Unsupported OS: $targetOS');
  }

  // Output path for the native library
  final libFile = File.fromUri(outputDir.resolve(libFileName));

  // Download if not already cached
  if (!libFile.existsSync()) {
    // Try local build output first (for development)
    final localFile = _findLocalLib(input, targetOS, targetArch, libFileName);
    if (localFile != null) {
      stdout.writeln('Using local build: ${localFile.path}');
      // Ensure parent directories exist (e.g. .framework/)
      libFile.parent.createSync(recursive: true);
      localFile.copySync(libFile.path);
    } else {
      // Download from GitHub Releases
      final version = _readVersion();
      final url =
          'https://github.com/$_repo/releases/download/v$version/$archiveFileName';
      stdout.writeln('Downloading $archiveFileName from $url ...');

      try {
        await _downloadAndExtract(
          url: url,
          outputDir: outputDir,
          expectedFile: libFile,
        );
      } catch (e) {
        // Download failed — skip asset declaration.
        // The native library will be built from source via podspec/CMakeLists
        // or must be provided manually.
        stderr.writeln(
          'Warning: Could not download native library ($e).\n'
          'Falling back to source build (podspec/CMakeLists).\n'
          'For pre-built binaries, ensure GitHub Release v${_readVersion()} exists.',
        );
        return;
      }

      if (!libFile.existsSync()) {
        stderr.writeln(
          'Warning: $libFileName not found after extraction. '
          'Falling back to source build.',
        );
        return;
      }
    }
  }

  // Declare the code asset — all platforms use dynamic loading
  output.assets.code.add(
    CodeAsset(
      package: packageName,
      name: '$_libName.dart',
      linkMode: DynamicLoadingBundled(),
      file: libFile.uri,
    ),
  );
}

/// Read package version from pubspec.yaml
String _readVersion() {
  // Walk up to find pubspec.yaml
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final match =
          RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
      if (match != null) return match.group(1)!.trim();
    }
    dir = dir.parent;
  }
  return Platform.environment['CERES_WALLET_CORE_VERSION'] ?? '0.0.1';
}

/// Find locally built native library (for development without GitHub Releases).
/// Checks ios/Libraries/, android/src/main/jniLibs/, build/ etc.
File? _findLocalLib(
  BuildInput input,
  OS targetOS,
  Architecture targetArch,
  String libFileName,
) {
  // Package root is the current directory when hook runs
  final packageRoot = Directory.current.path;

  final candidates = <String>[];

  switch (targetOS) {
    case OS.android:
      final abi = _androidAbi(targetArch);
      candidates.add('$packageRoot/android/src/main/jniLibs/$abi/$libFileName');
    case OS.iOS:
      // Try xcframework slices first, then standalone framework
      candidates.add('$packageRoot/ios/Frameworks/$_libName.xcframework/ios-arm64-simulator/$_libName.framework/$_libName');
      candidates.add('$packageRoot/ios/Frameworks/$_libName.xcframework/ios-arm64/$_libName.framework/$_libName');
      candidates.add('$packageRoot/ios/Frameworks/$_libName.framework/$_libName');
    case OS.macOS:
      candidates.add('$packageRoot/build/macos/$libFileName');
    default:
      break;
  }

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

/// Map Dart Architecture to Android ABI name
String _androidAbi(Architecture arch) {
  if (arch == Architecture.arm64) return 'arm64-v8a';
  if (arch == Architecture.arm) return 'armeabi-v7a';
  if (arch == Architecture.x64) return 'x86_64';
  if (arch == Architecture.ia32) return 'x86';
  throw UnsupportedError('Unsupported Android architecture: $arch');
}

/// Download archive and extract to outputDir
Future<void> _downloadAndExtract({
  required String url,
  required Uri outputDir,
  required File expectedFile,
}) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 30);

  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      final body = await response.transform(SystemEncoding().decoder).join();
      throw StateError('HTTP ${response.statusCode} downloading $url\n$body');
    }

    // Save to temp file
    final tempDir = await Directory.systemTemp.createTemp('ceres_native_');
    final tempFile = File('${tempDir.path}/archive.tar.gz');
    final sink = tempFile.openWrite();
    await response.pipe(sink);

    // Extract
    final outPath = Directory.fromUri(outputDir);
    if (!outPath.existsSync()) {
      outPath.createSync(recursive: true);
    }

    final result = await Process.run(
      'tar',
      ['-xzf', tempFile.path, '-C', outPath.path],
    );
    if (result.exitCode != 0) {
      throw StateError('tar extract failed: ${result.stderr}');
    }

    // Cleanup
    await tempDir.delete(recursive: true);
  } finally {
    client.close();
  }
}
