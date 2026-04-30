# ceres_wallet_core

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![pub.dev](https://img.shields.io/badge/pub.dev-v1.1.0-blue)](https://pub.dev/packages/ceres_wallet_core)

A Flutter plugin providing Dart FFI bindings for [Trust Wallet Core](https://github.com/SauceWu/wallet-core), supporting Ethereum, Solana, Sui, Tron and 27+ EVM L2 chains — plus a full ERC-4337 / EIP-7702 Account Abstraction mid-layer.

[中文文档](README_CN.md)

## Features

- **HD Wallet** — Create and import BIP39 wallets, derive keys and addresses for multiple chains
- **Transaction Signing** — Sign transactions via protobuf (ETH/SOL/SUI) or JSON (TRX)
- **Address Validation** — Validate addresses for any supported chain
- **Multi-chain** — ETH, SOL, SUI, TRX + Polygon, Arbitrum, Base, Optimism, and 20+ more EVM L2s
- **Memory Safe** — Automatic native resource cleanup via Dart Finalizers
- **Account Abstraction (v1.1)** — Complete ERC-4337 / EIP-7702 mid-layer: unified signer abstraction, Barz smart-account address derivation, UserOperation builder, ERC-1271 message signing, EIP-7702 EOA upgrade

## Requirements

- Flutter >= 3.38.0 / Dart >= 3.9.0
- iOS 13.0+ / Android API 21+ / macOS 12.0+
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

### Core wallet & key
| Class | Description |
|-------|-------------|
| `TWHDWallet` | BIP39 wallet, key derivation, extended (xprv/xpub) keys, master keys |
| `TWPrivateKey` | Sign / signAsDER / signZilliqaSchnorr, multi-curve public key getters |
| `TWPublicKey` | Verify, **recover from signature**, verifyAsDER, verifyZilliqaSchnorr |
| `TWAnyAddress` | Address parse / build (Bech32, SS58, Filecoin, Firo variants) |
| `TWMnemonic` | BIP39 mnemonic validation + word suggestion |
| `TWCoinType` extension | chainId, slip44, decimals, hrp, ss58Prefix, xprv/xpubVersion, account/transaction URLs |

### Transaction signing
| Class | Description |
|-------|-------------|
| `TWAnySigner` | Transaction signing (protobuf & JSON) — **transactions only** |
| `TWTransactionCompiler` | preImageHashes + compileWithSignatures (hardware / MPC flow) |
| `TWTransactionDecoder` | Decode chain-specific raw transactions |
| `TWTransactionUtil` | calcTxHash for display |
| `TWWalletConnectRequest` | Parse WalletConnect request → SigningInput |

### Off-chain message signing
| Class | Description |
|-------|-------------|
| `TWMessageSigner` | proto-based, multi-chain (`MessageSigningInput`) |
| `TWEthereumMessageSigner` | personal_sign / EIP-155 / EIP-712 typed data / verify |
| `TWBitcoinMessageSigner` | `signmessage` / `verifymessage` (Base64) |
| `TWTronMessageSigner` | TIP-191 |
| `TWTONMessageSigner` | TON message signing |
| `TWTezosMessageSigner` | Taquito format / payload / sign / verify |
| `TWStarkExMessageSigner` | dYdX, Immutable X (StarkNet flavour) |

### Solidity ABI codec
| Class | Description |
|-------|-------------|
| `TWEthereumAbi` | encode / decodeOutput / decodeCall / encodeFunction / encodeTyped (EIP-712) |
| `TWEthereumAbiFunction` | builder + getter for ABI function calls (all uint/int/array/string/bool/bytes variants) |
| `TWEthereumAbiValue` | primitive value codec (encodeAddress / decodeUInt256 / decodeArray / …) |

### Ethereum mini utilities & Account Abstraction
| Class | Description |
|-------|-------------|
| `TWEthereumAddress` | EIP-55 checksummed address |
| `TWEthereumRlp` | RLP encoding (used for raw EVM tx assembly) |
| `TWEthereumEip1014` | CREATE2 deterministic address |
| `TWEthereumEip1967` | proxy init code |
| `TWEthereumEip2645` | StarkEx HD path derivation |
| `TWStarkWare` | StarkNet stark key from Ethereum signature |
| `TWBarz` | ERC-4337 smart-account helpers (counterfactual address, init code, signature formatting, etc.) |

### Solana
| Class | Description |
|-------|-------------|
| `TWSolanaAddress` | Address parsing + SPL `defaultTokenAddress` (ATA) + `token2022Address` |
| `TWSolanaTransaction` | compute unit limit/price, fee payer override, instruction insertion, `updateBlockhashAndSign` |

### Derivation paths
| Class | Description |
|-------|-------------|
| `TWDerivationPath` | typed BIP44 path (parse, build, getters for purpose/coin/account/change/address) |
| `TWDerivationPathIndex` | individual path component (value + hardened) |

### Crypto utilities
| Class | Description |
|-------|-------------|
| `TWHash` | Keccak / SHA family / RIPEMD / Blake2b / Groestl |
| `TWBase32` `TWBase58` `TWBase64` `TWBech32` | Encode / decode (Base58Check, Base64-URL, Bech32M variants) |
| `TWAES` | AES-CBC / AES-CTR encrypt + decrypt |
| `TWPBKDF2` | HmacSha256 / HmacSha512 |
| `TWCryptoBox` | NaCl `crypto_box_easy` (X25519 + XSalsa20-Poly1305) — two-party E2E encryption |

### Encrypted keystore
| Class | Description |
|-------|-------------|
| `TWStoredKey` | Ethereum keystore v3 JSON, scrypt + AES, multi-coin account caching |
| `TWAccount` | Single chain account record returned by `TWStoredKey` (address, coin, derivation path, pubkey, xpub) |
| `TWKeystoreStorage` | Mobile-aware default path resolution (iOS Application Support / Android filesDir) + load/store/list/import/export helpers |

### WebAuthn / passkey
| Class | Description |
|-------|-------------|
| `TWWebAuthn` | Extract P-256 public key from `attestationObject`, reconstruct the signed payload from `authenticatorData` + `clientDataJSON`, decode `r ‖ s` from ASN.1 signatures. Pairs with `TWBarz` for ERC-4337 passkey-authenticated smart accounts. |

### Account Abstraction (v1.1) — ERC-4337 / EIP-7702

#### Signer abstraction
| Class | Description |
|-------|-------------|
| `EvmSigner` | Abstract base with single-flight `Future<EvmSignature> signDigest(Uint8List digest32)` — concurrent calls coalesce into one in-flight operation |
| `Secp256k1Signer` | Concrete `EvmSigner` wrapping `TWPrivateKey` — 65-byte `r‖s‖v` output |
| `PasskeySigner` | Concrete `EvmSigner` for P-256 / WebAuthn — accepts an injected `Future<PasskeyAssertion> Function(Uint8List)` adapter; SDK has no platform dependency |
| `EvmSignature` | `sealed class` union (`Secp256k1Signature` \| `PasskeySignature`) — compile-time prevention of raw-byte misuse |

#### Barz smart-account address & deployment
| Class | Description |
|-------|-------------|
| `BarzDeployments` | Per-chain registry covering mainnet, Sepolia, Base, Arbitrum, Optimism, Polygon — each pinning (chainId, factory, verificationFacet, entryPoint) |
| `BarzDeployment` | Immutable value object for one chain's deployment addresses |
| `PasskeyBarzAddress` | `compute(deployment, p256PubKey, salt)` — counterfactual address with mandatory CREATE2 round-trip verification; `acrossChains(...)` — batch multi-chain |
| `BarzInitCode` | `forPasskey(deployment, p256PubKey, salt)` — returns v0.6 monolithic `initCode` **and** v0.7 split `(factory, factoryData)` |

#### ERC-4337 UserOperation builder
| Class | Description |
|-------|-------------|
| `Erc4337Builder` | `v06(...)` / `v07(...)` named constructors for separate proto types; `attachSignature(EvmSignature)` is the sole signature→bytes site; validates `clientDataJSON` challenge against the UserOp hash |
| `Erc4337Calldata` | `executeCall(target, value, data)` / `executeBatch(...)` — ABI-encoded inner-call calldata with keccak256-verified selectors |

#### ERC-1271 message signing
| Class | Description |
|-------|-------------|
| `Erc1271Helper` | Per-(barzAddress, chainId) instance — `personalSignDigest` / `typedDataDigest` / `formatPasskeySignature` / `encodeIsValidSignature`; strictly non-EOA |
| `PasskeyAssertion` | Value object for WebAuthn assertion outputs (`derSignature`, `authenticatorData`, `clientDataJSON`, `challenge`) |

#### EIP-7702 & advanced
| Class | Description |
|-------|-------------|
| `Eip7702Upgrader` | `buildAuthorization(chainId, contractAddress, nonce, signer)` — wraps `TWBarz.signAuthorization`; rejects `PasskeySigner` (7702 must be secp256k1) |
| `BarzDiamondCut` | `encode(adds, removes, replaces)` — EIP-2535 diamond facet upgrade calldata |
| `BarzSessionKey` | `installCalldata(key, validUntil, allowedTargets)` — session-key facet ABI calldata |

#### Account Abstraction quick start

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// --- secp256k1 path ---
final signer = Secp256k1Signer(privateKey);

// --- Passkey path (inject your platform adapter) ---
final signer = PasskeySigner(
  (challenge) async {
    // call your platform passkey plugin here
    final assertion = await myPasskeyPlugin.authenticate(challenge);
    return PasskeyAssertion(
      derSignature: assertion.signature,
      authenticatorData: assertion.authenticatorData,
      clientDataJSON: assertion.clientDataJSON,
      challenge: challenge,
    );
  },
);

// --- Counterfactual address ---
final deployment = BarzDeployments.sepolia;
final address = PasskeyBarzAddress.compute(deployment, p256PubKeyBytes, salt32);

// --- Build a v0.7 UserOperation ---
final builder = Erc4337Builder.v07(
  sender: address,
  deployment: deployment,
  p256PublicKey: p256PubKeyBytes,
  salt: salt32,
  deployed: false,
);
final sig = await signer.signDigest(userOpHash);
final userOp = builder.attachSignature(sig);

// --- ERC-1271 message signing ---
final helper = Erc1271Helper(barzAddress: address, chainId: 11155111);
final digest = helper.personalSignDigest(Uint8List.fromList(utf8.encode('Hello')));
```

### Passkey wallet (high-level flow)

```dart
// 1. Registration — convert WebAuthn attestation to a P-256 public key
final pub = TWWebAuthn.getPublicKey(attestationObject);
final pubKeyBytes = pub!.data; // store this + credential id

// 2. Sign request — user authenticates, you get assertion
//    response.signature, response.authenticatorData, response.clientDataJSON

// 3. Verify (off-chain): rebuild the signed message and decode r||s
final message = TWWebAuthn.reconstructOriginalMessage(
  authenticatorData,
  clientDataJSON,
);
final rs = TWWebAuthn.getRSValues(derSignature);
final ok = TWPublicKey(pubKeyBytes, TWPublicKeyType.TWPublicKeyTypeNIST256p1)
    .verify(rs, message);

// 4. Verify on-chain: feed `rs` + `message` + `pubKeyBytes` into your
//    ERC-4337 verifier (Barz, EIP-7212 P-256 precompile, etc.)
```

### Encrypted Keystore on iOS / Android

The `TWStoredKey` JSON format is what Trust Wallet, MEW and MetaMask use to back up wallets. `TWKeystoreStorage` handles platform-specific paths for you:

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// 1. Create a new HD-mnemonic-backed keystore
final pwd = TWKeystoreStorage.passwordToBytes('user-supplied password');
final key = TWStoredKey.create('My Wallet', pwd);

// 2. Persist to the platform-appropriate path
//    iOS:     <App>/Library/Application Support/keystores/my_wallet.json
//    Android: <App>/files/keystores/my_wallet.json
await TWKeystoreStorage.store(key, 'my_wallet');

// 3. Re-open later
final loaded = await TWKeystoreStorage.load('my_wallet');
final mnemonic = loaded!.decryptMnemonic(pwd);

// 4. Cache per-coin addresses inside the keystore
final wallet = loaded.wallet(pwd);
final ethAccount = loaded.accountForCoin(TWCoinType.TWCoinTypeEthereum, wallet);
print(ethAccount?.address);

// 5. Import a keystore JSON from another wallet
final json = await someExternalSource();
final imported = await TWKeystoreStorage.importAndStore(json, 'imported');
```

**Important — storing the password:**
- The keystore JSON is **useless without the password**. Don't put the password in the JSON or in plain SharedPreferences / NSUserDefaults.
- Use the platform secure store. The most common choice is `flutter_secure_storage`, which wraps:
  - **iOS:** Keychain Services (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` recommended).
  - **Android:** EncryptedSharedPreferences / Android Keystore.

**iOS iCloud backup:** files in `Application Support` are included in iCloud / iTunes backups by default. To exclude a keystore file, set `URLResourceValues.isExcludedFromBackup = true` on the URL via Swift, or use `getApplicationCacheDirectory()` instead (system may purge).

**Android backup:** the default `getFilesDir` is included in adb backup unless your manifest sets `android:allowBackup="false"`.

### Off-chain Message Signing (the bug behind `0x` signatures)

`TWAnySigner.sign` is for **transactions only** — feeding it a
`MessageSigningInput` proto silently returns empty bytes. Use the dedicated
message signers instead:

```dart
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// EIP-191 personal_sign with EIP-155 replay protection
final sig = TWEthereumMessageSigner.signMessageEip155(privateKey, msg, chainId);

// EIP-712 v4 typed data
final typedSig = TWEthereumMessageSigner.signTypedMessageEip155(
  privateKey, jsonEncodedTypedData, chainId,
);

// Generic, proto-driven (multi-chain):
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

# macOS (requires macOS + Xcode command-line tools)
bash tool/build_native.sh macos

# All platforms
bash tool/build_native.sh all
```

The build script uses a [wallet-core fork](https://github.com/SauceWu/wallet-core) as a git submodule, trimmed to supported chains only.

### Build Requirements

- CMake >= 3.18, Ninja
- Rust nightly (with iOS / Android / macOS targets)
- Python 3
- cbindgen
- Xcode (iOS + macOS) / Android NDK (Android)

### Platform outputs

| Platform | Output | Archive |
|----------|--------|---------|
| iOS | `ios/Frameworks/ceres_wallet_core.xcframework` | `ios-xcframework.tar.gz` |
| Android | `android/src/main/jniLibs/{ABI}/libceres_wallet_core.so` | `android-{abi}.tar.gz` |
| macOS | `build/macos/libceres_wallet_core.dylib` | `macos-arm64.tar.gz` |

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
    aa/                          # Account Abstraction layer (v1.1)
      evm_signer.dart            #   Abstract EvmSigner + single-flight invariant
      evm_signature.dart         #   Sealed EvmSignature union
      secp256k1_signer.dart      #   Secp256k1Signer (TWPrivateKey)
      passkey_signer.dart        #   PasskeySigner (injected WebAuthn adapter)
      passkey_assertion.dart     #   PasskeyAssertion value object
      passkey_signature.dart     #   PasskeySignature (Barz-formatted blob)
      barz_deployment.dart       #   BarzDeployment + BarzDeployments registry
      passkey_barz_address.dart  #   Counterfactual address (CREATE2 round-trip)
      barz_init_code.dart        #   v0.6/v0.7 initCode generation
      erc4337_builder.dart       #   UserOperation assembler
      erc4337_calldata.dart      #   executeCall / executeBatch encoders
      erc1271_helper.dart        #   ERC-1271 message signing helper
      eip7702_upgrader.dart      #   EIP-7702 EOA → Barz authorization
      barz_diamond_cut.dart      #   EIP-2535 diamond facet upgrade calldata
      barz_session_key.dart      #   Session-key facet calldata
  bindings/                      # ffigen-generated C bindings
  proto/                         # Protobuf models (ETH/SOL/SUI/TRX)
tool/
  build_native.sh                # One-command native build (ios/android/macos/all)
  ci_patches.py                  # Source trimming for wallet-core
  trim_registry.py               # Chain registry trimmer
third_party/
  wallet-core/                   # Git submodule (SauceWu/wallet-core fork)
hook/
  build.dart                     # Dart build hook for native asset distribution
test/
  aa/                            # Unit tests for AA layer
  fixtures/                      # Canonical WebAuthn / UserOperation test vectors
```

## License

MIT License. See [LICENSE](LICENSE).

Trust Wallet Core is licensed under [Apache 2.0](https://github.com/trustwallet/wallet-core/blob/master/LICENSE).
