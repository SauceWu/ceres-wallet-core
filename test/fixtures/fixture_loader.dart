// Canonical loader for AA fixtures. See:
//   .planning/phases/06-ffi-hardening-test-fixtures/06-CONTEXT.md (D-03)
// All AA tests MUST consume fixtures through this helper — never via
// direct `File.readAsString` calls. This single chokepoint guarantees
// path resolution + hex decoding stay consistent across phases P7..P13.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Root directory under which all AA fixtures live (relative to the
/// package root, which is the cwd when `flutter test` runs).
const String _aaFixtureRoot = 'test/fixtures/aa';

/// Normalizes a POSIX-ish path-segment list, resolving `.` and `..`
/// segments without touching the filesystem. Returns null if `..`
/// segments underflow (attempt to escape above the root).
List<String>? _normalizeSegments(List<String> segments) {
  final out = <String>[];
  for (final seg in segments) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.isEmpty) return null;
      out.removeLast();
      continue;
    }
    out.add(seg);
  }
  return out;
}

/// True iff `segs` starts with every segment in `prefix` in order.
bool _startsWithPrefix(List<String> segs, List<String> prefix) {
  if (segs.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (segs[i] != prefix[i]) return false;
  }
  return true;
}

/// Loads a JSON fixture from `test/fixtures/aa/{relPath}` and returns
/// it as `Map<String, dynamic>`.
Map<String, dynamic> loadAaFixture(String relPath) {
  // Reject backslashes outright. This package targets iOS / Android /
  // macOS only; allowing `\\` would silently bypass the path-traversal
  // guard below because `split('/')` would not split on backslash and
  // would yield a single segment containing the entire string (WR-03).
  if (relPath.contains('\\')) {
    throw ArgumentError.value(
      relPath,
      'relPath',
      r'Backslashes not allowed; use forward slashes only',
    );
  }
  // Path-escape guard (defense-in-depth, threat T-06-01-01): normalize
  // `${_aaFixtureRoot}/${relPath}` purely as strings and reject any input
  // whose `..` segments climb above the fixture root. We don't rely on
  // `File.absolute.path` because that does not collapse `..` segments.
  final rootSegs = _aaFixtureRoot.split('/');
  final relSegs = relPath.split('/');
  final normalizedSegs = _normalizeSegments([...rootSegs, ...relSegs]);
  if (normalizedSegs == null || !_startsWithPrefix(normalizedSegs, rootSegs)) {
    throw ArgumentError.value(
      relPath,
      'relPath',
      'Path escapes fixture root ($_aaFixtureRoot)',
    );
  }
  final joined = '$_aaFixtureRoot/$relPath';
  final file = File(joined);
  if (!file.existsSync()) {
    final resolved = file.absolute.path;
    throw FileSystemException(
      'Fixture not found: $joined (resolved: $resolved). '
      'Did Plan 02 port it yet?',
      joined,
    );
  }
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      'Fixture $joined did not decode to a JSON object (got ${decoded.runtimeType})',
    );
  }
  return decoded;
}

/// Decodes a hex string into bytes. Accepts an optional leading `0x` and
/// is case-insensitive. Throws `FormatException` on odd length or
/// non-hex characters. See D-02 — fixture JSON stores bytes as hex
/// WITHOUT the `0x` prefix.
Uint8List hex(String s) {
  var input = s;
  if (input.startsWith('0x') || input.startsWith('0X')) {
    input = input.substring(2);
  }
  if (input.isEmpty) return Uint8List(0);
  if (input.length.isOdd) {
    throw FormatException('hex string must be even length: "$s"');
  }
  final out = Uint8List(input.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final byte = int.tryParse(input.substring(i * 2, i * 2 + 2), radix: 16);
    if (byte == null) {
      throw FormatException(
        'Invalid hex character in "$s" at offset ${i * 2}',
      );
    }
    out[i] = byte;
  }
  return out;
}
