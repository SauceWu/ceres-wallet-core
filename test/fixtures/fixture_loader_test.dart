// Self-test for the AA fixture loader.
// Plan 06-01, Task 3. Verifies the contract documented in fixture_loader.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'fixture_loader.dart';

void main() {
  final placeholder = File('test/fixtures/aa/webauthn_p256/_loader_smoke.json');
  const placeholderJson = {
    'note': 'Loader smoke test — not a real vector. See 06-01-PLAN.md task 3.',
    'authenticatorData': '1a70842af8c1feb7133b81e6a160a6a2be45ee057f0eb6d3f7f5126daa202e071d00000000',
    'someNumber': '12345',
  };

  setUp(() {
    placeholder.parent.createSync(recursive: true);
    placeholder.writeAsStringSync(jsonEncode(placeholderJson));
  });

  tearDown(() {
    if (placeholder.existsSync()) placeholder.deleteSync();
  });

  test('loadAaFixture decodes JSON object', () {
    final fx = loadAaFixture('webauthn_p256/_loader_smoke.json');
    expect(fx['note'], placeholderJson['note']);
    expect(fx['someNumber'], '12345');
  });

  test('hex decodes bare hex per D-02', () {
    final bytes = hex('1a70842af8c1feb7133b81e6a160a6a2be45ee057f0eb6d3f7f5126daa202e071d00000000');
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, 37);
    expect(bytes[0], 0x1a);
    expect(bytes[1], 0x70);
  });

  test('hex accepts 0x prefix (resilience for barz.rs copy-paste)', () {
    final a = hex('deadbeef');
    final b = hex('0xdeadbeef');
    final c = hex('0XDEADBEEF');
    expect(a, b);
    expect(a, c);
  });

  test('hex empty string returns empty Uint8List', () {
    expect(hex(''), Uint8List(0));
    expect(hex('0x'), Uint8List(0));
  });

  test('loadAaFixture throws FileSystemException for missing file', () {
    expect(
      () => loadAaFixture('webauthn_p256/does_not_exist_${DateTime.now().microsecondsSinceEpoch}.json'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('loadAaFixture rejects path escape attempts', () {
    expect(
      () => loadAaFixture('../../../etc/passwd'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('hex throws FormatException on odd length', () {
    expect(() => hex('abc'), throwsA(isA<FormatException>()));
  });

  test('hex throws FormatException on non-hex characters', () {
    expect(() => hex('zz'), throwsA(isA<FormatException>()));
    expect(() => hex('xy'), throwsA(isA<FormatException>()));
  });
}
