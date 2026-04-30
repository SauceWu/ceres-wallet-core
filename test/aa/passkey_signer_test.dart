// Tests for PasskeySigner (Phase 11).
//
// D-12 compliance: FFI-dependent tests use
//   skip: 'macOS host dylib unavailable — see TODO(P13)'
//
// Pure-Dart tests (adapter injection contract, single-flight invariant,
// type-safety verification) run unconditionally.
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fake PasskeyAssertion for unit testing ─────────────────────────────────

/// Fake adapter that returns a pre-baked [PasskeyAssertion].
/// Used to verify that adapter injection and single-flight semantics work
/// without requiring a real platform authenticator or native library.
PasskeyAdapter _fakeAdapter(PasskeyAssertion response) =>
    (Uint8List challenge) async => response;

/// Counting adapter — records how many times it was called.
class _CountingAdapter {
  int callCount = 0;

  Future<PasskeyAssertion> call(Uint8List challenge) async {
    callCount++;
    return PasskeyAssertion(
      derSignature: Uint8List(72), // Fake DER signature
      challenge: challenge,
      authenticatorData: Uint8List(37),
      clientDataJSON: '{"type":"webauthn.get"}',
    );
  }
}

void main() {
  // ── Adapter injection contract ─────────────────────────────────────────────

  group('PasskeySigner — adapter injection', () {
    test('accepts a PasskeyAdapter function at construction', () {
      final signer = PasskeySigner(adapter: _fakeAdapter(PasskeyAssertion(
        derSignature: Uint8List(72),
        challenge: Uint8List(32),
        authenticatorData: Uint8List(37),
        clientDataJSON: '{"type":"webauthn.get"}',
      )));
      expect(signer, isA<EvmSigner>());
      expect(signer, isA<PasskeySigner>());
    });

    test('PasskeySigner is an EvmSigner subtype', () {
      final signer = PasskeySigner(adapter: _fakeAdapter(PasskeyAssertion(
        derSignature: Uint8List(72),
        challenge: Uint8List(32),
        authenticatorData: Uint8List(37),
        clientDataJSON: '{"type":"webauthn.get"}',
      )));
      // Sealed type check: sealed EvmSignature switch would include
      // PasskeySignature. The signer inherits EvmSigner.
      expect(signer, isA<EvmSigner>());
    });
  });

  // ── Single-flight invariant ────────────────────────────────────────────────

  group('PasskeySigner — single-flight invariant', () {
    test(
      'concurrent signDigest calls coalesce to one adapter invocation',
      () async {
        // The counting adapter accumulates how many times it was called.
        // With single-flight semantics, two concurrent calls for the SAME
        // digest should only trigger ONE adapter call.
        final counter = _CountingAdapter();
        final signer = PasskeySigner(adapter: counter.call);
        final digest = Uint8List(32);

        // Launch two concurrent signDigest calls.
        final f1 = signer.signDigest(digest);
        final f2 = signer.signDigest(digest);

        // They should be the exact same future (single-flight).
        expect(identical(f1, f2), isTrue,
            reason: 'Concurrent signDigest calls must return the same Future');

        // The adapter is called but getFormattedSignature will fail on this
        // host (no native lib). We only care about the single-flight property.
        // Await one and ignore FFI errors.
        try {
          await f1;
        } catch (_) {
          // Expected: FFI / assertion error on macOS without native lib.
        }

        // Only ONE adapter call should have occurred.
        expect(counter.callCount, equals(1),
            reason: 'Adapter must be called exactly once for concurrent calls');
      },
    );

    test(
      'after first signDigest completes, a second call triggers a new ceremony',
      () async {
        final counter = _CountingAdapter();
        final signer = PasskeySigner(adapter: counter.call);
        final digest = Uint8List(32);

        try {
          await signer.signDigest(digest);
        } catch (_) {}

        try {
          await signer.signDigest(digest);
        } catch (_) {}

        // After the first completes, the second call must trigger a new
        // adapter invocation (D-20: no queue, fresh ceremony).
        expect(counter.callCount, equals(2),
            reason: 'Each non-overlapping signDigest must trigger a new ceremony');
      },
    );
  });

  // ── signDigest — digest length assertion ──────────────────────────────────

  group('PasskeySigner — signDigest digest length guard', () {
    test(
      'throws AssertionError when digest is not 32 bytes',
      () async {
        final signer = PasskeySigner(adapter: _fakeAdapter(PasskeyAssertion(
          derSignature: Uint8List(72),
          challenge: Uint8List(32),
          authenticatorData: Uint8List(37),
          clientDataJSON: '{}',
        )));
        // EvmSigner.signDigest asserts digest32.length == 32.
        // A 60-byte buffer triggers AssertionError immediately.
        expect(
          () => signer.signDigest(Uint8List(60)),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });

  // ── Type system: no 64-byte r‖s path ──────────────────────────────────────

  group('PasskeySigner — Pitfall 1 prevention (no raw r‖s path)', () {
    test('PasskeyAdapter function signature accepts only PasskeyAssertion', () {
      // PasskeyAdapter is defined as Future<PasskeyAssertion> Function(Uint8List).
      // This test asserts the type alias is correctly exported and typed.
      Future<PasskeyAssertion> adapter(Uint8List challenge) async {
        return PasskeyAssertion(
          derSignature: Uint8List(72),
          challenge: challenge,
          authenticatorData: Uint8List(37),
          clientDataJSON: '{"type":"webauthn.get"}',
        );
      }
      expect(adapter, isA<PasskeyAdapter>());
    });

    test(
      'PasskeySignature.fromBarzFormatted rejects blobs < 200 bytes in debug mode',
      () {
        // If the adapter somehow returned a 64-byte blob (e.g. a test mock),
        // PasskeySignature.fromBarzFormatted throws AssertionError in debug mode.
        expect(
          () => PasskeySignature.fromBarzFormatted(Uint8List(64)),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });

  // ── signDigest golden vector (FFI-dependent) ───────────────────────────────

  group('PasskeySigner.signDigest — golden vector (FFI)', () {
    const skip = 'macOS host dylib unavailable — see TODO(P13)';

    test(
      'formatted blob is ≥ 200 bytes for a real-shaped assertion',
      () async {
        // Source: barz.rs test vectors
        // Using a realistic-shaped DER signature and authenticator data.
        final derSignature = Uint8List.fromList([
          0x30, 0x45, 0x02, 0x21, 0x00, // SEQUENCE + r header
          ...List.generate(32, (i) => i + 1), // r (32 bytes)
          0x02, 0x20, // s header
          ...List.generate(32, (i) => i + 33), // s (32 bytes)
        ]);
        final challenge = Uint8List(32)..[0] = 0xAB;
        final authenticatorData = Uint8List(37)..[0] = 0xEF;
        const clientDataJSON =
            '{"type":"webauthn.get","challenge":"qw","origin":"https://example.com"}';

        final signer = PasskeySigner(
          adapter: (ch) async => PasskeyAssertion(
            derSignature: derSignature,
            challenge: ch,
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSON,
          ),
        );

        final sig = await signer.signDigest(challenge);
        expect(sig, isA<PasskeySignature>());
        final blob = (sig as PasskeySignature).formattedBlob;
        expect(blob.length, greaterThanOrEqualTo(200));
      },
      skip: skip,
    );
  });
}
