/// Ceres Wallet Core — Dart FFI bindings for Trust Wallet Core.
///
/// API-compatible with wallet_core_bindings for easy migration.
library ceres_wallet_core;

// Initialization
export 'src/native.dart' show CeresWalletCoreInit;

// High-level wrapper classes
export 'src/tw_hd_wallet.dart';
export 'src/tw_private_key.dart';
export 'src/tw_public_key.dart';
export 'src/tw_any_address.dart';
export 'src/tw_any_signer.dart';
export 'src/tw_mnemonic.dart';
export 'src/tw_coin_type_ext.dart';

// Off-chain message signing — personal_sign, EIP-712, and per-chain variants.
// `TWAnySigner.sign` is for transactions only; use these for messages.
export 'src/tw_message_signer.dart';
export 'src/tw_ethereum_message_signer.dart';
export 'src/tw_chain_message_signers.dart';

// Transaction tooling — pre-image hashes for hardware/MPC, decoding, hash calc,
// and WalletConnect request parsing.
export 'src/tw_transaction_compiler.dart';
export 'src/tw_transaction_decoder.dart';
export 'src/tw_transaction_util.dart';
export 'src/tw_wallet_connect_request.dart';

// Solidity ABI codec (encode / decode / EIP-712 typed data hashing).
export 'src/tw_ethereum_abi.dart';

// Ethereum mini utilities — EIP-55 checksum, RLP, EIP-1014 (CREATE2),
// EIP-1967 (proxy), EIP-2645 (StarkEx HD path), StarkWare key derivation.
export 'src/tw_ethereum_utils.dart';

// ERC-4337 / Account Abstraction (Barz smart-account helpers).
export 'src/tw_barz.dart';

// Solana — typed address (SPL token, Token-2022) and transaction builder
// helpers (compute units, fee payer, blockhash + sign).
export 'src/tw_solana_address.dart';
export 'src/tw_solana_transaction.dart';

// Typed BIP44 derivation paths.
export 'src/tw_derivation_path.dart';

// NaCl crypto_box_easy — X25519 + XSalsa20-Poly1305 authenticated public-key
// encryption, used for end-to-end encrypted messages between two key pairs.
export 'src/tw_crypto_box.dart';

// Crypto utilities — hash, encoding, symmetric crypto, KDF.
export 'src/tw_hash.dart';
export 'src/tw_base.dart';
export 'src/tw_aes.dart';
export 'src/tw_pbkdf2.dart';

// Encrypted multi-coin keystore (Ethereum keystore v3 JSON, scrypt + AES).
export 'src/tw_stored_key.dart';
// Mobile-aware default path resolution for keystore JSON files.
export 'src/tw_keystore_storage.dart';

// WebAuthn / passkey support — extract P-256 public key from attestation,
// reconstruct the signed payload, decode r/s from ASN.1 signatures.
// Pairs with TWBarz for ERC-4337 passkey-authenticated smart accounts.
export 'src/tw_webauthn.dart';

// Enums and types from bindings (re-export)
export 'bindings/ceres_wallet_core_bindings.dart'
    show
        TWCoinType,
        TWCurve,
        TWPublicKeyType,
        TWDerivation,
        TWBlockchain,
        TWPurpose,
        TWHDVersion,
        TWHRP,
        TWAESPaddingMode,
        TWFilecoinAddressType,
        TWFiroAddressType,
        TWStoredKeyEncryption,
        TWStoredKeyEncryptionLevel;

// Protobuf models — import with prefix to avoid name conflicts:
//   import 'package:ceres_wallet_core/proto/Ethereum.pb.dart' as Ethereum;
//   import 'package:ceres_wallet_core/proto/Solana.pb.dart' as Solana;
//   import 'package:ceres_wallet_core/proto/Sui.pb.dart' as Sui;
//   import 'package:ceres_wallet_core/proto/Tron.pb.dart' as Tron;
