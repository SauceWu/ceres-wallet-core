# ceres_wallet_core

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Flutter 插件，通过 Dart FFI 绑定 [Trust Wallet Core](https://github.com/SauceWu/wallet-core)，支持 Ethereum、Solana、Sui、Tron 及 27+ EVM L2 链。

[English](README.md)

## 功能

- **HD 钱包** — 创建/导入 BIP39 钱包，派生多链密钥和地址
- **交易签名** — 通过 protobuf（ETH/SOL/SUI）或 JSON（TRX）签名交易
- **地址验证** — 验证任意支持链的地址
- **多链支持** — ETH、SOL、SUI、TRX + Polygon、Arbitrum、Base、Optimism 等 20+ EVM L2
- **内存安全** — 通过 Dart Finalizer 自动清理 native 资源

## 环境要求

- Flutter >= 3.38.0 / Dart >= 3.9.0
- iOS 13.0+ / Android API 21+
- 预编译 native 库（参见[编译说明](#编译-native-库)）

## 安装

```yaml
dependencies:
  ceres_wallet_core:
    git:
      url: https://github.com/SauceWu/ceres-wallet-core.git
```

## 快速开始

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// 创建钱包
final wallet = TWHDWallet();
print('助记词: ${wallet.mnemonic}');

// 派生地址
final ethAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeEthereum);
final solAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeSolana);
final tronAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeTron);

// 从助记词导入
final imported = TWHDWallet.createWithMnemonic('twelve word mnemonic ...');

// 验证地址
final valid = TWAnyAddress.isValid('0x...', TWCoinType.TWCoinTypeEthereum);

// 签名交易
final output = TWAnySigner.sign(inputBytes, TWCoinType.TWCoinTypeEthereum);

// 释放资源
wallet.delete();
```

## API 参考

| 类 | 说明 |
|---|------|
| `TWHDWallet` | HD 钱包创建、导入、密钥派生 |
| `TWPrivateKey` | 私钥操作、签名 |
| `TWPublicKey` | 公钥操作、验证 |
| `TWAnyAddress` | 地址创建、验证 |
| `TWAnySigner` | 交易签名（protobuf 和 JSON） |
| `TWMnemonic` | BIP39 助记词验证 |
| `TWCoinType` | 链配置、派生路径 |

### Protobuf 模型

导入链专用 protobuf 模型用于构建交易：

```dart
import 'package:ceres_wallet_core/proto/Ethereum.pb.dart' as Ethereum;
import 'package:ceres_wallet_core/proto/Solana.pb.dart' as Solana;
import 'package:ceres_wallet_core/proto/Sui.pb.dart' as Sui;
import 'package:ceres_wallet_core/proto/Tron.pb.dart' as Tron;
```

## 支持的链

**主链：** Ethereum、Solana、Sui、Tron

**EVM L2：** Polygon、Arbitrum、Base、Optimism、Avalanche C-Chain、BNB Smart Chain、Fantom、Cronos、zkSync、Linea、Scroll、Mantle、Blast、Ronin、Moonbeam、Boba、Kaia、opBNB、Arbitrum Nova、Polygon zkEVM、Manta、Metis、Aurora、Celo、Gnosis (xDai)、Kava EVM、Sonic

### 自定义链配置

如需增加或删除支持的链，编辑 `tool/trim_registry.py`：

```python
# tool/trim_registry.py
DEFAULT_CHAINS = {
    'ethereum', 'solana', 'sui', 'tron',
    'polygon', 'arbitrum', 'base', 'optimism',
    # 在此添加新链（使用 wallet-core registry.json 中的链 ID）
    # 删除不需要的链
}
```

修改后重新编译 native 库：

```bash
bash tool/build_native.sh all
```

> **注意：** 使用 Rust 签名器的链（ETH、SOL、SUI）还需要在 `tool/ci_patches.py` 的 `step10_trim_rust()` 中 `keep_chains` 里启用对应的 Rust crate。Tron 和 EVM L2 是纯 C++ 实现，只需要 registry 条目即可。

## 编译 Native 库

使用前需要编译 native 库：

```bash
# iOS（需要 macOS + Xcode）
bash tool/build_native.sh ios

# Android（需要 Android NDK）
bash tool/build_native.sh android

# 全平台
bash tool/build_native.sh all
```

编译脚本使用 [wallet-core fork](https://github.com/SauceWu/wallet-core) 作为 git submodule，已裁剪至仅支持的链。

### 编译依赖

- CMake >= 3.18、Ninja
- Rust nightly（需安装 iOS/Android targets）
- Python 3
- cbindgen
- Xcode（iOS）/ Android NDK（Android）

## 测试

```bash
cd example
flutter test integration_test/wallet_core_test.dart -d <device_id>
```

## 项目结构

```
lib/
  ceres_wallet_core.dart         # 导出入口
  src/                           # 高层 Dart 封装
  bindings/                      # ffigen 生成的 C 绑定
  proto/                         # Protobuf 模型（ETH/SOL/SUI/TRX）
tool/
  build_native.sh                # 一键编译脚本
  ci_patches.py                  # wallet-core 源码裁剪
  trim_registry.py               # 链注册表裁剪
third_party/
  wallet-core/                   # Git submodule（SauceWu/wallet-core fork）
hook/
  build.dart                     # Dart build hook，用于 native 库分发
```

## 许可证

MIT License。详见 [LICENSE](LICENSE)。

Trust Wallet Core 使用 [Apache 2.0](https://github.com/trustwallet/wallet-core/blob/master/LICENSE) 许可。
