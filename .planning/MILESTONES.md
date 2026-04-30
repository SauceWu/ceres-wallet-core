# Milestones

## v1.1 AA Foundation — SHIPPED 2026-04-30

**Started:** 2026-04-29
**Shipped:** 2026-04-30
**Goal:** Deliver a complete ERC-4337 / EIP-7702 Account Abstraction mid-layer — unified secp256k1 + P-256 passkey signer abstraction, Barz SmartAccount counterfactual address, initCode, UserOperation assembly, ERC-1271 message signing, and EIP-7702 EOA upgrade.

**Stats:** 8 phases (Phase 6–13) | 12 formal plans | 26 files changed | 4,037 lines added | v1.1.0 published to pub.dev

**Key accomplishments:**
- Sealed `EvmSignature` union (`Secp256k1Signature` + `PasskeySignature`) with abstract `EvmSigner` single-flight invariant — compile-time prevention of raw r‖s misuse (Pitfall 1 + Pitfall 7)
- `Secp256k1Signer` + `PasskeySigner` concrete implementations; injected adapter pattern keeps SDK free of platform dependencies
- `Erc4337Calldata.executeCall` / `.executeBatch` with keccak256-verified selectors and release-safe `ArgumentError` validation
- `BarzDeployments` per-chain registry (6 chains) + `PasskeyBarzAddress.compute` with mandatory CREATE2 round-trip verification (Pitfall 2 + Pitfall 9)
- `BarzInitCode.forPasskey` generating both v0.6 monolithic initCode and v0.7 split (factory + factoryData)
- `Erc1271Helper` per-(account, chainId) instance for ERC-1271 personal_sign / typed-data — strictly non-EOA
- `Erc4337Builder.v06` / `.v07` named constructors + `attachSignature` sole conversion site + clientDataJSON challenge validation with `PasskeyChallengeMismatch`
- `Eip7702Upgrader`, `BarzDiamondCut`, `BarzSessionKey`, `PasskeyBarzAddress.acrossChains` — complete AA primitive surface; v1.1.0 pub.dev publish
- 3 code review passes (Phases 6–13): 4 Critical, 12 Warning, 12 Info — all Critical + Warning fixed; security-critical challenge binding elevated to release-safe `StateError`

**Archived artifacts:**
- `.planning/milestones/v1.1-ROADMAP.md`
- `.planning/milestones/v1.1-REQUIREMENTS.md`

---

## v1.0 SDK Foundation — SHIPPED 2026-04-29

**Started:** 2026-04-11
**Shipped:** 2026-04-29
**Goal:** Deliver a fully functional Flutter plugin replacing the commercially-licensed `wallet_core_bindings` with self-hosted Dart FFI bindings to Trust Wallet Core (Apache 2.0).

**Stats:** 5 phases | 7 plans | v0.1.0 → v0.2.0 published to pub.dev

**Key accomplishments:**
- Dart FFI bindings covering ~95% of wallet-relevant Trust Wallet Core surface (commit `4207adb`, v0.2.0)
- Cross-platform native libs: iOS xcframework (arm64 device + simulator) + Android .so (arm64-v8a / armeabi-v7a / x86_64)
- Self-contained build pipeline: registry trimming (31 chains for wallet-core 4.6.3), codegen, native compilation, GitHub Actions CI, automated GitHub Releases
- pub.dev publication with Dart build hooks for transparent native-library download at `flutter pub get` time
- Drop-in API parity with `wallet_core_bindings` (same class names + signatures) + unified `CeresWalletCoreInit` initialization
- ERC-4337 / Account Abstraction primitives via `TWBarz` (counterfactual address, init code, signature formatting, EIP-7702 authorization)
- WebAuthn / passkey support via `TWWebAuthn` for P-256 smart-account flows
- Encrypted JSON keystore (`TWStoredKey` v3 format, MEW/MetaMask compatible) + mobile-aware path resolution (`TWKeystoreStorage`)

**Known deferred:**
- High-level signer abstraction unifying secp256k1 + P-256 — deferred to v1.1 AA Foundation
- ERC-4337 `UserOperation` builder + `executeCall` calldata encoders — deferred to v1.1 AA Foundation
- Full local-script reproducibility for native build — accepted via override in `02-VERIFICATION.md` (CI delivers reproducibility)

**Archived artifacts:**
- `.planning/milestones/v1.0-ROADMAP.md`
- `.planning/milestones/v1.0-REQUIREMENTS.md`
