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

### 钱包与密钥
| 类 | 说明 |
|---|------|
| `TWHDWallet` | BIP39 钱包，密钥派生，扩展密钥（xprv/xpub），主密钥 |
| `TWPrivateKey` | sign / signAsDER / signZilliqaSchnorr，多曲线公钥派生 |
| `TWPublicKey` | verify、**recover（从签名恢复公钥）**、verifyAsDER、verifyZilliqaSchnorr |
| `TWAnyAddress` | 地址解析与构造（Bech32 / SS58 / Filecoin / Firo 变体） |
| `TWMnemonic` | BIP39 助记词校验与单词建议 |
| `TWCoinType` 扩展 | chainId、slip44、decimals、hrp、ss58Prefix、xprv/xpubVersion、accountURL/transactionURL |

### 交易签名
| 类 | 说明 |
|---|------|
| `TWAnySigner` | 交易签名（protobuf & JSON）— **仅交易，不要用于消息** |
| `TWTransactionCompiler` | preImageHashes + compileWithSignatures（硬件钱包 / MPC 流程） |
| `TWTransactionDecoder` | 反解链特定的原始交易 |
| `TWTransactionUtil` | calcTxHash 用于显示交易哈希 |
| `TWWalletConnectRequest` | 解析 WalletConnect 请求 → SigningInput |

### 链下消息签名
| 类 | 说明 |
|---|------|
| `TWMessageSigner` | proto 多链调度器（`MessageSigningInput`） |
| `TWEthereumMessageSigner` | personal_sign / EIP-155 / EIP-712 typed data / verify |
| `TWBitcoinMessageSigner` | `signmessage` / `verifymessage`（Base64） |
| `TWTronMessageSigner` | TIP-191 |
| `TWTONMessageSigner` | TON 消息签名 |
| `TWTezosMessageSigner` | Taquito format / payload / sign / verify |
| `TWStarkExMessageSigner` | dYdX、Immutable X（StarkNet 风格） |

### Solidity ABI 编解码
| 类 | 说明 |
|---|------|
| `TWEthereumAbi` | encode / decodeOutput / decodeCall / encodeFunction / encodeTyped（EIP-712） |
| `TWEthereumAbiFunction` | ABI 函数构建器（uint/int/array/string/bool/bytes 全套 add/get） |
| `TWEthereumAbiValue` | 原子值编解码（encodeAddress / decodeUInt256 / decodeArray …） |

### Ethereum 小工具 & 账户抽象
| 类 | 说明 |
|---|------|
| `TWEthereumAddress` | EIP-55 校验和地址 |
| `TWEthereumRlp` | RLP 编码（自拼 EVM 交易时用） |
| `TWEthereumEip1014` | CREATE2 确定性地址 |
| `TWEthereumEip1967` | 代理 init code |
| `TWEthereumEip2645` | StarkEx HD 路径派生 |
| `TWStarkWare` | 由以太坊签名派生 StarkNet stark key |
| `TWBarz` | ERC-4337 智能账户工具（counterfactual 地址、init code、签名格式化等） |

### Solana
| 类 | 说明 |
|---|------|
| `TWSolanaAddress` | Solana 地址解析 + SPL `defaultTokenAddress`（ATA）+ `token2022Address` |
| `TWSolanaTransaction` | compute unit 上限/单价、fee payer 替换、指令插入、`updateBlockhashAndSign` 用最新 blockhash 重签 |

### 派生路径
| 类 | 说明 |
|---|------|
| `TWDerivationPath` | 类型化 BIP44 路径（解析、构造、各分量 getter） |
| `TWDerivationPathIndex` | 单段路径组件（value + hardened） |

### 加密工具
| 类 | 说明 |
|---|------|
| `TWHash` | Keccak / SHA / RIPEMD / Blake2b / Groestl 全家桶 |
| `TWBase32` `TWBase58` `TWBase64` `TWBech32` | 编/解码（含 Base58Check、Base64-URL、Bech32M 变体） |
| `TWAES` | AES-CBC / AES-CTR 加解密 |
| `TWPBKDF2` | HmacSha256 / HmacSha512 |
| `TWCryptoBox` | NaCl `crypto_box_easy`（X25519 + XSalsa20-Poly1305）— 双方端到端加密 |

### 加密 Keystore
| 类 | 说明 |
|---|------|
| `TWStoredKey` | Ethereum keystore v3 JSON 格式，scrypt + AES，多链账户缓存 |
| `TWAccount` | `TWStoredKey` 返回的单链账户记录（地址、coin、派生路径、公钥、xpub） |
| `TWKeystoreStorage` | 移动端默认路径解析（iOS Application Support / Android filesDir）+ load/store/list/import/export 工具 |

### WebAuthn / Passkey
| 类 | 说明 |
|---|------|
| `TWWebAuthn` | 从 `attestationObject` 抽 P-256 公钥；用 `authenticatorData` + `clientDataJSON` 重建签名原文；从 ASN.1 签名中拆出 `r ‖ s`。配 `TWBarz` 做 ERC-4337 passkey 智能账户。 |

### Passkey 钱包流程

```dart
// 1. 注册：把 WebAuthn attestation 转成 P-256 公钥
final pub = TWWebAuthn.getPublicKey(attestationObject);
final pubKeyBytes = pub!.data; // 这个 + credential id 存起来

// 2. 签名请求：用户人脸/指纹通过，拿到 assertion
//    response.signature / response.authenticatorData / response.clientDataJSON

// 3. 链下验证：重建签名原文 + 拆 r||s
final message = TWWebAuthn.reconstructOriginalMessage(
  authenticatorData,
  clientDataJSON,
);
final rs = TWWebAuthn.getRSValues(derSignature);
final ok = TWPublicKey(pubKeyBytes, TWPublicKeyType.TWPublicKeyTypeNIST256p1)
    .verify(rs, message);

// 4. 链上验证：把 `rs` + `message` + `pubKeyBytes` 喂给
//    ERC-4337 验证器（Barz / EIP-7212 P-256 预编译合约等）
```

### iOS / Android 上的加密 Keystore

`TWStoredKey` 的 JSON 是 Trust Wallet、MEW、MetaMask 都在用的钱包备份格式。`TWKeystoreStorage` 帮你处理移动端的路径差异：

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// 1. 创建新的 HD 助记词 keystore
final pwd = TWKeystoreStorage.passwordToBytes('用户输入的密码');
final key = TWStoredKey.create('我的钱包', pwd);

// 2. 落盘到平台默认位置
//    iOS:     <App>/Library/Application Support/keystores/my_wallet.json
//    Android: <App>/files/keystores/my_wallet.json
await TWKeystoreStorage.store(key, 'my_wallet');

// 3. 之后再打开
final loaded = await TWKeystoreStorage.load('my_wallet');
final mnemonic = loaded!.decryptMnemonic(pwd);

// 4. 在 keystore 里缓存各链地址
final wallet = loaded.wallet(pwd);
final ethAccount = loaded.accountForCoin(TWCoinType.TWCoinTypeEthereum, wallet);
print(ethAccount?.address);

// 5. 导入其他钱包导出的 keystore JSON
final json = await someExternalSource();
final imported = await TWKeystoreStorage.importAndStore(json, 'imported');
```

**密码存哪：**
- keystore JSON **没有密码就完全无用**。**不要**把密码塞进 JSON、SharedPreferences 或 NSUserDefaults。
- 用平台安全存储，常见用 `flutter_secure_storage`：
  - **iOS：** Keychain Services（推荐 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）
  - **Android：** EncryptedSharedPreferences / Android Keystore

**iOS iCloud 备份：** `Application Support` 默认会同步到 iCloud / iTunes 备份。如果不想 keystore 上云：通过原生 Swift 给 URL 设置 `URLResourceValues.isExcludedFromBackup = true`，或改用 `getApplicationCacheDirectory()`（系统可能清理）。

**Android 备份：** `getFilesDir` 默认会进 adb backup，除非 manifest 设 `android:allowBackup="false"`。

### 链下消息签名（修复 `0x` 空签名的关键）

`TWAnySigner.sign` **只处理交易**——把 `MessageSigningInput` proto 喂给它会
静默返回空字节（`personal_sign` 出 `0x` 的常见原因）。请改用专用 message signer：

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// EIP-191 personal_sign，带 EIP-155 重放保护
final sig = TWEthereumMessageSigner.signMessageEip155(privateKey, msg, chainId);

// EIP-712 v4 typed data
final typedSig = TWEthereumMessageSigner.signTypedMessageEip155(
  privateKey, jsonEncodedTypedData, chainId,
);

// 通用 proto 通路（多链）：
import 'package:ceres_wallet_core/proto/Ethereum.pb.dart' as Ethereum;
import 'package:fixnum/fixnum.dart';

final input = Ethereum.MessageSigningInput(
  privateKey: privateKey.data,
  message: 'Hello',
  chainId: Ethereum.MaybeChainId(chainId: Int64(1)),
  messageType: Ethereum.MessageType.MessageType_eip155,
);
final outBytes = TWMessageSigner.sign(
  TWCoinType.TWCoinTypeEthereum,
  input.writeToBuffer(),
);
final out = Ethereum.MessageSigningOutput.fromBuffer(outBytes);
```

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
