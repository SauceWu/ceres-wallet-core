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
        TWHRP;

// Protobuf models — import with prefix to avoid name conflicts:
//   import 'package:ceres_wallet_core/proto/Ethereum.pb.dart' as Ethereum;
//   import 'package:ceres_wallet_core/proto/Solana.pb.dart' as Solana;
//   import 'package:ceres_wallet_core/proto/Sui.pb.dart' as Sui;
//   import 'package:ceres_wallet_core/proto/Tron.pb.dart' as Tron;
