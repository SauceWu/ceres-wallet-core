// FFI reachability discipline. Phase 6, Plan 03. See:
//   .planning/phases/06-ffi-hardening-test-fixtures/06-CONTEXT.md (D-05, D-06, D-07)
//   .planning/research/PITFALLS.md (Pitfall 8: Finalizer GC mid-await)
//
// ---------------------------------------------------------------------------
// WHY THIS FILE EXISTS
// ---------------------------------------------------------------------------
// Dart 3 release-mode escape analysis is permitted to deem a Dart object
// unreachable once its last *Dart-level* read has completed. For a wrapper
// class like `TWPrivateKey` that owns a native handle via `Finalizer`, this
// means the `Finalizer` callback (`TWPrivateKeyDelete`) can fire while the
// wrapper's `.pointer` is still being read inside an FFI call that has
// yielded across an `await`. The pointer is freed; the next FFI call dereferences
// freed memory. On iOS this surfaces as SIGSEGV; on Android it can be silent
// memory corruption.
//
// PROBLEM SHAPE (paraphrased from PITFALLS.md Pitfall 8):
//   final pk = TWPrivateKey.createWithData(bytes);   // (1) wrapper holds Finalizer
//   await someAsyncIO();                              // (2) Dart may decide pk is dead
//   final sig = pk.sign(digest, TWCurveSECP256k1);    // (3) reads pk._ptr — UAF if (2) GC'd
//
// FIX: anchor the wrapper's reachability past the last FFI read by passing
// it to a function the Dart VM cannot prove is a no-op:
//
//   final pk = TWPrivateKey.createWithData(bytes);
//   try {
//     await someAsyncIO();
//     final sig = pk.sign(digest, TWCurveSECP256k1);
//     return sig;
//   } finally {
//     keepAlive(pk);   // <- forces pk to live until at least here
//   }
//
// Calling `keepAlive` in a `finally` block guarantees the local is live for
// the entire try-block, including across every `await`.
//
// ---------------------------------------------------------------------------
// WHEN TO USE keepAlive (D-06)
// ---------------------------------------------------------------------------
// (a) ANY function that crosses an `await` while holding a wrapper that
//     bears a native handle. Wrapper types subject to this rule include
//     (non-exhaustive, all from Phase 5 / v0.2.0):
//       - TWPrivateKey, TWPublicKey, TWStoredKey
//       - TWAnyAddress
//       - TWHDWallet, TWMnemonic
//       - any TW* type that declares a Finalizer<Pointer<raw.X>> at
//         the file's top.
//     Pure-Dart wrappers without a Finalizer (signers / builders / encoders
//     introduced in Phase 7+) do NOT need keepAlive — they own no native
//     handle.
//
// (b) Inside a loop that performs FFI calls and is followed by an `await`:
//     the loop's induction variable can be GC-eligible the moment the loop
//     body finishes its last read. If the variable references a wrapper
//     and the surrounding function awaits afterward, anchor with
//     `keepAlive(loopVar)` after the loop or in the enclosing `finally`.
//
// ---------------------------------------------------------------------------
// MANDATORY CONSUMERS (per D-06)
// ---------------------------------------------------------------------------
// Phase 11 (PasskeySigner): every implementation that holds a TWPublicKey
// across the platform passkey ceremony's `await signWithPlatform(...)` MUST
// wrap the body in try/finally with `keepAlive(pubkey)` in the finally.
// Phase 12 (Erc4337Builder): every method that holds a TWBarz-derived
// input across an `await` (e.g. an injected `EthCodeChecker` callback that
// returns Future<bool>) MUST keepAlive the relevant wrapper.
//
// ---------------------------------------------------------------------------
// WHY NOT package:ffi's reachability primitives (D-07)
// ---------------------------------------------------------------------------
// package:ffi exposes `Arena` for scoped memory allocation, NOT a
// cross-await reachability barrier. Adding the dependency for the
// reachability problem would be unjustified weight; this hand-rolled
// helper is ~5 lines and zero new pubspec entries (D-08, D-11).
//
// ---------------------------------------------------------------------------
// WHY THIS FILE IS NOT IN THE BARREL
// ---------------------------------------------------------------------------
// The leading underscore in the filename (`_ffi_reachability.dart`) signals:
// internal helper, no public surface. lib/ceres_wallet_core.dart does NOT
// re-export it. Consumers inside the package use the direct path:
//   import 'package:ceres_wallet_core/src/_ffi_reachability.dart' show keepAlive;
//
// Note on naming: D-05 uses the spelling `_keepAlive` to evoke "this is
// intentionally private at the call site." But Dart treats top-level
// identifiers prefixed with `_` as library-private — making them
// unimportable. We resolve this by exporting `keepAlive` (no underscore)
// here, and downstream callers may bind it locally if they prefer the
// visual emphasis:
//   import 'package:ceres_wallet_core/src/_ffi_reachability.dart'
//       show keepAlive;
//   void _keepAlive(Object o) => keepAlive(o);  // optional local alias
library;

/// Reachability barrier. Forces the Dart VM to keep [o] alive at least
/// through the program point where this is called. Does nothing
/// observable: returns void, does not read [o]'s fields, does not throw.
///
/// The `@pragma('vm:never-inline')` annotation discourages the compiler
/// from removing this call as a no-op. Combined with the side-effecting
/// `o.hashCode` read (which the compiler cannot prove is pure for an
/// arbitrary Object), this is robust against Dart 3 escape analysis in
/// release builds. Plan 06-04's release-mode smoke test exercises this
/// path on a real TWPrivateKey held across a long `await`.
@pragma('vm:never-inline')
void keepAlive(Object o) {
  // Read a property the compiler cannot prove is pure. `hashCode` on
  // Object is virtual and may be overridden, so the compiler must
  // emit the call. The result is discarded but the side-effect (which
  // includes "loaded the object header") anchors `o`'s liveness.
  // ignore: unused_local_variable
  final _ = o.hashCode;
}
