# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — SDK Foundation

**Shipped:** 2026-04-29
**Phases:** 5 | **Plans:** 7 | **Released:** v0.1.0 → v0.2.0 on pub.dev

### What Was Built

- Self-hosted Dart FFI bindings for Trust Wallet Core (Apache 2.0) — ~95% coverage of wallet-relevant FFI surface
- iOS xcframework (arm64 device + simulator) + Android .so (3 ABIs) cross-compiled from trimmed wallet-core fork (31 chains for 4.6.3)
- GitHub Actions CI auto-building native libs + automated GitHub Releases + Dart `build hooks` downloading native libs at `flutter pub get` time
- Drop-in API parity with `wallet_core_bindings` (same class names, same signatures) + unified `CeresWalletCoreInit` initialization
- ERC-4337 / Account Abstraction primitives (`TWBarz` — counterfactual address, init code, signature formatting, EIP-7702)
- WebAuthn / passkey primitives (`TWWebAuthn` — P-256 public key extraction, message reconstruction, r/s decoding)
- Encrypted JSON keystore (`TWStoredKey`, MEW/MetaMask v3 compatible) + mobile-aware `TWKeystoreStorage`
- Solana ATA / Token-2022 / blockhash re-signing, BIP44 typed paths, NaCl crypto_box (X25519 + XSalsa20-Poly1305)

### What Worked

- **Hand-written `dart:ffi` lookups over ffigen** — small interface surface, fully controlled, no codegen friction. Allowed 30+ wrapper classes to be written without tooling fights.
- **Build-hook-based native distribution** — pub.dev publication clean (no large binaries in repo), `flutter pub get` transparently resolves platform binaries. Decoupled binary release cadence from Dart code release cadence.
- **API parity as a hard constraint** — kept the migration cost for wallet_example near zero. Any signature drift was caught early.
- **Daily `chore: sync wallet-core upstream` cadence** — kept wallet-core fork from drifting. v0.1.1–v0.1.6 each absorbed upstream fixes without surprise.
- **CI as reproducibility ground truth** — local build script remained semi-manual but the GitHub Actions workflow encoded the full pipeline. Accepted via override; pragmatic.

### What Was Inefficient

- **Phase 5 ("Expand Wrappers") shipped without ahead-of-time GSD planning.** Code was written, released as v0.2.0, then PLAN/SUMMARY/CONTEXT got reverse-engineered at milestone close (2026-04-29). Worked, but:
  - Lost ahead-of-time threat modeling for keystore I/O, FFI to native crypto, and WalletConnect-bound bytes
  - Coverage estimate ("~76%") in the commit message understated actual delivery (~95%)
  - Required ~30min of forensic doc-writing at milestone close
- **Phase 4 (MIG) was scoped ambiguously** — original criteria mixed producer-side artifacts (this repo) and consumer-side migration (wallet_example repo). Took until milestone close to disambiguate; the producer-side criteria were trivially satisfied from day one, and the consumer-side criteria were never tracked in this repo to begin with.
- **wallet-core 4.4.4 → 4.6.3 upgrade** mid-milestone caused chain count drift (28 → 31). Verification flagged it, then accepted via override. Future upgrades should pin chain count expectations or update the count atomically.
- **Phase 2 build-script reproducibility** stayed semi-manual all milestone. Required override at close. Should have been a tracked tech-debt item from Phase 2 SUMMARY, not a verification surprise.

### Patterns Established

- **One file per public class** under `lib/src/`, mirrored by an `export` line in `lib/ceres_wallet_core.dart`. Made the public API surface trivially auditable (30 exports = 30 public classes).
- **Memory ownership via Dart `Finalizer`** for any wrapper class with a native handle. Caller never needs `dispose()`. Now the default for any new wrapper.
- **TWData / TWString helper modules** (`tw_data_helper.dart`, `tw_string_helper.dart`) hide pointer plumbing — every wrapper uses them. Reduced FFI boilerplate ~60%.
- **Verification overrides with structured `accepted_by` / `accepted_at`** — formal way to acknowledge "this gap is intentional / addressed elsewhere" without lying to the verifier.

### Key Lessons

1. **Plan phases up front, even if you "already know what you'll build".** Phase 5 retrofit took longer than just writing the PLAN would have, and lost the threat-modeling step entirely. v1.1 onwards: strict `/gsd-discuss-phase → /gsd-plan-phase → /gsd-execute-phase` flow.
2. **Producer/consumer split makes ambiguous milestone scope.** When a phase touches another repo, write the boundary into the phase definition (which side owns what) before planning, not after.
3. **Upstream pins are load-bearing.** `wallet-core 4.4.4 → 4.6.3` was the right call but its side-effects (chain count, registry shape) cascaded into BUILD-04. Future upstream bumps should be explicit roadmap items, not in-flight changes.
4. **The hand-written FFI bindings approach scales to 30+ classes.** No need to revisit ffigen for AA work in v1.1.

### Cost Observations

- Sessions: ~5 (estimated from commit grouping)
- Model mix: not tracked
- Notable: Phase 5 retrofit was the most expensive single doc operation of the milestone — pure reverse-engineering against a 1-commit diff. Worth factoring into "do we plan this?" decisions.

---

## Milestone: v1.1 — AA Foundation

**Shipped:** 2026-04-30
**Phases:** 8 (Phase 6–13) | **Plans:** 12 formal + autonomous execution for Phases 9-13

### What Was Built

- Sealed `EvmSignature` union (`Secp256k1Signature` + `PasskeySignature`) with abstract `EvmSigner` single-flight invariant
- `Secp256k1Signer` + `PasskeySigner` concrete implementations; injected adapter pattern keeps SDK platform-free
- `Erc4337Calldata.executeCall` / `.executeBatch` with keccak256-verified selectors
- `BarzDeployments` 6-chain registry + `PasskeyBarzAddress.compute` with mandatory CREATE2 round-trip
- `BarzInitCode.forPasskey` generating v0.6 monolithic and v0.7 split (factory + factoryData)
- `Erc1271Helper` per-(account, chainId) for ERC-1271 personal_sign / typed-data — no EOA ecrecover path
- `Erc4337Builder.v06` / `.v07` named constructors + `attachSignature` sole conversion site + challenge validation
- `Eip7702Upgrader`, `BarzDiamondCut`, `BarzSessionKey`, `PasskeyBarzAddress.acrossChains` — complete AA primitive surface
- 3 code review passes (all phases): 4 Critical, 12 Warning, 12 Info — all Critical + Warning resolved

### What Worked

- **GSD autonomous execution for Phases 9-13** — once Phase 6-8 established patterns, `/gsd-autonomous` delivered Phases 9-13 in a single pass. Pitfall-first research (research phase) paid off in zero architecture surprises.
- **Pitfall-driven design** — the 12 explicitly documented pitfalls from research phase directly translated into sealed unions, single-flight, CREATE2 round-trip, and named constructors. Every pitfall has a code-level enforcement site.
- **Code review discipline** — 3 separate review passes caught a systematic `assert()` → `ArgumentError`/`StateError` issue that spanned every public API boundary. Release-safe validation is now a project-wide standard.
- **`_proto_utils.dart` extraction** — caught during review; eliminates varint encoding drift between two files and sets a model for future proto3 hand-rolling.
- **`@visibleForTesting` exposure pattern** — refactoring `_validateChallenge` to be testable revealed and fixed a real bug (`base64Url.normalize` outside try/catch). Review-driven testability improvement found a production bug.
- **Injected adapter pattern** — `PasskeySigner` has no platform import. SDK tests are fully platform-free. Pattern scales to future signers.

### What Was Inefficient

- **Phase 9-13 missing CONTEXT.md files** — autonomous execution skipped CONTEXT.md generation. Required manual reconstruction (30-40 min) post-execution. `/gsd-autonomous` should generate CONTEXT.md as part of each phase completion hook.
- **`assert()` anti-pattern was systemic** — the same "assert for input validation" pattern appeared in Phases 7, 8, 9, 10, 11, 12, and 13. A project-level linting rule or code review checklist item would have caught this at Phase 7.
- **Review passes were sequential, not concurrent** — Phases 7+8 and Phases 9-13 were reviewed in two separate passes. A single pass covering all phases would have been faster.
- **Autonomous phases had no formal PLAN/SUMMARY artifacts** — makes retroactive auditing harder. `/gsd-autonomous` should at minimum record a summary JSON per phase.

### Patterns Established

- **Release-safe validation standard:** All public API input validation uses `throw ArgumentError(...)` or `throw StateError(...)`, never `assert()`. Applied retroactively to all Phases 7-13.
- **Sealed union for signature types:** `sealed class EvmSignature` with `Secp256k1Signature` and `PasskeySignature` subtypes. No raw byte arrays in public signatures.
- **Single-flight at abstract layer:** `_pending` Future field in `EvmSigner`. Concrete signers inherit for free.
- **CREATE2 round-trip always:** Any counterfactual address computation verifies via `TWEthereumEip1014.create2Address`. No "compute and trust".
- **Injected adapters over platform imports:** `PasskeySigner` takes `Function` — not a plugin. SDK stays platform-pure.
- **`@visibleForTesting` for FFI-gated paths:** Expose private pure-Dart logic via a testable static method when the production code path requires FFI. Enables full coverage without mocking.
- **`_proto_utils.dart` shared module pattern:** Package-private library for cross-file utilities. Prevents varint/proto serialization drift.

### Key Lessons

1. **Pitfall-first research is worth every minute.** The 12 pitfalls from the research phase became the spec for the type system. Zero architecture surprises at execution time.
2. **`assert()` is not validation.** A project-wide linting rule (or enforced code review checklist item) should flag `assert()` in non-test files as a review gate — it's stripped in release mode.
3. **Autonomous execution needs artifact hooks.** `/gsd-autonomous` is powerful but silently skips CONTEXT.md generation. Add a post-phase hook to create at least a stub CONTEXT.md during execution.
4. **Review-driven testability finds bugs.** Refactoring `_validateChallenge` to be `@visibleForTesting`-accessible revealed a real production bug in the same session. "Make it testable" and "fix it" often go together.
5. **Sealed types are the right tool for protocol variant prevention.** `EvmSignature` sealed union meant Pitfall 1 (wrong signature type) was a compile error, not a runtime surprise. Worth the 10-line type definition overhead.

### Cost Observations

- Sessions: ~2 (one autonomous run, one review+fix session)
- Notable: Review pass was the most valuable per-token activity — 4 Critical bugs found that would have caused silent data corruption or bypassed security checks in release builds.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Key Change |
|-----------|--------|------------|
| v1.0 | 5 | Initial GSD adoption; Phase 4/5 shipped without formal planning then retrofit at close |
| v1.1 | 8 | Full GSD flow (Phases 6-8) + autonomous execution (Phases 9-13); 3 code review passes; pitfall-driven design |

### Cumulative Quality

| Milestone | Public Classes | FFI Coverage | Native Platforms |
|-----------|----------------|--------------|------------------|
| v1.0 | ~30 | ~95% wallet-relevant | iOS + Android |
| v1.1 | ~43 (+13 AA layer) | ~95% wallet + full ERC-4337/EIP-7702/ERC-1271 AA | iOS + Android |

### Top Lessons (Verified Across Milestones)

1. **Plan ahead-of-time, even for "known" work.** Phase 5 retrofit (v1.0) and autonomous CONTEXT.md gap (v1.1) both confirm this. The planning artifact is the threat-model, not just a schedule.
2. **`assert()` is not production validation.** Appeared as a systemic pattern in v1.1. Add to project coding standards as a hard rule.
3. **Sealed types prevent protocol misuse at compile time.** First demonstrated in v1.1 with `EvmSignature`. Carry this pattern to any future protocol-variant boundary.
4. **Code review should cover all phases in one pass.** v1.1 did two separate passes; one comprehensive pass is faster and catches cross-phase patterns (like the assert anti-pattern) more reliably.
