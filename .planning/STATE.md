---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: AA Foundation
status: SHIPPED
last_updated: "2026-04-30T02:08:00.000Z"
progress:
  total_phases: 8
  completed_phases: 8
  total_plans: 12
  percent: 100
---

# 状态

## 当前位置

里程碑：v1.1 AA Foundation — **SHIPPED 2026-04-30**

所有 8 个阶段（Phase 6–13）已完成并出货。15/15 AA 需求全部交付。v1.1.0 已发布至 pub.dev。

## Project Reference

See: `.planning/PROJECT.md`（updated 2026-04-30）

**Core value:** 自主拥有钱包核心绑定层 — 无商业许可依赖，提供 ERC-4337 / passkey 钱包底层原语
**Current focus:** v1.1 已归档 — 规划下一里程碑

## v1.0 成就（已归档）

详见 `.planning/milestones/v1.0-ROADMAP.md` 与 `.planning/MILESTONES.md`。

## v1.1 成就（已归档）

详见 `.planning/milestones/v1.1-ROADMAP.md` 与 `.planning/MILESTONES.md`。

**已交付 AA 层：**
- `EvmSigner` + `EvmSignature` sealed union + `Secp256k1Signer` + `PasskeySigner`
- `Erc4337Calldata` + `Erc4337Builder` (v0.6/v0.7)
- `BarzDeployments` 6-chain registry + `PasskeyBarzAddress` + `BarzInitCode`
- `Erc1271Helper` + `PasskeyAssertion`
- `Eip7702Upgrader` + `BarzDiamondCut` + `BarzSessionKey`
- `_proto_utils.dart` 共享 proto3 序列化工具库

## Accumulated Context

### Open Blockers

（无）

### Tech Debt 跨里程碑

- macOS host `.dylib` 未构建 — FFI 集成测试需要 iOS/Android 设备（文档化于 Phase 6 POLICY）
- Sepolia E2E 延后至 v1.2（Out of Scope 用户决策）
- `@visibleForTesting attachSignature._computedHash == null` guard 测试路径 — FFI 依赖阻塞（Phase 13 INFO 项）
