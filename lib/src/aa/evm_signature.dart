/// Sealed union of every `EvmSignature` subtype the AA layer produces.
///
/// Decisions: D-14 (sealed Dart 3 union, two `final` subclasses, `extends`
/// not `implements`), D-15 (`Secp256k1Signature` carries 32-byte `r`,
/// 32-byte `s`, 1-byte `v`; convenience `rsv` getter; `fromRsv` factory),
/// D-30 (this file lives under the new `lib/src/aa/` subdirectory — see
/// the justification table below), D-33 (no `TW` prefix on AA-namespace
/// class names; this file is pure-Dart composition layer with no native
/// counterpart).
///
/// Switch-exhaustiveness over this sealed union is the prevention
/// mechanism for Pitfall 1 (raw r‖s vs Barz-formatted blob) — every
/// consumer (Phase 12 `attachSignature`) must handle both variants
/// explicitly. Adding a third variant in v1.2 is a breaking change by
/// design: every downstream `switch` is forced to update.
///
/// Pure Dart. No native handle. No `Finalizer`. (Architecture research,
/// 2026-04-29: pure-Dart composition layer; `Finalizer` is for native
/// handle wrappers ONLY.)
///
/// **D-30 — `lib/src/aa/` subdirectory justification:**
///
/// | Property                                   | flat `tw_*` files        | new `aa/` files                      |
/// | ------------------------------------------ | ------------------------ | ------------------------------------ |
/// | Wraps a Trust Wallet Core C type?          | YES (TWBarz, TWPrivateKey, …) | NO — pure-Dart composition           |
/// | Class name `TW`-prefixed?                  | YES                      | NO (EvmSigner, Secp256k1Signature, …) |
/// | Contains `Finalizer<Pointer<raw.X>>`?      | usually                  | NEVER (no native handles)            |
/// | Phase                                      | v1.0 + Phase 5           | v1.1 AA (Phase 7+)                   |
///
/// The `aa/` subdirectory marks AA-namespace composition layer files
/// distinct from flat `lib/src/tw_*.dart` TW wrappers.
library;

import 'dart:async';
import 'dart:typed_data';

// `package:meta` is a transitive dependency of the Flutter SDK (D-11
// carry-forward from Phase 6: pubspec.yaml stays unchanged). The
// `depend_on_referenced_packages` lint flags transitive imports; the
// ignore is intentional and scoped to this single line.
// ignore: depend_on_referenced_packages
import 'package:meta/meta.dart';

import '../../bindings/ceres_wallet_core_bindings.dart' show TWCurve;
import '../_ffi_reachability.dart' show keepAlive;
import '../tw_barz.dart';
import '../tw_private_key.dart';
import 'passkey_assertion.dart';

// `passkey_signature.dart`, `evm_signer.dart`, `secp256k1_signer.dart`, and
// `passkey_signer.dart` are bound into THIS library via `part` (not `import`)
// because Dart 3 sealed-class semantics require every direct subtype of
// `EvmSignature` to live in the SAME library as the sealed base. The `part`
// directive collapses the files into a single anonymous library while
// preserving per-file separation. `evm_signer.dart` joins this library so
// that its library-private template method `_doSign` (leading underscore) is
// accessible to `Secp256k1Signer` and `PasskeySigner`.
//
// All imports needed by the parts (`@protected` from `package:meta`,
// `dart:async`, `dart:typed_data`, `TWCurve` from bindings, `keepAlive`,
// `TWPrivateKey`, `TWBarz`, `PasskeyAssertion`) are declared HERE at the
// library root — `part of` files cannot have their own imports.
part 'passkey_signature.dart';
part 'evm_signer.dart';
part 'secp256k1_signer.dart';
part 'passkey_signer.dart';

/// Sealed union of every signature shape the AA layer produces.
/// Switch over this union is exhaustiveness-checked by Dart 3.
sealed class EvmSignature {
  const EvmSignature();
}

/// 65-byte secp256k1 ECDSA signature (`r ‖ s ‖ v`).
/// `v` is the recovery byte (TWPrivateKey returns `0x1b`/`0x1c` for Ethereum).
final class Secp256k1Signature extends EvmSignature {
  Secp256k1Signature({
    required this.r,
    required this.s,
    required this.v,
  })  : assert(r.length == 32, 'r must be exactly 32 bytes'),
        assert(s.length == 32, 's must be exactly 32 bytes');

  /// Parse a TW-shaped 65-byte buffer (`r ‖ s ‖ v`).
  /// `TWPrivateKey.sign(digest, TWCurve.TWCurveSECP256k1)` returns this layout.
  factory Secp256k1Signature.fromRsv(Uint8List rsv65) {
    assert(rsv65.length == 65,
        'rsv buffer must be exactly 65 bytes (got ${rsv65.length})');
    return Secp256k1Signature(
      r: Uint8List.fromList(rsv65.sublist(0, 32)),
      s: Uint8List.fromList(rsv65.sublist(32, 64)),
      v: rsv65[64],
    );
  }

  final Uint8List r;
  final Uint8List s;
  final int v;

  /// Canonical 65-byte concatenation `r ‖ s ‖ [v]`.
  Uint8List get rsv {
    final out = Uint8List(65);
    out.setRange(0, 32, r);
    out.setRange(32, 64, s);
    out[64] = v;
    return out;
  }
}
