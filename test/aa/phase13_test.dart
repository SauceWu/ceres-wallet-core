// Tests for Phase 13: Eip7702Upgrader, BarzDiamondCut, BarzSessionKey,
// PasskeyBarzAddress.acrossChains.
//
// D-12 compliance: FFI-dependent tests use
//   skip: 'macOS host dylib unavailable — see TODO(P13)'
//
// Pure-Dart tests (input validation, type safety, proto structure) run
// unconditionally.
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Eip7702Upgrader ────────────────────────────────────────────────────────

  group('Eip7702Upgrader — type safety (Pitfall 1)', () {
    test('authorizationHash returns 32 bytes (FFI)', () async {
      final hash = Eip7702Upgrader.authorizationHash(
        chainId: Uint8List.fromList([0x01]),
        contractAddress: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
        nonce: Uint8List.fromList([0x00]),
      );
      expect(hash.length, equals(32));
    },
        skip: 'macOS host dylib unavailable — see TODO(P13)');

    test('buildAuthorization throws ArgumentError for PasskeySigner', () {
      final passkeySigner = PasskeySigner(
        adapter: (challenge) async => PasskeyAssertion(
          derSignature: Uint8List(72),
          challenge: challenge,
          authenticatorData: Uint8List(37),
          clientDataJSON: '{}',
        ),
      );
      expect(
        () => Eip7702Upgrader.buildAuthorization(
          chainId: Uint8List.fromList([0x01]),
          contractAddress: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
          nonce: Uint8List.fromList([0x00]),
          signer: passkeySigner,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Secp256k1Signer'),
          ),
        ),
      );
    });

    test('Eip7702Authorization carries all fields', () {
      final sig = Secp256k1Signature.fromRsv(Uint8List(65));
      final auth = Eip7702Authorization(
        chainId: Uint8List.fromList([0x01]),
        contractAddress: '0xAddr',
        nonce: Uint8List.fromList([0x00]),
        signature: sig,
      );
      expect(auth.contractAddress, equals('0xAddr'));
      expect(auth.signature, isA<Secp256k1Signature>());
    });
  });

  // ── BarzDiamondCut ────────────────────────────────────────────────────────

  group('BarzDiamondCut — input validation', () {
    test('throws ArgumentError for selector != 4 bytes', () {
      expect(
        () => BarzDiamondCut.encode(
          adds: [
            FacetCutSpec(
              facetAddress: '0x0000000000000000000000000000000000000001',
              functionSelectors: [Uint8List(3)], // wrong length
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty cuts returns bytes (FFI)', () {
      // With no cuts, the proto payload is minimal. This needs FFI to call
      // TWBarz.getDiamondCutCode. Test the call doesn't throw on pure-Dart path.
      // Actually getDiamondCutCode is an FFI call... so skip for macOS.
    }, skip: 'macOS host dylib unavailable — see TODO(P13)');
  });

  group('BarzDiamondCut — FacetCutSpec', () {
    test('FacetCutSpec stores facetAddress and selectors', () {
      final sel = Uint8List.fromList([0xAB, 0xCD, 0xEF, 0x12]);
      final spec = FacetCutSpec(
        facetAddress: '0x1234567890123456789012345678901234567890',
        functionSelectors: [sel],
      );
      expect(spec.facetAddress,
          equals('0x1234567890123456789012345678901234567890'));
      expect(spec.functionSelectors.length, equals(1));
      expect(spec.functionSelectors[0], equals(sel));
    });
  });

  // ── BarzSessionKey ────────────────────────────────────────────────────────

  group('BarzSessionKey.installCalldata', () {
    test('throws ArgumentError for invalid key address', () {
      expect(
        () => BarzSessionKey.installCalldata(
          key: 'not-an-address',
          validUntil: BigInt.from(9999999999),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws RangeError for negative validUntil', () {
      expect(
        () => BarzSessionKey.installCalldata(
          key: '0x0000000000000000000000000000000000000001',
          validUntil: BigInt.from(-1),
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('calldata starts with addSessionKey selector (pure-Dart, FFI)', () {
      // addSessionKey(address,uint256,address[]) = keccak256[:4]
      // We compute the expected selector using the same ABI encoding path.
      // This is an FFI test since TWEthereumAbi.encode requires native lib.
      final calldata = BarzSessionKey.installCalldata(
        key: '0x0000000000000000000000000000000000000001',
        validUntil: BigInt.from(9999999999),
      );
      expect(calldata.length, greaterThan(4));
      // The first 4 bytes should be the selector for addSessionKey(address,uint256,address[])
      // We can't compute the expected selector without FFI, but we verify it's non-zero.
      final selector = calldata.sublist(0, 4);
      expect(selector.any((b) => b != 0), isTrue,
          reason: 'Selector must be non-zero');
    }, skip: 'macOS host dylib unavailable — see TODO(P13)');

    test('functionSignature constant is documented ABI string', () {
      expect(
        BarzSessionKey.functionSignature,
        equals('addSessionKey(address,uint256,address[])'),
      );
    });
  });

  // ── PasskeyBarzAddress.acrossChains ───────────────────────────────────────

  group('PasskeyBarzAddress.acrossChains — input validation', () {
    test('throws ArgumentError for unregistered chainId', () {
      expect(
        () => PasskeyBarzAddress.acrossChains(
          Uint8List(64),
          0,
          [999999], // no deployment for this chain
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for pubKey != 64 bytes', () {
      expect(
        () => PasskeyBarzAddress.acrossChains(
          Uint8List(63),
          0,
          [1],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws RangeError for invalid salt', () {
      expect(
        () => PasskeyBarzAddress.acrossChains(
          Uint8List(64),
          -1,
          [1],
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('returns map with one entry per chainId (FFI)', () {
      final result = PasskeyBarzAddress.acrossChains(
        Uint8List(64),
        0,
        [1, 137], // mainnet + polygon
      );
      expect(result.length, equals(2));
      expect(result.containsKey(1), isTrue);
      expect(result.containsKey(137), isTrue);
    }, skip: 'macOS host dylib unavailable — see TODO(P13)');

    test('empty chainIds returns empty map', () {
      // Pure Dart: no FFI needed for empty list
      final result = PasskeyBarzAddress.acrossChains(Uint8List(64), 0, []);
      expect(result, isEmpty);
    });
  });
}
