# ceres_wallet_core

## 项目简介

Flutter 插件，通过 Dart FFI 绑定 Trust Wallet Core（Apache 2.0 许可）。替代商业许可的 `wallet_core_bindings` 包，覆盖 Ethereum、Solana、Sui、Tron 及 27 条 EVM L2 链 — 加上 ERC-4337 / 账户抽象、WebAuthn / passkey、加密 keystore、Solana 高级 API、Solidity ABI 编解码、链上消息签名、E2E 加密等完整原语。

## 核心价值

自主拥有钱包核心绑定层 — 无商业许可依赖，通过链裁剪缩小二进制体积，完全掌控 native 构建和 API 接口；同时为生态提供 ERC-4337 智能账户与 passkey 钱包的底层密码学原语。

## 当前状态

**已发布版本：** v1.1.0（pub.dev）
**最后里程碑：** v1.1 AA Foundation — 2026-04-30 出货

**FFI 覆盖率：** ~95% wallet 相关 Trust Wallet Core surface
**AA 层覆盖率：** 完整 ERC-4337 v0.6/v0.7 + EIP-7702 + ERC-1271 + WebAuthn/passkey 原语

**当前里程碑：** 规划中（见 ROADMAP.md）

## 背景

- **起因：** wallet_example 项目使用 `wallet_core_bindings`（商业许可）+ `wallet_core_bindings_native` + `wallet_core_bindings_libs` 来访问 Trust Wallet Core，需要替换为自有 SDK
- **方案：** Fork Trust Wallet Core（Apache 2.0），裁剪 registry.json 至 31 条链（4 主链 + 27 EVM L2），编译 native 库，提供 API 兼容的 Dart FFI 绑定层
- **用户：** wallet_example 应用 + 后续 Ceres 生态其他应用（钱包、dapp、AA passkey 钱包）
- **约束：** API 签名必须与 wallet_core_bindings 一致，最小化迁移工作量

## 关键决策

| 决策 | 选择 | 原因 | 结果 |
|------|------|------|------|
| 单包 vs 多包 | 单一 Flutter 插件 | 比 wallet_core_bindings 的 3 包拆分更简单；只需 iOS + Android | ✓ Good — pub.dev 单包发布，build hooks 自动下载 native |
| FFI 方式 | 手写 dart:ffi lookups | 比 ffigen 更可控，所需接口面较小 | ✓ Good — 5 phases 内扩展到 30+ wrapper 类无阻力 |
| 链范围 | ETH/SOL/SUI/TRX + 27 个 EVM L2（实际裁剪到 31 条） | 覆盖 wallet_example 全部需求，不含 BTC | ✓ Good — wallet-core 4.6.3 升级造成 +3 chain，纯增量无损 |
| Native 分发 | GitHub Releases + build hooks | 避免提交大二进制文件，支持 pub.dev 发布 | ✓ Good — v0.1.0 起每个 release 自动产物 |
| wallet-core 版本 | 4.6.3（v1.0 中段升级 from 4.4.4） | 跟上游 fix + 新链 | ⚠️ Revisit — 升级会引发 registry chain 数变化，每次需 verify 脚本同步 |
| Phase 5 计划方式 | v0.2.0 直接 ship 后回填 | 任务面临扩展机会、formal 计划开销不划算 | ⚠️ Revisit — 回填可行但失去 ahead-of-time threat modeling，AA 阶段会更严格走流程 |
| sealed EvmSignature 联合 | Dart 3 sealed class | 编译期防止 Pitfall 1（raw r‖s 进入 passkey 路径） | ✓ Good — 类型系统守卫 |
| 单飞在抽象层实现 | EvmSigner._pending Future | Pitfall 7 在正确抽象层防止；适配器无需关心并发 | ✓ Good |
| 注入式 passkey 适配器 | Function 类型参数 | SDK 无平台依赖；调用方拥有平台层 | ✓ Good |
| CREATE2 round-trip 强制 | 总是通过 TWEthereumEip1014 验证 | Pitfall 2 防止；无"信任但不验证"路径 | ✓ Good |
| v0.6/v0.7 命名构造器 | 独立构造器 → 独立 proto 类型 | Pitfall 4 防止；错误版本是编译期选择错误 | ✓ Good |
| attachSignature 作为唯一转换入口 | Builder 拥有 signature→bytes | 无 getFormattedSignature bypass 路径 | ✓ Good |
| _proto_utils.dart 共享模块 | 包级私有 library | 消除 passkey_barz_address 和 barz_diamond_cut 间 proto3 varint 重复 | ✓ Good |
| assert → ArgumentError/StateError | Release-safe 验证 | assert 在 release 模式被剥离；安全关键检查必须用 throw | ✓ Good |
 
## 需求（Requirements）

### Validated（v1.0 已交付）

#### SDK 核心
- ✓ **SDK-01..07** — 5 核心类（TWHDWallet、TWPrivateKey、TWPublicKey、TWAnyAddress、TWAnySigner）+ 8 枚举 + 4 链 protobuf — v1.0
- ✓ **EXT-01** — 离线消息签名（TWMessageSigner、TWEthereumMessageSigner、5 链特化）— v1.0 (v0.2.0)
- ✓ **EXT-02** — 交易工具链（Compiler、Decoder、Util、WalletConnect）— v1.0 (v0.2.0)
- ✓ **EXT-03** — Solidity ABI 编解码 — v1.0 (v0.2.0)
- ✓ **EXT-04** — 加密原语（Hash、Base*、AES、PBKDF2）— v1.0 (v0.2.0)
- ✓ **EXT-05** — Ethereum mini 工具（EIP-55、RLP、CREATE2、EIP-1967、EIP-2645、StarkWare）— v1.0 (v0.2.0)
- ✓ **EXT-06** — ERC-4337 Barz 原语（含 EIP-7702）— v1.0 (v0.2.0)
- ✓ **EXT-07** — WebAuthn / passkey 原语 — v1.0 (v0.2.0)
- ✓ **EXT-08** — 加密 keystore（v3 JSON）+ 移动端存储 — v1.0 (v0.2.0)
- ✓ **EXT-09** — Solana ATA / 派生路径 / E2EE — v1.0 (v0.2.0)

#### Native + 分发 + 迁移
- ✓ **BUILD-01..02** — iOS xcframework + Android .so 三 ABI — v1.0
- ✓ **BUILD-03..04** — 构建脚本 + registry 裁剪（accepted via overrides — 见 02-VERIFICATION.md）— v1.0
- ✓ **DIST-01..03** — GitHub CI + pub.dev + path: 依赖支持 — v1.0
- ✓ **MIG-01..03** — Producer 侧 drop-in 兼容 + 单一 init — v1.0

### Validated（v1.1 已交付）

#### AA 签名抽象
- ✓ **AA-01** — `EvmSigner` 抽象接口 + sealed `EvmSignature` 联合类型 + 单飞保证 — v1.1
- ✓ **AA-02** — `Secp256k1Signer`（TWPrivateKey 包装）65 字节 r‖s‖v — v1.1
- ✓ **AA-03** — `PasskeySigner`（注入适配器 + TWBarz.getFormattedSignature 约 290 字节输出）— v1.1

#### ERC-4337 UserOperation 组装
- ✓ **AA-04** — `Erc4337Builder.v06` / `.v07` 命名构造器 + 跨版本字段守卫 — v1.1
- ✓ **AA-05** — `attachSignature` 作为签名→bytes 唯一转换入口 + challenge 校验 — v1.1
- ✓ **AA-06** — `Erc4337Calldata.executeCall` / `.executeBatch` + keccak256 selector 验证 — v1.1

#### 反事实地址与部署
- ✓ **AA-07** — `PasskeyBarzAddress.compute` + 强制 CREATE2 round-trip 校验 — v1.1
- ✓ **AA-08** — `BarzDeployment` + `BarzDeployments` 6链 registry — v1.1
- ✓ **AA-09** — `BarzInitCode.forPasskey` (v0.6 monolithic + v0.7 split) — v1.1

#### ERC-1271 消息签名
- ✓ **AA-10** — `Erc1271Helper` per-(barzAddress, chainId) 实例 4 个方法 — v1.1
- ✓ **AA-11** — ERC-1271 语义文档 + 无 EOA ecrecover 路径 — v1.1

#### EIP-7702 EOA 升级
- ✓ **AA-12** — `Eip7702Upgrader.buildAuthorization` (仅 secp256k1; PasskeySigner 被拒绝) — v1.1

#### 高级 P2 增量
- ✓ **AA-13** — `BarzDiamondCut.encode` (add/remove/replace facet calldata) — v1.1
- ✓ **AA-14** — `BarzSessionKey.installCalldata` (session key facet ABI calldata) — v1.1
- ✓ **AA-15** — `PasskeyBarzAddress.acrossChains` (Map<int,String> per-chain) — v1.1

### Active（下一里程碑待定义）

待 `/gsd-new-milestone` 时定义。已知方向：
- Bundler RPC client integration（上层 dapp 向 — 可能独立包）
- Sepolia E2E 联调（从 Out of Scope 升级为 v1.2 可选）
- ERC-7579 modular accounts（长期规划）

### 不在范围内

- Bitcoin / UTXO 链
- WASM 目标
- 桌面端（Windows / Linux）native 构建（macOS 仅作为开发主机）
- Bundler RPC client（属上层 dapp / wallet 应用）
- Paymaster RPC（属上层 dapp）
- 平台 passkey 调用（属独立 Flutter plugin）

## Context

- **代码量：** lib/src/ 31 个 FFI wrapper 文件 + lib/src/aa/ 13 个 AA 层文件 + lib/proto/ 20 个 protobuf 文件 + 2 平台 stubs + 23 个测试文件
- **版本：** v1.1.0（pub.dev 已发布）
- **依赖：** path_provider ^2.1.4（TWKeystoreStorage）、meta: any（@visibleForTesting、@nonVirtual 注解）
- **CI：** GitHub Actions 在 push 与 tag 时构建 iOS + Android，artifacts 上传到 GitHub Releases
- **下游消费：** wallet_example（迁移在外部 repo 跟踪）+ AA passkey 钱包（v1.1 主要目标客户）
- **技术债：** macOS `.dylib` 未打包 — 主机端 FFI 集成测试跳过（文档化于 Phase 6 POLICY）；Sepolia E2E 作为 Out of Scope 延后至 v1.2

## 演进

本文档在阶段转换和里程碑边界时更新。

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → 移到 Out of Scope，写明原因
2. Requirements validated? → 移到 Validated 并标 phase reference
3. New requirements emerged? → 加到 Active
4. Decisions to log? → 加到 Key Decisions

**After each milestone** (via `/gsd-complete-milestone`):
1. 全文 review
2. Core Value 仍是优先级最高的吗？
3. 审计 Out of Scope — 原因还成立吗？
4. 用当前状态更新 Context

---
*最后更新：2026-04-30 — v1.1 milestone closed*
