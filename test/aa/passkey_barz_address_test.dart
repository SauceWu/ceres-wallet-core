// Tests for PasskeyBarzAddress and BarzInitCode (Phase 9).
//
// D-12 compliance: FFI-dependent tests use
//   skip: 'macOS host dylib unavailable — see TODO(P13)'
// to allow the test file to be parsed / linted on CI hosts where the native
// library is not compiled into the Dart test runner.
//
// Pure-Dart tests (input validation, registry enumeration, ABI structure) run
// unconditionally and provide fast coverage without FFI.
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Test fixtures ──────────────────────────────────────────────────────────
//
// Source: third_party/wallet-core/rust/tw_evm/tests/barz.rs
// test_get_init_code (line 719).

/// BSC testnet factory used in barz.rs test_get_init_code.
const _testFactory = '0x3fC708630d85A3B5ec217E53100eC2b735d4f800';
const _testVerificationFacet = '0x6BF22ff186CC97D88ECfbA47d1473a234CEBEFDf';
const _testAccountFacet = '0x0000000000000000000000000000000000000001';
const _testFacetRegistry = '0x0000000000000000000000000000000000000002';
const _testDefaultFallback = '0x0000000000000000000000000000000000000003';
const _testEntryPointV06 = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';
const _testEntryPointV07 = '0x0000000071727De22E5E9d8BAf0edAc6f37da032';

// barz.rs line 719–731: 65-byte uncompressed P-256 public key (with 04 prefix)
// Our API takes 64 bytes (X‖Y, no prefix).
const _testPubKeyHex =
    'e6f4e0351e2f556fd7284a9a033832bae046ac31fd529ad02ab6220870624b79'
    'eb760e718fdaed7a037dd1d77a561759cee9f2706eb55a729dc953e0d5719b02';

// Expected v0.6 initCode from barz.rs line 727 (salt=0, factory + calldata).
const _expectedInitCodeHex =
    '3fc708630d85a3b5ec217e53100ec2b735d4f800'
    '296601cd'
    '0000000000000000000000006bf22ff186cc97d88ecfba47d1473a234cebefdf'
    '0000000000000000000000000000000000000000000000000000000000000060'
    '0000000000000000000000000000000000000000000000000000000000000000'
    '0000000000000000000000000000000000000000000000000000000000000041'
    '04e6f4e0351e2f556fd7284a9a033832bae046ac31fd529ad02ab6220870624b79'
    'eb760e718fdaed7a037dd1d77a561759cee9f2706eb55a729dc953e0d5719b02'
    '00000000000000000000000000000000000000000000000000000000000000';

// Placeholder creation code for the test deployment (not used for address
// computation in pure-Dart tests, only for round-trip in FFI tests).
const _testBarzCreationCodeHex = '0x60806040'; // minimal placeholder

// ── Helper ────────────────────────────────────────────────────────────────

Uint8List _fromHex(String hex) {
  var s = hex.replaceAll(' ', '');
  if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(Uint8List b) =>
    b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

BarzDeployment _testDeployment() => const BarzDeployment(
      chainId: 97,
      factory: _testFactory,
      verificationFacet: _testVerificationFacet,
      accountFacet: _testAccountFacet,
      facetRegistry: _testFacetRegistry,
      defaultFallback: _testDefaultFallback,
      entryPointV06: _testEntryPointV06,
      entryPointV07: _testEntryPointV07,
      barzCreationCodeHex: _testBarzCreationCodeHex,
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  // ── BarzDeployment registry ──────────────────────────────────────────────

  group('BarzDeployments registry', () {
    test('byChainId covers exactly 6 chains', () {
      expect(BarzDeployments.byChainId, hasLength(6));
    });

    test('required chain IDs are present', () {
      const expected = {1, 11155111, 8453, 42161, 10, 137};
      expect(BarzDeployments.byChainId.keys.toSet(), equals(expected));
    });

    test('all deployments share the same factory address', () {
      const factory = '0x729c310186a57833f622630a16d13f710b83272a';
      for (final d in BarzDeployments.byChainId.values) {
        expect(d.factory.toLowerCase(), equals(factory));
      }
    });

    test('all deployments share the same verificationFacet', () {
      final vf = '0xeE1AF8E967eC04C84711842796A5E714D2FD33e6'.toLowerCase();
      for (final d in BarzDeployments.byChainId.values) {
        expect(d.verificationFacet.toLowerCase(), equals(vf));
      }
    });

    test('barzCreationCodeHex starts with 0x and has even length', () {
      for (final d in BarzDeployments.byChainId.values) {
        expect(d.barzCreationCodeHex, startsWith('0x'));
        expect((d.barzCreationCodeHex.length - 2).isEven, isTrue);
      }
    });

    test('mainnet barzCreationCodeHex decodes to 1362 bytes', () {
      final hex = BarzDeployments.mainnet.barzCreationCodeHex;
      final byteLen = (hex.length - 2) ~/ 2;
      expect(byteLen, equals(1362));
    });

    test('equality is by chainId + factory', () {
      const a = BarzDeployment(
        chainId: 1,
        factory: '0xabc',
        verificationFacet: '',
        accountFacet: '',
        facetRegistry: '',
        defaultFallback: '',
        entryPointV06: '',
        entryPointV07: '',
        barzCreationCodeHex: '',
      );
      const b = BarzDeployment(
        chainId: 1,
        factory: '0xabc',
        verificationFacet: 'different',
        accountFacet: '',
        facetRegistry: '',
        defaultFallback: '',
        entryPointV06: '',
        entryPointV07: '',
        barzCreationCodeHex: '',
      );
      expect(a, equals(b));
    });

    test('named constants are enumerable via byChainId', () {
      expect(BarzDeployments.byChainId[1], equals(BarzDeployments.mainnet));
      expect(
          BarzDeployments.byChainId[8453], equals(BarzDeployments.base));
    });
  });

  // ── PasskeyBarzAddress input validation ──────────────────────────────────

  group('PasskeyBarzAddress.compute — input validation (pure Dart)', () {
    test('throws ArgumentError when pubKey is 63 bytes (too short)', () {
      expect(
        () => PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(63),
          0,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('64 bytes'),
          ),
        ),
      );
    });

    test('throws ArgumentError when pubKey is 65 bytes (with 04 prefix)', () {
      expect(
        () => PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(65),
          0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws RangeError when salt is negative', () {
      expect(
        () => PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(64),
          -1,
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws RangeError when salt exceeds uint32 max', () {
      expect(
        () => PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(64),
          0x1_0000_0000,
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('accepts salt = 0 without throwing (pure validation only)', () {
      // We cannot call the full function without FFI, but we CAN verify that
      // no ArgumentError or RangeError is thrown for boundary-valid inputs.
      // The FFI call itself will throw a StateError or similar if the native
      // lib is absent, which is distinct from our input-validation checks.
      Object? thrown;
      try {
        PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(64),
          0,
        );
      } on RangeError catch (e) {
        thrown = e;
      } on ArgumentError catch (e) {
        thrown = e;
      } catch (_) {
        // Other errors (FFI / BarzAddressMismatchError) are expected on
        // macOS hosts without the native library. Not ArgumentError/RangeError.
      }
      expect(thrown, isNull, reason: 'No input-validation error for salt=0');
    });

    test('accepts salt = 0xFFFFFFFF without input-validation error', () {
      Object? thrown;
      try {
        PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          Uint8List(64),
          0xFFFFFFFF,
        );
      } on RangeError catch (e) {
        thrown = e;
      } on ArgumentError catch (e) {
        thrown = e;
      } catch (_) {}
      expect(thrown, isNull, reason: 'No input-validation error for max salt');
    });
  });

  // ── BarzInitCode input validation (pure Dart) ────────────────────────────

  group('BarzInitCode.forPasskey — input validation (pure Dart)', () {
    test('throws ArgumentError when pubKey is not 64 bytes', () {
      expect(
        () => BarzInitCode.forPasskey(_testDeployment(), Uint8List(65), 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws RangeError for negative salt', () {
      expect(
        () => BarzInitCode.forPasskey(_testDeployment(), Uint8List(64), -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws RangeError for salt > 0xFFFFFFFF', () {
      expect(
        () => BarzInitCode.forPasskey(
            _testDeployment(), Uint8List(64), 0x1_0000_0000),
        throwsA(isA<RangeError>()),
      );
    });
  });

  // ── BarzInitCode golden vector (FFI-dependent) ───────────────────────────

  group('BarzInitCode.forPasskey — golden vector from barz.rs', () {
    test(
      'salt=0: initCodeV06 matches barz.rs test_get_init_code expected output',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        expect(pubKey64, hasLength(64));

        final result =
            BarzInitCode.forPasskey(_testDeployment(), pubKey64, 0);

        final actual = _toHex(result.initCodeV06);
        // Compare normalised (lowercase, no 0x).
        final expected = _expectedInitCodeHex
            .toLowerCase()
            .replaceAll(' ', '');
        expect(actual, equals(expected));
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'salt=1: initCodeV06 last word (salt slot) = 0x01',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        final result =
            BarzInitCode.forPasskey(_testDeployment(), pubKey64, 1);

        // The salt (uint256 = 1) occupies bytes 100..131 in the calldata
        // (3rd ABI argument). In 0-indexed big-endian 32-byte slot, the value
        // 1 is at position [31].
        final saltSlot = result.initCodeV06.sublist(
            20 + 4 + 64 + 32, 20 + 4 + 64 + 32 + 32); // factory+sel+vf+off+salt
        expect(saltSlot.last, equals(1),
            reason: 'salt=1 should appear in the last byte of the salt slot');
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'v0.7 split: initCodeV06 == factoryV07_bytes ‖ factoryDataV07',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        final result =
            BarzInitCode.forPasskey(_testDeployment(), pubKey64, 0);

        final reconstructed = Uint8List(
            result.initCodeV06.length)
          ..setRange(0, 20,
              _fromHex(result.factoryV07.substring(2))) // strip 0x
          ..setRange(20, result.initCodeV06.length, result.factoryDataV07);

        expect(_toHex(reconstructed), equals(_toHex(result.initCodeV06)));
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'factoryV07 equals deployment.factory (lower-case comparison)',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        final dep = _testDeployment();
        final result = BarzInitCode.forPasskey(dep, pubKey64, 0);
        expect(
          result.factoryV07.toLowerCase(),
          equals(dep.factory.toLowerCase()),
        );
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  // ── PasskeyBarzAddress round-trip (FFI-dependent) ─────────────────────────

  group('PasskeyBarzAddress.compute — round-trip verification (FFI)', () {
    test(
      'both paths agree for arbitrary P-256 pubkey + mainnet deployment',
      () {
        // Use the test pubkey (64 bytes X‖Y).
        final pubKey64 = _fromHex(_testPubKeyHex);

        // This calls both path A (TWBarz.getCounterfactualAddress) and
        // path B (manual ABI + keccak256 + create2Address). If they disagree,
        // BarzAddressMismatchError is thrown.
        final address = PasskeyBarzAddress.compute(
          BarzDeployments.mainnet,
          pubKey64,
          0,
        );

        // Address must be a 0x-prefixed 42-char EVM address.
        expect(address, matches(r'^0x[0-9a-fA-F]{40}$'));
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'same pubkey + same salt across all 6 chains produces same address '
      '(shared factory → CREATE2 formula identical)',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        final addresses = <int, String>{};
        for (final entry in BarzDeployments.byChainId.entries) {
          addresses[entry.key] =
              PasskeyBarzAddress.compute(entry.value, pubKey64, 0);
        }

        // All addresses should be identical (same factory, same salt, same pubkey).
        final first = addresses.values.first;
        for (final addr in addresses.values) {
          expect(addr.toLowerCase(), equals(first.toLowerCase()));
        }
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'different salt → different address (Pitfall 9 — salt uniqueness)',
      () {
        final pubKey64 = _fromHex(_testPubKeyHex);
        final addr0 = PasskeyBarzAddress.compute(
            BarzDeployments.mainnet, pubKey64, 0);
        final addr1 = PasskeyBarzAddress.compute(
            BarzDeployments.mainnet, pubKey64, 1);
        expect(addr0.toLowerCase(), isNot(equals(addr1.toLowerCase())));
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  // ── Public API surface (barrel exports) ─────────────────────────────────

  group('barrel export coverage', () {
    test('BarzDeployment is exported from ceres_wallet_core.dart', () {
      // Verifies that the symbol is accessible from the public barrel.
      expect(BarzDeployments.mainnet, isA<BarzDeployment>());
    });

    test('BarzAddressMismatchError is exported from ceres_wallet_core.dart',
        () {
      // Construction should not throw.
      final err = BarzAddressMismatchError('test');
      expect(err.toString(), contains('test'));
    });
  });
}
