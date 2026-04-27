## 0.2.0

Major Dart wrapper expansion — high-level API now covers ~95% of the relevant FFI surface. `TWAnySigner.sign` is for transactions only; the new wrappers fix the silent `0x` signatures that occurred when `MessageSigningInput` was fed to the wrong API.

### Added — off-chain message signing
- `TWMessageSigner` — proto-based, multi-chain dispatcher (`sign` / `preImageHashes` / `verify`).
- `TWEthereumMessageSigner` — `personal_sign` (legacy / EIP-155 / Immutable X), EIP-712 typed data (with optional EIP-155), `verifyMessage`.
- `TWBitcoinMessageSigner`, `TWTronMessageSigner`, `TWTONMessageSigner`, `TWTezosMessageSigner`, `TWStarkExMessageSigner`.

### Added — transaction tooling
- `TWTransactionCompiler.preImageHashes` / `compileWithSignatures` / `compileWithSignaturesAndPubKeyType` — needed for hardware-wallet and MPC signing flows.
- `TWTransactionDecoder.decode` — chain-specific decoded transaction protos.
- `TWTransactionUtil.calcTxHash` — display tx hash from raw encoded tx.
- `TWWalletConnectRequest.parse` — WalletConnect request → `SigningInput`.

### Added — Solidity ABI codec
- `TWEthereumAbi` (encode / decodeOutput / decodeCall / decodeContractCall / decodeParams / decodeValue / encodeFunction / encodeTyped / getFunctionSignature).
- `TWEthereumAbiFunction` — instance class with finalizer; full param builder + getter API.
- `TWEthereumAbiValue` — primitive ABI codec (encode / decode for bool, bytes, address, string, uint/int 32/256, etc.).

### Added — crypto utilities
- `TWHash` — Keccak256/512, SHA1/256/512, SHA3-256/512, RIPEMD, Blake256/2b (+ personal salt), Groestl512, and SHA-double / Blake-double / SHA256-RIPEMD compositions.
- `TWBase32` / `TWBase58` / `TWBase64` / `TWBech32` — encode/decode (Base58Check, Base64-URL, Bech32M variants).
- `TWAES` — CBC / CTR encrypt + decrypt with `TWAESPaddingMode`.
- `TWPBKDF2` — `hmacSha256` / `hmacSha512`.

### Added — partial wrapper completion
- `TWHDWallet`: `createWithMnemonicCheck`, `getMasterKey`, `getKeyByCurve`, `getDerivedKey`, `getExtendedPrivateKey/PublicKey` (+ Account + Derivation variants), `getPublicKeyFromExtended`.
- `TWPrivateKey`: `createCopy`, `signAsDER`, `signZilliqaSchnorr`, `getPublicKeyCurve25519` / `Ed25519Blake2b` / `Ed25519Cardano` / `Nist256p1`.
- `TWPublicKey`: **`recover`** (signature → public key recovery), `verifyAsDER`, `verifyZilliqaSchnorr`.
- `TWAnyAddress`: `createBech32(WithPublicKey)`, `createSS58(WithPublicKey)`, `createWithPublicKeyFilecoinAddressType`, `createWithPublicKeyFiroAddressType`, `isValidBech32`, `isValidSS58`, `nativeEqual`.
- `TWCoinType` extension: `chainId`, `slip44Id`, `decimals`, `name`, `symbol`, `id`, `accountURL` / `transactionURL`, `p2pkhPrefix` / `p2shPrefix` / `staticPrefix`, `hrp`, `ss58Prefix`, `xprvVersion` / `xpubVersion`, `deriveAddressFromPublicKeyAndDerivation`.

### Re-exports
- `TWAESPaddingMode`, `TWFilecoinAddressType`, `TWFiroAddressType` are now re-exported from the barrel.

### Added — Ethereum mini utilities
- `TWEthereumAddress.checksummed` — EIP-55 checksummed address.
- `TWEthereumRlp.encode` — RLP encoding.
- `TWEthereumEip1014.create2Address` — CREATE2 deterministic address.
- `TWEthereumEip1967.proxyInitCode` — proxy init code.
- `TWEthereumEip2645.getPath` — StarkEx HD path derivation.
- `TWStarkWare.getStarkKeyFromSignature` — StarkNet stark key from Ethereum signature.

### Added — ERC-4337 Account Abstraction
- `TWBarz` — smart-account helpers: `getCounterfactualAddress`, `getInitCode`, `getFormattedSignature`, `getPrefixedMsgHash`, `getSignedHash`, `getEncodedHash`, `getDiamondCutCode`, `getAuthorizationHash`, `signAuthorization`.

### Added — Solana
- `TWSolanaAddress` — instance class for Solana addresses, with `defaultTokenAddress` (SPL ATA) and `token2022Address` derivation.
- `TWSolanaTransaction` — compute unit limit/price get/set, fee payer override, instruction insertion, and `updateBlockhashAndSign` for re-signing with a fresh blockhash.

### Added — Typed derivation paths
- `TWDerivationPath` and `TWDerivationPathIndex` instance classes — type-safe BIP44 path manipulation (parse, build, indexAt, hardened/value getters, description).

### Added — End-to-end encryption
- `TWCryptoBox` (NaCl `crypto_box_easy`, X25519 + XSalsa20-Poly1305) with `TWCryptoBoxSecretKey` / `TWCryptoBoxPublicKey` instance classes. For two-party encrypted messages (E2EE, encrypted backups, push payloads).

### Added — Encrypted keystore (Ethereum keystore v3 JSON)
- `TWStoredKey` — full keystore lifecycle: create, importHDWallet, importPrivateKey, importJSON, decryptMnemonic, decryptPrivateKey, exportJSON, store, load, plus per-coin Account caching (accountForCoin / addAccount / removeAccountForCoin / updateAddress / fixAddresses).
- `TWAccount` — derived account record (address, coin, derivation, derivationPath, publicKey, extendedPublicKey).
- Re-exports `TWStoredKeyEncryption` and `TWStoredKeyEncryptionLevel` enums.
- Compatible with the JSON keystore format used by Trust Wallet, MEW, MetaMask.

### Added — WebAuthn / passkey support
- `TWWebAuthn` — passkey wallet authentication helpers:
  - `getPublicKey(attestationObject)` → `TWPublicKey?` — extract the P-256 (NIST256p1) public key from a WebAuthn registration `attestationObject`.
  - `reconstructOriginalMessage(authenticatorData, clientDataJSON)` — rebuild the bytes the authenticator signed (= `authenticatorData ‖ SHA-256(clientDataJSON)`).
  - `getRSValues(derSignature)` — extract canonical `r ‖ s` (64 bytes) from an ASN.1 / DER WebAuthn signature.
- Pairs with `TWBarz` for ERC-4337 passkey-authenticated smart accounts and on-chain P-256 verifiers (EIP-7212).

### Added — Mobile keystore storage helper
- `TWKeystoreStorage` — platform-aware default path resolution for keystore JSON. Lands in iOS `Application Support/keystores/` and Android `files/keystores/` via `path_provider`. Convenience `store/load/list/exists/deleteKeystore/importAndStore/exportJSON` helpers, plus `passwordToBytes` (UTF-8) for the `Uint8List password` argument.
- New dependency: `path_provider: ^2.1.4`.
- Note: passwords still need to be stored separately via the platform secure store (iOS Keychain / Android Keystore) — the helper does not handle credentials.

## 0.1.0

- Initial release
- Dart FFI bindings for Trust Wallet Core (based on wallet-core 4.6.3)
- HD wallet creation and import (BIP39)
- Multi-chain address derivation: ETH, SOL, SUI, TRX + 27 EVM L2s
- Transaction signing via protobuf and JSON
- Address validation for all supported chains
- Memory-safe wrappers with Dart Finalizers
- Integration tests covering all API classes
- CI workflow for building iOS and Android native libraries
