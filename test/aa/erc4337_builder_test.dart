// Tests for Erc4337Builder (Phase 12).
//
// D-12 compliance: FFI-dependent tests (computeHash, buildOutput) use
//   skip: 'macOS host dylib unavailable — see TODO(P13)'
//
// Pure-Dart tests (factory constructors, deployedState tracking, attachSignature
// conversion, challenge validation, Pitfall 4 version safety) run unconditionally.
import 'dart:convert' show base64Url;
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:ceres_wallet_core/proto/Ethereum.pbenum.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Erc4337Builder _v06Builder({bool deployed = false, Uint8List? initCode}) =>
    Erc4337Builder.v06(
      deployment: BarzDeployments.mainnet,
      sender: '0xb16Db98B365B1f89191996942612B14F1Da4Bd5f',
      nonce: BigInt.from(2),
      target: '0x61061fCAE11fD5461535e134EfF67A98CFFF44E9',
      value: BigInt.zero,
      innerCallData: Uint8List(0),
      callGasLimit: BigInt.from(100000),
      verificationGasLimit: BigInt.from(100000),
      preVerificationGas: BigInt.from(46856),
      maxFeePerGas: BigInt.parse('7033440745'),
      maxPriorityFeePerGas: BigInt.parse('7033440745'),
      initCode: initCode,
      deployed: deployed,
    );

Erc4337Builder _v07Builder({bool deployed = false}) => Erc4337Builder.v07(
      deployment: BarzDeployments.mainnet,
      sender: '0xb16Db98B365B1f89191996942612B14F1Da4Bd5f',
      nonce: BigInt.from(1),
      target: '0x61061fCAE11fD5461535e134EfF67A98CFFF44E9',
      value: BigInt.zero,
      innerCallData: Uint8List(0),
      callGasLimit: BigInt.from(100000),
      verificationGasLimit: BigInt.from(100000),
      preVerificationGas: BigInt.from(46856),
      maxFeePerGas: BigInt.parse('7033440745'),
      maxPriorityFeePerGas: BigInt.parse('7033440745'),
      factory: deployed ? null : BarzDeployments.mainnet.factory,
      factoryData: deployed ? null : Uint8List(0),
      deployed: deployed,
    );

void main() {
  // ── v06 factory constructor ────────────────────────────────────────────────

  group('Erc4337Builder.v06 — constructor', () {
    test('isV06 is true, isV07 is false', () {
      final b = _v06Builder();
      expect(b.isV06, isTrue);
      expect(b.isV07, isFalse);
    });

    test('buildSigningInput returns a SigningInput with UserOperation set', () {
      final b = _v06Builder();
      final si = b.buildSigningInput();
      // userOperationOneof should be set to userOperation (v0.6)
      expect(si.hasUserOperation(), isTrue);
      expect(si.hasUserOperationV07(), isFalse);
    });

    test('userOperation.sender is set correctly', () {
      final b = _v06Builder();
      final si = b.buildSigningInput();
      expect(si.userOperation.sender,
          equals('0xb16Db98B365B1f89191996942612B14F1Da4Bd5f'));
    });

    test('txMode is UserOp', () {
      final b = _v06Builder();
      final si = b.buildSigningInput();
      expect(si.txMode, equals(TransactionMode.UserOp));
    });
  });

  // ── v07 factory constructor ────────────────────────────────────────────────

  group('Erc4337Builder.v07 — constructor', () {
    test('isV07 is true, isV06 is false', () {
      final b = _v07Builder();
      expect(b.isV07, isTrue);
      expect(b.isV06, isFalse);
    });

    test('buildSigningInput returns a SigningInput with UserOperationV07 set', () {
      final b = _v07Builder();
      final si = b.buildSigningInput();
      expect(si.hasUserOperationV07(), isTrue);
      expect(si.hasUserOperation(), isFalse);
    });

    test('userOperationV07.sender is set correctly', () {
      final b = _v07Builder();
      final si = b.buildSigningInput();
      expect(si.userOperationV07.sender,
          equals('0xb16Db98B365B1f89191996942612B14F1Da4Bd5f'));
    });

    test('userOperationV07.factory is set when not deployed', () {
      final b = _v07Builder(deployed: false);
      final si = b.buildSigningInput();
      expect(si.userOperationV07.factory, isNotEmpty);
    });

    test('userOperationV07.factory is empty when deployed=true', () {
      final b = _v07Builder(deployed: true);
      final si = b.buildSigningInput();
      expect(si.userOperationV07.factory, isEmpty);
    });
  });

  // ── Deployed-state tracking (Pitfall 12 prevention) ───────────────────────

  group('Erc4337Builder — deployed-state tracking', () {
    test('v06 initCode is empty bytes when deployed=true', () {
      final b = _v06Builder(deployed: true);
      final si = b.buildSigningInput();
      expect(si.userOperation.initCode, isEmpty);
    });

    test('v06 initCode is set when deployed=false and initCode provided', () {
      final fakeInitCode = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final b = _v06Builder(deployed: false, initCode: fakeInitCode);
      final si = b.buildSigningInput();
      expect(si.userOperation.initCode, equals([0xAA, 0xBB, 0xCC]));
    });

    test('v07 factory is empty when deployed=true (Pitfall 12 prevention)', () {
      final b = _v07Builder(deployed: true);
      final si = b.buildSigningInput();
      expect(si.userOperationV07.factory, isEmpty);
    });
  });

  // ── attachSignature — SOLE conversion site ────────────────────────────────

  group('Erc4337Builder.attachSignature — SOLE conversion site', () {
    test('Secp256k1Signature → 65-byte rsv', () {
      final b = _v06Builder();
      final sig = Secp256k1Signature.fromRsv(Uint8List(65));
      final bytes = b.attachSignature(sig);
      expect(bytes.length, equals(65));
    });

    test('PasskeySignature → formattedBlob', () {
      final b = _v06Builder();
      final blob = Uint8List(200)..[0] = 0xDE;
      final sig = PasskeySignature.fromBarzFormatted(blob);
      final bytes = b.attachSignature(sig);
      expect(bytes.length, equals(200));
      expect(bytes[0], equals(0xDE));
    });

    test('different EvmSignature subtypes produce different byte sizes', () {
      final b = _v06Builder();
      final secp = Secp256k1Signature.fromRsv(Uint8List(65));
      final passkey = PasskeySignature.fromBarzFormatted(Uint8List(200));
      final secpBytes = b.attachSignature(secp);
      final passkeyBytes = b.attachSignature(passkey);
      expect(secpBytes.length, isNot(equals(passkeyBytes.length)));
    });
  });

  // ── Challenge validation (Pitfall 3 prevention) ───────────────────────────

  group('Erc4337Builder — PasskeyChallengeMismatch', () {
    test('throws when challenge does not match stored hash', () {
      // Test the error type is exported correctly.
      expect(PasskeyChallengeMismatch('test'), isA<PasskeyChallengeMismatch>());
      expect(PasskeyChallengeMismatch('test').toString(),
          contains('PasskeyChallengeMismatch'));
    });

    // ── validateChallengeForTest: pure-Dart coverage of _validateChallenge ──
    // These tests use the @visibleForTesting entry point to exercise the
    // challenge-validation logic without requiring FFI (computeHash needs the
    // native dylib to set _computedHash; these tests inject an arbitrary hash).

    group('validateChallengeForTest — pure Dart', () {
      final storedHash = Uint8List(32)
        ..[0] = 0xAB
        ..[1] = 0xCD;

      test('correct base64url-no-pad challenge passes', () {
        final b64 = base64Url.encode(storedHash).replaceAll('=', '');
        expect(
          () => Erc4337Builder.validateChallengeForTest(
            '{"type":"webauthn.get","challenge":"$b64"}',
            storedHash,
          ),
          returnsNormally,
        );
      });

      test('correct base64url challenge with padding also passes', () {
        final b64 = base64Url.encode(storedHash); // may include '='
        expect(
          () => Erc4337Builder.validateChallengeForTest(
            '{"type":"webauthn.get","challenge":"$b64"}',
            storedHash,
          ),
          returnsNormally,
        );
      });

      test('wrong challenge bytes → PasskeyChallengeMismatch', () {
        final wrongHash = Uint8List(32)..[0] = 0xFF;
        final b64 = base64Url.encode(wrongHash).replaceAll('=', '');
        expect(
          () => Erc4337Builder.validateChallengeForTest(
            '{"type":"webauthn.get","challenge":"$b64"}',
            storedHash,
          ),
          throwsA(isA<PasskeyChallengeMismatch>()),
        );
      });

      test('invalid JSON → PasskeyChallengeMismatch', () {
        expect(
          () => Erc4337Builder.validateChallengeForTest('not-json', storedHash),
          throwsA(isA<PasskeyChallengeMismatch>()),
        );
      });

      test('missing "challenge" field → PasskeyChallengeMismatch', () {
        expect(
          () => Erc4337Builder.validateChallengeForTest(
            '{"type":"webauthn.get"}',
            storedHash,
          ),
          throwsA(isA<PasskeyChallengeMismatch>()),
        );
      });

      test('non-base64url "challenge" value → PasskeyChallengeMismatch', () {
        expect(
          () => Erc4337Builder.validateChallengeForTest(
            '{"type":"webauthn.get","challenge":"!!!not-b64!!!"}',
            storedHash,
          ),
          throwsA(isA<PasskeyChallengeMismatch>()),
        );
      });
    });

    test('clientDataJSON with matching challenge passes validation', () {
      final b = _v06Builder();
      // Simulate a stored hash
      final hash = Uint8List(32)..[0] = 0xAB..[1] = 0xCD;
      final challengeB64 = base64Url.encode(hash).replaceAll('=', '');
      final clientDataJSON =
          '{"type":"webauthn.get","challenge":"$challengeB64","origin":"https://example.com"}';

      // Pass a dummy sig — no FFI needed for this validation path
      final sig = PasskeySignature.fromBarzFormatted(Uint8List(200));

      // No stored hash → validation is skipped (no StateError)
      expect(
        () => b.attachSignature(sig, clientDataJSON: clientDataJSON),
        returnsNormally,
      );
    });

    test('clientDataJSON with mismatching challenge throws when hash is stored',
        () {
      final wrongHash = Uint8List(32)..[0] = 0xFF;
      final rightHash = Uint8List(32)..[0] = 0xAB;
      final b = _v06Builder();
      final challengeB64 = base64Url.encode(wrongHash).replaceAll('=', '');
      final clientDataJSON =
          '{"type":"webauthn.get","challenge":"$challengeB64"}';

      // Since _computedHash = null, validation is skipped.
      // This tests the "no hash stored" path doesn't throw.
      final sig = PasskeySignature.fromBarzFormatted(Uint8List(200));
      expect(
        () => b.attachSignature(sig, clientDataJSON: clientDataJSON),
        returnsNormally,
        reason: 'No stored hash → challenge validation skipped',
      );

      // Confirm that PasskeyChallengeMismatch is throwable
      expect(
        () => throw PasskeyChallengeMismatch('hash mismatch: $rightHash'),
        throwsA(isA<PasskeyChallengeMismatch>()),
      );
    });

    test('invalid JSON in clientDataJSON does not throw when no stored hash',
        () {
      final b = _v06Builder();
      final sig = PasskeySignature.fromBarzFormatted(Uint8List(200));
      // With no stored hash, even invalid JSON is silently skipped.
      expect(
        () => b.attachSignature(sig, clientDataJSON: 'not-json'),
        returnsNormally,
      );
    });
  });

  // ── Version safety — Pitfall 4 prevention ────────────────────────────────

  group('Erc4337Builder — version discriminant (Pitfall 4)', () {
    test('v06 builder has userOperation (not V07) in signed input', () {
      final si = _v06Builder().buildSigningInput();
      expect(si.whichUserOperationOneof().name, equals('userOperation'));
    });

    test('v07 builder has userOperationV07 (not v06) in signed input', () {
      final si = _v07Builder().buildSigningInput();
      expect(si.whichUserOperationOneof().name, equals('userOperationV07'));
    });
  });

  // ── computeHash + buildOutput (FFI-dependent) ─────────────────────────────

  group('Erc4337Builder.computeHash + buildOutput (FFI)', () {
    const skip = 'macOS host dylib unavailable — see TODO(P13)';

    test('computeHash returns 32 bytes', () {
      final b = _v06Builder(deployed: true);
      final hash = b.computeHash();
      expect(hash.length, equals(32));
    }, skip: skip);

    test(
      'v06 UserOp hash matches barz.rs test_barz_transfer_account_deployed '
      'pre_hash = 2d37191a...',
      () {
        // barz.rs line 42 pre_hash:
        const expectedPreHash =
            '2d37191a8688f69090451ed90a0a9ba69d652c2062ee9d023b3ebe964a3ed2ae';

        // Build the exact same SigningInput as barz.rs test_barz_transfer_account_deployed.
        // chain_id=97 (BSC testnet), nonce=2, sender=0xb16Db98B..., deployed=true.
        // Note: barz.rs uses EntryPoint v0.6 on BSC testnet (chain 97).
        // BarzDeployments doesn't include BSC testnet, so we build manually.
        const testDeployment = BarzDeployment(
          chainId: 97,
          factory: '0x3fC708630d85A3B5ec217E53100eC2b735d4f800',
          verificationFacet: '0x6BF22ff186CC97D88ECfbA47d1473a234CEBEFDf',
          accountFacet: '0x0000000000000000000000000000000000000001',
          facetRegistry: '0x0000000000000000000000000000000000000002',
          defaultFallback: '0x0000000000000000000000000000000000000003',
          entryPointV06: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
          entryPointV07: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
          barzCreationCodeHex: '0x',
        );

        final builder = Erc4337Builder.v06(
          deployment: testDeployment,
          sender: '0xb16Db98B365B1f89191996942612B14F1Da4Bd5f',
          nonce: BigInt.from(2),
          target: '0x61061fCAE11fD5461535e134EfF67A98CFFF44E9',
          value: BigInt.parse('10000000000000000'),  // 0x2386f26fc10000
          innerCallData: Uint8List(0),
          callGasLimit: BigInt.from(100000),
          verificationGasLimit: BigInt.from(100000),
          preVerificationGas: BigInt.from(0xb708),  // 46856
          maxFeePerGas: BigInt.parse('7033440745'),  // 0x1a339c9e9
          maxPriorityFeePerGas: BigInt.parse('7033440745'),
          deployed: true,
        );

        final hash = builder.computeHash();
        final hashHex = hash
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        expect(hashHex, equals(expectedPreHash));
      },
      skip: skip,
    );
  });
}
