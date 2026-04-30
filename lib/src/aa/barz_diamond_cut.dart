/// Diamond-cut calldata encoder for Barz modular facet management.
///
/// AA-13: Provides [BarzDiamondCut.encode] which builds a `DiamondCutInput`
/// proto3 payload and delegates to `TWBarz.getDiamondCutCode`.
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

import '../tw_barz.dart';

/// Specifies a single facet operation for [BarzDiamondCut.encode].
///
/// [facetAddress] — the contract address of the facet to add, remove, or
/// replace.
///
/// [functionSelectors] — list of 4-byte function selectors to register for
/// this facet. Each element must be exactly 4 bytes.
final class FacetCutSpec {
  /// Creates a [FacetCutSpec].
  const FacetCutSpec({
    required this.facetAddress,
    required this.functionSelectors,
  });

  /// The facet contract address (EIP-55 hex, 42 chars).
  final String facetAddress;

  /// Function selectors to register. Each must be exactly 4 bytes.
  final List<Uint8List> functionSelectors;
}

/// Static encoder for EIP-2535 diamond-cut calldata targeting Barz smart
/// accounts.
///
/// Builds a `DiamondCutInput` proto3 message and delegates to
/// `TWBarz.getDiamondCutCode` for final ABI encoding.
abstract final class BarzDiamondCut {
  // FacetCutAction enum values (from Barz.proto: ADD=0, REPLACE=1, REMOVE=2).
  static const int _actionAdd = 0;
  static const int _actionReplace = 1;
  static const int _actionRemove = 2;

  /// Encodes a `diamondCut` call for the given [adds], [removes], and
  /// [replaces] facet operations.
  ///
  /// [adds] — facet operations to ADD (new function → facet mappings).
  /// [removes] — facet operations to REMOVE (de-register selectors).
  /// [replaces] — facet operations to REPLACE (redirect selectors to new
  ///   facet).
  ///
  /// [initAddress] — address to call with [initData] after the cut; use
  ///   the zero address (default) for a cut with no init call.
  ///
  /// [initData] — bytes to pass to [initAddress]'s init function (optional).
  ///
  /// Returns the complete ABI-encoded `diamondCut(...)` calldata.
  static Uint8List encode({
    List<FacetCutSpec> adds = const [],
    List<FacetCutSpec> removes = const [],
    List<FacetCutSpec> replaces = const [],
    String initAddress = '0x0000000000000000000000000000000000000000',
    Uint8List? initData,
  }) {
    for (final cut in adds) {
      _validateSelectors(cut);
    }
    for (final cut in removes) {
      _validateSelectors(cut);
    }
    for (final cut in replaces) {
      _validateSelectors(cut);
    }

    // Assemble the ordered list: adds first, then replaces, then removes.
    // This ordering matches the typical EIP-2535 diamondCut call convention.
    final allCuts = [
      ..._makeCuts(adds, _actionAdd),
      ..._makeCuts(replaces, _actionReplace),
      ..._makeCuts(removes, _actionRemove),
    ];

    final proto = _serializeDiamondCutInput(
      allCuts,
      initAddress,
      initData ?? Uint8List(0),
    );
    return TWBarz.getDiamondCutCode(proto);
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  static void _validateSelectors(FacetCutSpec cut) {
    if (cut.functionSelectors.isEmpty) {
      throw ArgumentError.value(
        cut,
        'cut',
        'FacetCutSpec.functionSelectors must not be empty '
            '(facet: ${cut.facetAddress}). '
            'EIP-2535 requires at least one selector per FacetCut.',
      );
    }
    for (final sel in cut.functionSelectors) {
      if (sel.length != 4) {
        throw ArgumentError.value(
          sel,
          'functionSelector',
          'must be exactly 4 bytes (got ${sel.length})',
        );
      }
    }
  }

  static List<({String facetAddress, int action, List<Uint8List> selectors})>
      _makeCuts(List<FacetCutSpec> specs, int action) {
    return specs
        .map((s) => (
              facetAddress: s.facetAddress,
              action: action,
              selectors: s.functionSelectors,
            ))
        .toList();
  }

  /// Serialize a list of facet-cut records + init params into proto3 bytes.
  ///
  /// DiamondCutInput proto3 schema (from Barz.proto):
  ///   message DiamondCutInput {
  ///     repeated FacetCut facet_cuts = 1;
  ///     string init_address = 2;
  ///     bytes init_data = 3;
  ///   }
  ///   message FacetCut {
  ///     string facet_address = 1;
  ///     FacetCutAction action = 2;
  ///     repeated bytes function_selectors = 3;
  ///   }
  static Uint8List _serializeDiamondCutInput(
    List<({String facetAddress, int action, List<Uint8List> selectors})> cuts,
    String initAddress,
    Uint8List initData,
  ) {
    final buf = <int>[];

    for (final cut in cuts) {
      final facetCutBytes = _serializeFacetCut(cut);
      // Field 1 (facet_cuts), wire type 2 (LEN)
      buf.addAll(_writeTag(1, 2));
      buf.addAll(_writeVarint(facetCutBytes.length));
      buf.addAll(facetCutBytes);
    }

    // Field 2 (init_address), wire type 2 (LEN) — string
    final initAddrBytes = _encodeUtf8(initAddress);
    buf.addAll(_writeTag(2, 2));
    buf.addAll(_writeVarint(initAddrBytes.length));
    buf.addAll(initAddrBytes);

    // Field 3 (init_data), wire type 2 (LEN) — bytes
    if (initData.isNotEmpty) {
      buf.addAll(_writeTag(3, 2));
      buf.addAll(_writeVarint(initData.length));
      buf.addAll(initData);
    }

    return Uint8List.fromList(buf);
  }

  static Uint8List _serializeFacetCut(
    ({String facetAddress, int action, List<Uint8List> selectors}) cut,
  ) {
    final buf = <int>[];

    // Field 1 (facet_address), wire type 2 (LEN) — string
    final addrBytes = _encodeUtf8(cut.facetAddress);
    buf.addAll(_writeTag(1, 2));
    buf.addAll(_writeVarint(addrBytes.length));
    buf.addAll(addrBytes);

    // Field 2 (action), wire type 0 (VARINT) — enum
    if (cut.action != 0) {
      buf.addAll(_writeTag(2, 0));
      buf.addAll(_writeVarint(cut.action));
    }

    // Field 3 (function_selectors), wire type 2 (LEN) — repeated bytes
    for (final sel in cut.selectors) {
      buf.addAll(_writeTag(3, 2));
      buf.addAll(_writeVarint(sel.length));
      buf.addAll(sel);
    }

    return Uint8List.fromList(buf);
  }

  static List<int> _writeTag(int fieldNumber, int wireType) {
    return _writeVarint((fieldNumber << 3) | wireType);
  }

  static List<int> _writeVarint(int value) {
    final bytes = <int>[];
    while (value > 0x7F) {
      bytes.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7F);
    return bytes;
  }

  static List<int> _encodeUtf8(String s) => utf8.encode(s);
}
