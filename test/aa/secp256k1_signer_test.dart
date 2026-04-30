// Phase 7, Plan 04 — Golden vector + parallel-call serialization +
// sealed-union shape tests + D-12 compliance assertion.
//
// NOTE — _SpySigner invocation count:
//   EvmSigner._doSign (leading underscore) is library-private to the
//   anonymous library rooted at `lib/src/aa/evm_signature.dart`. A subclass
//   defined in a different library (here: a test file) cannot override
//   a library-private method. Therefore the "5 parallel calls → exactly 1
//   _doSign invocation" assertion is verified via `identical()` — which is a
//   STRONGER guarantee: it proves the 5 awaiters received the SAME Future
//   instance, not just equal results. The invocation-count style spy is
//   deferred to a future phase that adds `@visibleForTesting` hooks.
//
// Run via:
//   flutter test test/aa/secp256k1_signer_test.dart   (JIT host mode)
//
// Skip policy: tests that call TWPrivateKey require the native dylib.
// On macOS host (CI / developer machine), the dylib is unavailable (same
// blocker as release_mode_smoke_test.dart TODO(P13)). Skipped with the same
// note; they run in-full on Android/iOS test runners or when the dylib ships
// for macOS.

import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  group('golden vector — barz_userop_v06/transfer_account_deployed.json', () {
    test(
      'signs pre_hash and matches expected_signature bytewise',
      () async {
        final fixture =
            loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
        final pk =
            TWPrivateKey.createWithData(hex(fixture['private_key'] as String));
        final signer = Secp256k1Signer(pk);
        final digest = hex(fixture['pre_hash'] as String);
        final expected = hex(fixture['expected_signature'] as String);

        final sig = await signer.signDigest(digest);

        expect(sig, isA<Secp256k1Signature>());
        final s = sig as Secp256k1Signature;
        expect(s.rsv, equals(expected));
        expect(s.r, equals(expected.sublist(0, 32)));
        expect(s.s, equals(expected.sublist(32, 64)));
        expect(s.v, equals(0x1c)); // recovery id 28 (Ethereum legacy)
      },
      // TODO(P13): re-enable when macOS host dylib ships.
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group('single-flight', () {
    test(
      '5 parallel signDigest calls all coalesce onto one in-flight ceremony',
      () async {
        final fixture =
            loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
        final pk =
            TWPrivateKey.createWithData(hex(fixture['private_key'] as String));
        final signer = Secp256k1Signer(pk);
        final digest = hex(fixture['pre_hash'] as String);

        final results = await Future.wait([
          for (var i = 0; i < 5; i++) signer.signDigest(digest),
        ]);

        expect(results.length, 5);
        // `identical` proves single-flight: all 5 awaiters received the SAME
        // EvmSignature INSTANCE (D-27, ROADMAP P7 success criterion #4).
        // This is stronger than value equality — it proves one Future was
        // shared, not 5 parallel ceremonies producing equal bytes.
        expect(
          results.every((r) => identical(r, results.first)),
          isTrue,
          reason: 'All 5 awaiters must receive the SAME EvmSignature instance '
              '(Pitfall 7 prevention — single-flight invariant)',
        );
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'after resolution, next signDigest schedules a fresh ceremony',
      () async {
        final fixture =
            loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
        final pk =
            TWPrivateKey.createWithData(hex(fixture['private_key'] as String));
        final signer = Secp256k1Signer(pk);
        final digest = hex(fixture['pre_hash'] as String);

        final sig1 = await signer.signDigest(digest);
        final sig2 = await signer.signDigest(digest);
        // A second sequential call produces a new signing ceremony; result
        // is correct (same deterministic signature) but a NEW instance
        // because the _pending field was cleared after the first completion.
        expect(sig1, isA<Secp256k1Signature>());
        expect(sig2, isA<Secp256k1Signature>());
        expect((sig1 as Secp256k1Signature).rsv,
            equals((sig2 as Secp256k1Signature).rsv));
        // Verify _pending was cleared: sig2 must be a NEW instance — not the
        // cached sig1 Future. If _pending were never cleared, identical(sig1, sig2)
        // would be true and single-flight would never resolve fresh (D-20).
        expect(
          identical(sig1, sig2),
          isFalse,
          reason: 'Sequential calls must produce separate instances — '
              '_pending must be cleared after first completion (D-20).',
        );
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group('sealed union shape — Pitfall 1 + Pitfall 3 prevention', () {
    test('PasskeySignature.fromBarzFormatted rejects 64-byte r||s buffer', () {
      expect(
        () => PasskeySignature.fromBarzFormatted(Uint8List(64)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('PasskeySignature.fromBarzFormatted rejects 199-byte buffer (boundary)',
        () {
      expect(
        () => PasskeySignature.fromBarzFormatted(Uint8List(199)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('PasskeySignature.fromBarzFormatted accepts 290-byte Barz blob', () {
      final blob = Uint8List(290);
      final sig = PasskeySignature.fromBarzFormatted(blob);
      expect(sig.formattedBlob.length, 290);
    });

    test('exhaustive switch over EvmSignature dispatches both variants', () {
      String describe(EvmSignature s) {
        return switch (s) {
          Secp256k1Signature() => 'secp256k1',
          PasskeySignature() => 'passkey',
        };
      }

      final sec = Secp256k1Signature(
        r: Uint8List(32),
        s: Uint8List(32),
        v: 27,
      );
      final pk = PasskeySignature.fromBarzFormatted(Uint8List(290));
      expect(describe(sec), 'secp256k1');
      expect(describe(pk), 'passkey');
    });

    test(
      'signDigest rejects 31-byte digest with AssertionError',
      () async {
        final fixture =
            loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
        final pk = TWPrivateKey.createWithData(
            hex(fixture['private_key'] as String));
        final signer = Secp256k1Signer(pk);
        expect(
          () => signer.signDigest(Uint8List(31)),
          throwsA(isA<AssertionError>()),
        );
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'signDigest rejects 60-byte EIP-191-prefixed buffer (Pitfall 3 frontline guard)',
      () async {
        final fixture =
            loadAaFixture('barz_userop_v06/transfer_account_deployed.json');
        final pk = TWPrivateKey.createWithData(
            hex(fixture['private_key'] as String));
        final signer = Secp256k1Signer(pk);
        expect(
          () => signer.signDigest(Uint8List(60)),
          throwsA(isA<AssertionError>()),
        );
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group(
      'D-12 fixture-reference compliance — webauthn_p256/get_formatted_signature_001.json',
      () {
    test('loadAaFixture surfaces signature_der as non-empty hex string', () {
      final fixture =
          loadAaFixture('webauthn_p256/get_formatted_signature_001.json');
      final sigDer = fixture['signature_der'] as String;
      expect(sigDer, isNotEmpty);
      // hex-decodes cleanly (no length / charset surprises) — D-12 token assertion.
      final decoded = hex(sigDer);
      expect(decoded.length, greaterThan(0));
    });
  });
}
