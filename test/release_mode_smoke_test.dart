// Phase 6, Plan 04 — release-mode FFI smoke test.
// Goal: prove the Plan 03 keepAlive helper + Plan 02 fixture loader compose
// safely across an await boundary, in BOTH debug AND release modes.
//
// Run via:
//   flutter test test/release_mode_smoke_test.dart            (debug)
//   flutter test --release test/release_mode_smoke_test.dart  (release — the load-bearing case for Pitfall 8)
//   tool/run_release_tests.sh                                 (Plan 04 Task 2)
//
// Pitfall 8 (Finalizer GC mid-await) prevention reference:
//   .planning/research/PITFALLS.md
//   lib/src/_ffi_reachability.dart (Plan 06-03 doc block)
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:ceres_wallet_core/src/_ffi_reachability.dart' show keepAlive;
import 'package:ceres_wallet_core/bindings/ceres_wallet_core_bindings.dart' as raw;

import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fixture_loader.dart';

void main() {
  // 32-byte digest used by case (1). Arbitrary but deterministic.
  final digest = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('TWPrivateKey survives await Future.delayed with keepAlive', () async {
    final pk = TWPrivateKey();
    try {
      // Cross-await — release-mode escape analysis may consider pk dead here.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final sig = pk.sign(digest, raw.TWCurve.TWCurveSECP256k1);
      expect(sig, isA<Uint8List>());
      expect(sig.length, 65, reason: 'secp256k1 signature is r||s||v = 65 bytes');
    } finally {
      keepAlive(pk);
    }
  });

  test('fixture loader is reachable from release-mode test', () {
    final fx = loadAaFixture('webauthn_p256/get_formatted_signature_001.json');
    expect(fx['_source'], isA<String>());
    expect(
      (fx['_source'] as String).startsWith(
          'third_party/wallet-core/rust/tw_evm/tests/barz.rs:'),
      isTrue,
      reason: 'Plan 06-02 must populate _source per D-04',
    );
    final der = hex(fx['signature_der'] as String);
    expect(der.length, 70,
        reason: 'Upstream barz.rs:736 DER signature is 70 bytes '
            '(0x30 0x44 marker + 0x02 0x20 + 32-byte r + 0x02 0x20 + 32-byte s)');
  });

  test('TWPrivateKey + fixture load + cross-await all compose', () async {
    final fx = loadAaFixture('webauthn_p256/get_formatted_signature_001.json');
    final challenge = hex(fx['challenge'] as String);
    expect(challenge.length, 32,
        reason: 'WebAuthn challenge is sha256(userOpHash) — 32 bytes');

    // Deterministic test private key (NOT a real key — same key as
    // barz.rs:36, well-known test material).
    final pkBytes = hex(
        '3c90badc15c4d35733769093d3733501e92e7f16e101df284cee9a310d36c483');
    final pk = TWPrivateKey.createWithData(pkBytes);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final sig = pk.sign(challenge, raw.TWCurve.TWCurveSECP256k1);
      expect(sig, isA<Uint8List>());
      expect(sig.length, 65);
      // Determinism: signing the same challenge with the same key yields
      // the same r and s (low-S normalized by upstream secp256k1). We do
      // NOT assert exact bytes here — that level of golden-vector
      // verification is P7's job. We assert only the shape contract.
    } finally {
      keepAlive(pk);
    }
  });
}
