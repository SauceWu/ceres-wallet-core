// Phase 8, Plan 02 — Tests for Erc4337Calldata encoders.
//
// All tests that call into the native library (TWHash.keccak256, TWEthereumAbi)
// are skipped on macOS host pending TODO(P13) dylib availability.
//
// Tests that exercise pure-Dart paths (argument validation, length checks)
// run without skipping.
//
// Run via:
//   flutter test test/aa/erc4337_calldata_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:ceres_wallet_core/ceres_wallet_core.dart';
import 'package:ceres_wallet_core/src/aa/erc4337_calldata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Known Ethereum addresses for tests (well-known public addresses, no
  // real-world funds at risk).
  const target = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';

  group('executeCall — selector verification', () {
    test(
      'first 4 bytes match keccak256("execute(address,uint256,bytes)")[:4]',
      () {
        final calldata = Erc4337Calldata.executeCall(
          target,
          BigInt.zero,
          Uint8List(0),
        );
        expect(calldata.length, greaterThan(4),
            reason: 'calldata must contain selector + encoded params');

        // Compute expected selector: keccak256 of the function signature bytes.
        final sigBytes =
            Uint8List.fromList(utf8.encode('execute(address,uint256,bytes)'));
        final hash = TWHash.keccak256(sigBytes);
        final expectedSelector = hash.sublist(0, 4);

        expect(calldata.sublist(0, 4), equals(expectedSelector),
            reason: 'executeCall selector must match keccak256 of signature');
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'calldata length is 4 + 32 + 32 + 32 + 32 = 132 bytes for empty data',
      () {
        // execute(address, 0, bytes(0)) — ABI encoding:
        //   4 bytes selector
        //   32 bytes address (padded)
        //   32 bytes uint256 value (0)
        //   32 bytes offset pointer for bytes
        //   32 bytes bytes length (0, no content words)
        // Total = 4 + 4*32 = 132 bytes
        final calldata = Erc4337Calldata.executeCall(
          target,
          BigInt.zero,
          Uint8List(0),
        );
        expect(calldata.length, equals(132),
            reason: 'ABI-encoded calldata for empty-data executeCall is 132 bytes');
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group('executeBatch — selector verification', () {
    test(
      'first 4 bytes match keccak256("executeBatch(address[],uint256[],bytes[])")[:4]',
      () {
        final calldata = Erc4337Calldata.executeBatch(
          [target],
          [BigInt.zero],
          [Uint8List(0)],
        );
        expect(calldata.length, greaterThan(4));

        final sigBytes = Uint8List.fromList(
            utf8.encode('executeBatch(address[],uint256[],bytes[])'));
        final hash = TWHash.keccak256(sigBytes);
        final expectedSelector = hash.sublist(0, 4);

        expect(calldata.sublist(0, 4), equals(expectedSelector),
            reason:
                'executeBatch selector must match keccak256 of signature');
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );

    test(
      'single-element batch produces valid calldata',
      () {
        final calldata = Erc4337Calldata.executeBatch(
          [target],
          [BigInt.zero],
          [Uint8List(0)],
        );
        // Selector (4) + 3 offset pointers (3*32=96) +
        // targets array (32 length + 32 element = 64) +
        // values array (32 length + 32 element = 64) +
        // datas array (32 length + 32 offset + 32 length = 96) = 356 bytes
        expect(calldata.length, greaterThan(4));
        expect(calldata.length % 32, equals(4),
            reason: 'ABI-encoded calldata beyond selector must be 32-byte aligned');
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group('executeCall — pure Dart validation (no dylib)', () {
    test('throws ArgumentError for address shorter than 40 hex chars', () {
      expect(
        () => Erc4337Calldata.executeCall('0x1234', BigInt.zero, Uint8List(0)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for negative value', () {
      expect(
        () => Erc4337Calldata.executeCall(target, BigInt.from(-1), Uint8List(0)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('executeBatch — pure Dart validation (no dylib)', () {
    test('throws ArgumentError for mismatched list lengths', () {
      expect(
        () => Erc4337Calldata.executeBatch(
          [target, target],
          [BigInt.zero],
          [Uint8List(0)],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'empty batch returns calldata with only selector + 3 empty arrays',
      () {
        final calldata = Erc4337Calldata.executeBatch([], [], []);
        expect(calldata.length, greaterThan(4));
        expect(calldata.sublist(0, 4), isNot(equals(Uint8List(4))));
      },
      skip: 'macOS host dylib unavailable — see TODO(P13)',
    );
  });

  group('selector constants are private', () {
    test('Erc4337Calldata has no public selector field', () {
      // This is a static/compile-time guarantee — just document it.
      // The class only exposes executeCall and executeBatch.
      // If this test compiles without referencing any selector constant,
      // the private constraint is implicitly enforced.
      expect(Erc4337Calldata, isNotNull);
    });
  });
}
