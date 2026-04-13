# ceres_wallet_core

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Flutter plugin providing Dart FFI bindings for [Trust Wallet Core](https://github.com/SauceWu/wallet-core), supporting Ethereum, Solana, Sui, Tron and 27+ EVM L2 chains.

[中文文档](README_CN.md)

## Features

- **HD Wallet** — Create and import BIP39 wallets, derive keys and addresses for multiple chains
- **Transaction Signing** — Sign transactions via protobuf (ETH/SOL/SUI) or JSON (TRX)
- **Address Validation** — Validate addresses for any supported chain
- **Multi-chain** — ETH, SOL, SUI, TRX + Polygon, Arbitrum, Base, Optimism, and 20+ more EVM L2s
- **Memory Safe** — Automatic native resource cleanup via Dart Finalizers

## Requirements

- Flutter >= 3.38.0 / Dart >= 3.9.0
- iOS 13.0+ / Android API 21+
- Pre-built native libraries (see [Building](#building-native-libraries))

## Installation

```yaml
dependencies:
  ceres_wallet_core:
    git:
      url: https://github.com/SauceWu/ceres-wallet-core.git
```

## Quick Start

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// Create a new wallet
final wallet = TWHDWallet();
print('Mnemonic: ${wallet.mnemonic}');

// Derive addresses
final ethAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeEthereum);
final solAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeSolana);
final tronAddr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeTron);

// Import from mnemonic
final imported = TWHDWallet.createWithMnemonic('your twelve word mnemonic ...');

// Validate address
final valid = TWAnyAddress.isValid('0x...', TWCoinType.TWCoinTypeEthereum);

// Sign transaction
final output = TWAnySigner.sign(inputBytes, TWCoinType.TWCoinTypeEthereum);

// Clean up
wallet.delete();
```

## API Reference

| Class | Description |
|-------|-------------|
| `TWHDWallet` | HD wallet creation, import, key derivation |
| `TWPrivateKey` | Private key operations, signing |
| `TWPublicKey` | Public key operations, verification |
| `TWAnyAddress` | Address creation, validation |
| `TWAnySigner` | Transaction signing (protobuf & JSON) |
| `TWMnemonic` | BIP39 mnemonic validation |
| `TWCoinType` | Chain configuration, derivation paths |

### Protobuf Models

Import chain-specific protobuf models for transaction building:

```dart
import 'package:ceres_wallet_core/proto/Ethereum.pb.dart' as Ethereum;
import 'package:ceres_wallet_core/proto/Solana.pb.dart' as Solana;
import 'package:ceres_wallet_core/proto/Sui.pb.dart' as Sui;
import 'package:ceres_wallet_core/proto/Tron.pb.dart' as Tron;
```

## Supported Chains

**Primary:** Ethereum, Solana, Sui, Tron

**EVM L2:** Polygon, Arbitrum, Base, Optimism, Avalanche C-Chain, BNB Smart Chain, Fantom, Cronos, zkSync, Linea, Scroll, Mantle, Blast, Ronin, Moonbeam, Boba, Kaia, opBNB, Arbitrum Nova, Polygon zkEVM, Manta, Metis, Aurora, Celo, Gnosis (xDai), Kava EVM, Sonic

### Customizing Chains

To add or remove supported chains, edit `tool/trim_registry.py`:

```python
# tool/trim_registry.py
DEFAULT_CHAINS = {
    'ethereum', 'solana', 'sui', 'tron',
    'polygon', 'arbitrum', 'base', 'optimism',
    # Add new chains here (use the chain ID from wallet-core registry.json)
    # Remove chains you don't need
}
```

After modifying, rebuild the native libraries:

```bash
bash tool/build_native.sh all
```

> **Note:** Chains using Rust signers (ETH, SOL, SUI) also need the corresponding Rust crate enabled in `tool/ci_patches.py` under `keep_chains` in `step10_trim_rust()`. Tron and EVM L2s are pure C++ and only need the registry entry.

## Building Native Libraries

Pre-built native libraries are required. Build them with:

```bash
# iOS (requires macOS + Xcode)
bash tool/build_native.sh ios

# Android (requires Android NDK)
bash tool/build_native.sh android

# Both platforms
bash tool/build_native.sh all
```

The build script uses a [wallet-core fork](https://github.com/SauceWu/wallet-core) as a git submodule, trimmed to supported chains only.

### Build Requirements

- CMake >= 3.18, Ninja
- Rust nightly (with iOS/Android targets)
- Python 3
- cbindgen
- Xcode (iOS) / Android NDK (Android)

## Testing

```bash
cd example
flutter test integration_test/wallet_core_test.dart -d <device_id>
```

## Project Structure

```
lib/
  ceres_wallet_core.dart         # Barrel export
  src/                           # High-level Dart wrappers
  bindings/                      # ffigen-generated C bindings
  proto/                         # Protobuf models (ETH/SOL/SUI/TRX)
tool/
  build_native.sh                # One-command native build
  ci_patches.py                  # Source trimming for wallet-core
  trim_registry.py               # Chain registry trimmer
third_party/
  wallet-core/                   # Git submodule (SauceWu/wallet-core fork)
hook/
  build.dart                     # Dart build hook for native asset distribution
```

## License

MIT License. See [LICENSE](LICENSE).

Trust Wallet Core is licensed under [Apache 2.0](https://github.com/trustwallet/wallet-core/blob/master/LICENSE).
