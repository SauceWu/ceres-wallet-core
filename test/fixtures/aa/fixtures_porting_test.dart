// Validates that every JSON fixture under test/fixtures/aa/ loads cleanly,
// declares its source-of-truth provenance, and has byte-shaped fields
// that decode via the canonical hex() helper.
//
// Pitfall 11 prevention: this test refuses to let a fixture lacking a
// `_source: third_party/wallet-core/rust/tw_evm/tests/barz.rs:NNN`
// pointer survive in the tree.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../fixture_loader.dart';

void main() {
  const fixtureRoot = 'test/fixtures/aa';
  final byteFieldNames = <String>{
    'init_code',
    'paymaster_data',
    'factory_data',
    'paymaster_and_data',
    'signature_der',
    'challenge',
    'authenticator_data',
    'expected_call_data',
    'expected_signature',
    'pre_hash',
    'expected_r_hex_32',
    'expected_s_hex_32',
    'transfer_amount_hex',
    'approve_amount_hex',
    'private_key',
  };
  final sourceLineRe = RegExp(
    r'^third_party/wallet-core/rust/tw_evm/tests/barz\.rs:[0-9]+$',
  );

  List<File> allJsonFixtures() {
    return Directory(fixtureRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
  }

  test('every committed fixture has _source pointing at barz.rs:NNN', () {
    final files = allJsonFixtures();
    expect(files, isNotEmpty,
        reason: 'No JSON fixtures found under $fixtureRoot — '
            'Plan 06-02 must port at least 8 vectors.');
    for (final f in files) {
      final relPath = f.path.replaceFirst('$fixtureRoot/', '');
      final fx = loadAaFixture(relPath);
      expect(fx['_source'], isA<String>(),
          reason: '$relPath missing _source field (D-04)');
      expect(sourceLineRe.hasMatch(fx['_source'] as String), isTrue,
          reason: '$relPath _source must match '
              'third_party/wallet-core/rust/tw_evm/tests/barz.rs:NNN '
              '(got "${fx['_source']}")');
    }
  });

  test('every byte field decodes via hex() without throwing', () {
    for (final f in allJsonFixtures()) {
      final relPath = f.path.replaceFirst('$fixtureRoot/', '');
      final fx = loadAaFixture(relPath);
      for (final entry in fx.entries) {
        if (!byteFieldNames.contains(entry.key)) continue;
        final value = entry.value;
        if (value is! String) {
          fail('$relPath: ${entry.key} is not a string '
              '(got ${value.runtimeType})');
        }
        // hex() throws FormatException on bad input.
        try {
          hex(value);
        } on FormatException catch (e) {
          fail('$relPath: hex(${entry.key}="$value") failed: $e');
        }
      }
    }
  });

  test('canonical anchor fixtures exist (guard against accidental deletion)',
      () {
    const anchors = [
      'webauthn_p256/get_formatted_signature_001.json',
      'webauthn_p256/get_rs_values_001.json',
      'barz_userop_v06/transfer_account_deployed.json',
      'barz_userop_v06/transfer_account_not_deployed.json',
      'barz_userop_v07/transfer_account_not_deployed_v07.json',
      'barz_userop_v07/biz4337_transfer.json',
      'barz_userop_v07/biz4337_transfer_batch.json',
      'barz_userop_v07/incorrect_wallet_type_error.json',
    ];
    for (final a in anchors) {
      final fx = loadAaFixture(a);
      expect(fx, isNotEmpty, reason: 'Anchor fixture $a is empty');
    }
  });

  test('barz_userop_v06 deployed pre_hash matches barz.rs:80 verbatim', () {
    final fx = loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
    expect(fx['pre_hash'],
        '2d37191a8688f69090451ed90a0a9ba69d652c2062ee9d023b3ebe964a3ed2ae');
  });

  test('barz_userop_v07 transfer pre_hash matches barz.rs:266 verbatim', () {
    final fx = loadAaFixture(
        'barz_userop_v07/transfer_account_not_deployed_v07.json');
    expect(fx['pre_hash'],
        'f177858c1c500e51f38ffe937bed7e4d3a8678725900be4682d3ce04d97071eb');
  });

  test('webauthn fixture has DER signature and clientDataJSON verbatim', () {
    final fx = loadAaFixture('webauthn_p256/get_formatted_signature_001.json');
    expect(
        fx['signature_der'],
        '3044022012d89e3b41e253dc9e90bd34dc1750d059b76d0b1d16af2059aa26e90b8960bf'
        '0220256d8a05572c654906ce422464693e280e243e6d9dbc5f96a681dba846bca276');
    // clientDataJSON value is a JSON-encoded string. Verbatim from barz.rs:742.
    expect(
        fx['client_data_json'],
        '{"type":"webauthn.get","challenge":'
        '"zyZ6eMWtr5bzQaaW61doJChMVy8-Yb5hlpTVOdsZJfk",'
        '"origin":"https://trustwallet.com"}');
  });

  test(
      'eip7702_authorization directory may be empty '
      '(vectors live in eip7702.rs, P13 scope)', () {
    final dir = Directory('$fixtureRoot/eip7702_authorization');
    expect(dir.existsSync(), isTrue);
    // Allow 0 .json files — that's expected for P6.
  });
}
