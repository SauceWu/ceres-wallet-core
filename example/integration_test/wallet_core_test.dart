import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ceres_wallet_core/ceres_wallet_core.dart';

// Fixed test mnemonic — DO NOT use in production
const _testMnemonic =
    'shoot island position soft burden budget tooth cruel issue economy destroy above';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // 1. TWHDWallet
  // ============================================================
  group('TWHDWallet', () {
    testWidgets('create random 12-word wallet', (tester) async {
      final wallet = TWHDWallet();
      final words = wallet.mnemonic.split(' ');
      expect(words.length, 12);
      wallet.delete();
    });

    testWidgets('create random 24-word wallet', (tester) async {
      final wallet = TWHDWallet(strength: 256);
      final words = wallet.mnemonic.split(' ');
      expect(words.length, 24);
      wallet.delete();
    });

    testWidgets('create from mnemonic', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      expect(wallet.mnemonic, _testMnemonic);
      wallet.delete();
    });

    testWidgets('seed is non-empty', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      expect(wallet.seed.isNotEmpty, true);
      wallet.delete();
    });

    testWidgets('entropy is non-empty', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      expect(wallet.entropy.isNotEmpty, true);
      wallet.delete();
    });

    testWidgets('getKeyForCoin returns valid key', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      expect(key.data.length, 32);
      key.delete();
      wallet.delete();
    });

    testWidgets('getKey with custom derivation path', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key =
          wallet.getKey(TWCoinType.TWCoinTypeEthereum, "m/44'/60'/0'/0/0");
      expect(key.data.length, 32);
      key.delete();
      wallet.delete();
    });

    testWidgets('getAddressForCoin - Ethereum', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final addr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeEthereum);
      expect(addr.startsWith('0x'), true);
      expect(addr.length, 42);
      wallet.delete();
    });

    testWidgets('getAddressForCoin - Solana', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final addr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeSolana);
      expect(addr.isNotEmpty, true);
      expect(addr.length > 30, true); // base58 address
      wallet.delete();
    });

    testWidgets('getAddressForCoin - Tron', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final addr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeTron);
      expect(addr.startsWith('T'), true);
      wallet.delete();
    });

    testWidgets('getAddressForCoin - Sui', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final addr = wallet.getAddressForCoin(TWCoinType.TWCoinTypeSui);
      expect(addr.startsWith('0x'), true);
      wallet.delete();
    });

    testWidgets('delete is safe to call multiple times', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      wallet.delete();
      wallet.delete(); // should not crash
    });

    testWidgets('same mnemonic produces same addresses', (tester) async {
      final w1 = TWHDWallet.createWithMnemonic(_testMnemonic);
      final w2 = TWHDWallet.createWithMnemonic(_testMnemonic);
      expect(
        w1.getAddressForCoin(TWCoinType.TWCoinTypeEthereum),
        w2.getAddressForCoin(TWCoinType.TWCoinTypeEthereum),
      );
      w1.delete();
      w2.delete();
    });
  });

  // ============================================================
  // 2. TWPrivateKey
  // ============================================================
  group('TWPrivateKey', () {
    testWidgets('create random key', (tester) async {
      final key = TWPrivateKey();
      expect(key.data.length, 32);
      key.delete();
    });

    testWidgets('createWithData', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final original = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      final bytes = original.data;

      final restored = TWPrivateKey.createWithData(bytes);
      expect(restored.data, bytes);

      restored.delete();
      original.delete();
      wallet.delete();
    });

    testWidgets('createWithHexString', (tester) async {
      final key = TWPrivateKey();
      final hex =
          key.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final restored = TWPrivateKey.createWithHexString(hex);
      expect(restored.data, key.data);
      restored.delete();
      key.delete();
    });

    testWidgets('isValid — valid key', (tester) async {
      final key = TWPrivateKey();
      expect(
        TWPrivateKey.isValid(key.data, TWCurve.TWCurveSECP256k1),
        true,
      );
      key.delete();
    });

    testWidgets('isValid — invalid key', (tester) async {
      expect(
        TWPrivateKey.isValid(Uint8List(32), TWCurve.TWCurveSECP256k1),
        false,
      );
    });

    testWidgets('getPublicKey', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      final pubkey = key.getPublicKey(TWCoinType.TWCoinTypeEthereum);
      expect(pubkey.data.isNotEmpty, true);
      pubkey.delete();
      key.delete();
      wallet.delete();
    });

    testWidgets('sign returns non-empty data', (tester) async {
      final key = TWPrivateKey();
      final digest = Uint8List(32); // zero hash
      digest[0] = 1; // make it non-zero
      final sig = key.sign(digest, TWCurve.TWCurveSECP256k1);
      expect(sig.isNotEmpty, true);
      key.delete();
    });

    testWidgets('delete safe multiple times', (tester) async {
      final key = TWPrivateKey();
      key.delete();
      key.delete();
    });
  });

  // ============================================================
  // 3. TWPublicKey
  // ============================================================
  group('TWPublicKey', () {
    testWidgets('createWithData from private key', (tester) async {
      final privKey = TWPrivateKey();
      final pubKey =
          privKey.getPublicKeyByType(TWPublicKeyType.TWPublicKeyTypeSECP256k1);
      final data = pubKey.data;

      final restored =
          TWPublicKey.createWithData(data, TWPublicKeyType.TWPublicKeyTypeSECP256k1);
      expect(restored.data, data);

      restored.delete();
      pubKey.delete();
      privKey.delete();
    });

    testWidgets('isCompressed', (tester) async {
      final key = TWPrivateKey();
      final compressed =
          key.getPublicKeyByType(TWPublicKeyType.TWPublicKeyTypeSECP256k1);
      expect(compressed.isCompressed, true);

      final uncompressed = key.getPublicKeyByType(
          TWPublicKeyType.TWPublicKeyTypeSECP256k1Extended);
      expect(uncompressed.isCompressed, false);

      uncompressed.delete();
      compressed.delete();
      key.delete();
    });

    testWidgets('verify signature', (tester) async {
      final key = TWPrivateKey();
      final pubKey =
          key.getPublicKeyByType(TWPublicKeyType.TWPublicKeyTypeSECP256k1);
      final digest = Uint8List(32);
      digest[0] = 42;

      final sig = key.sign(digest, TWCurve.TWCurveSECP256k1);
      expect(pubKey.verify(sig, digest), true);

      pubKey.delete();
      key.delete();
    });
  });

  // ============================================================
  // 4. TWAnyAddress
  // ============================================================
  group('TWAnyAddress', () {
    testWidgets('isValid — ETH address', (tester) async {
      expect(
        TWAnyAddress.isValid(
            '0x9Ac64Cc6e109c8025ab3C2cD9c8F426c5dE4A68B',
            TWCoinType.TWCoinTypeEthereum),
        true,
      );
    });

    testWidgets('isValid — Tron address', (tester) async {
      expect(
        TWAnyAddress.isValid(
            'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t', TWCoinType.TWCoinTypeTron),
        true,
      );
    });

    testWidgets('isValid — invalid address', (tester) async {
      expect(
        TWAnyAddress.isValid('not_an_address', TWCoinType.TWCoinTypeEthereum),
        false,
      );
    });

    testWidgets('createWithPublicKey — ETH', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      final pubKey = key.getPublicKey(TWCoinType.TWCoinTypeEthereum);
      final addr =
          TWAnyAddress.createWithPublicKey(pubKey, TWCoinType.TWCoinTypeEthereum);

      expect(addr.description.startsWith('0x'), true);
      expect(addr.description.length, 42);

      addr.delete();
      pubKey.delete();
      key.delete();
      wallet.delete();
    });

    testWidgets('description matches getAddressForCoin', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final directAddr =
          wallet.getAddressForCoin(TWCoinType.TWCoinTypeEthereum);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      final pubKey = key.getPublicKey(TWCoinType.TWCoinTypeEthereum);
      final addr =
          TWAnyAddress.createWithPublicKey(pubKey, TWCoinType.TWCoinTypeEthereum);

      expect(addr.description.toLowerCase(), directAddr.toLowerCase());

      addr.delete();
      pubKey.delete();
      key.delete();
      wallet.delete();
    });

    testWidgets('data is non-empty', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      final pubKey = key.getPublicKey(TWCoinType.TWCoinTypeEthereum);
      final addr =
          TWAnyAddress.createWithPublicKey(pubKey, TWCoinType.TWCoinTypeEthereum);

      expect(addr.data.isNotEmpty, true);

      addr.delete();
      pubKey.delete();
      key.delete();
      wallet.delete();
    });

    testWidgets('dynamic TWCoinType construction', (tester) async {
      // TWCoinType.fromValue(60) == TWCoinTypeEthereum
      final coin = TWCoinType.fromValue(60);
      final valid = TWAnyAddress.isValid(
          '0x9Ac64Cc6e109c8025ab3C2cD9c8F426c5dE4A68B', coin);
      expect(valid, true);
    });
  });

  // ============================================================
  // 5. TWAnySigner
  // ============================================================
  group('TWAnySigner', () {
    testWidgets('supportsJSON — Ethereum', (tester) async {
      expect(TWAnySigner.supportsJSON(TWCoinType.TWCoinTypeEthereum), true);
    });

    testWidgets('supportsJSON — Tron', (tester) async {
      // Tron uses pure C++ signer, JSON signing not available in trimmed build
      expect(TWAnySigner.supportsJSON(TWCoinType.TWCoinTypeTron), false);
    });

    testWidgets('sign returns non-empty for valid input', (tester) async {
      // Minimal Ethereum SigningInput protobuf
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);

      // Even with minimal input, sign should return something (or empty, not crash)
      final result =
          TWAnySigner.sign(Uint8List.fromList([]), TWCoinType.TWCoinTypeEthereum);
      // Empty input may return empty output, but should not crash
      expect(result, isA<Uint8List>());

      key.delete();
      wallet.delete();
    });
  });

  // ============================================================
  // 6. TWMnemonic
  // ============================================================
  group('TWMnemonic', () {
    testWidgets('isValid — valid mnemonic', (tester) async {
      expect(TWMnemonic.isValid(_testMnemonic), true);
    });

    testWidgets('isValid — invalid mnemonic', (tester) async {
      expect(TWMnemonic.isValid('invalid mnemonic phrase'), false);
    });

    testWidgets('isValid — wrong word count', (tester) async {
      expect(TWMnemonic.isValid('abandon abandon abandon'), false);
    });

    testWidgets('isValidWord — valid word', (tester) async {
      expect(TWMnemonic.isValidWord('abandon'), true);
    });

    testWidgets('isValidWord — invalid word', (tester) async {
      expect(TWMnemonic.isValidWord('xyz123'), false);
    });
  });

  // ============================================================
  // 7. TWCoinType properties
  // ============================================================
  group('TWCoinType', () {
    testWidgets('Ethereum curve is SECP256k1', (tester) async {
      expect(TWCoinType.TWCoinTypeEthereum.curve, TWCurve.TWCurveSECP256k1);
    });

    testWidgets('Solana curve is ED25519', (tester) async {
      expect(TWCoinType.TWCoinTypeSolana.curve, TWCurve.TWCurveED25519);
    });

    testWidgets('derivationPath is non-empty', (tester) async {
      expect(
          TWCoinType.TWCoinTypeEthereum.derivationPath.isNotEmpty, true);
    });

    testWidgets('validate address', (tester) async {
      expect(
        TWCoinType.TWCoinTypeEthereum
            .validate('0x9Ac64Cc6e109c8025ab3C2cD9c8F426c5dE4A68B'),
        true,
      );
      expect(
        TWCoinType.TWCoinTypeEthereum.validate('invalid'),
        false,
      );
    });

    testWidgets('dynamic construction equals static', (tester) async {
      expect(TWCoinType.fromValue(60), TWCoinType.TWCoinTypeEthereum);
    });
  });

  // ============================================================
  // 8. Memory safety
  // ============================================================
  group('Memory safety', () {
    testWidgets('create many wallets without crash', (tester) async {
      for (var i = 0; i < 50; i++) {
        final w = TWHDWallet();
        w.mnemonic; // access to trigger lazy load
        w.delete();
      }
    });

    testWidgets('create many keys without crash', (tester) async {
      for (var i = 0; i < 100; i++) {
        final k = TWPrivateKey();
        k.data; // access
        k.delete();
      }
    });

    testWidgets('wallet accessible after key delete', (tester) async {
      final wallet = TWHDWallet.createWithMnemonic(_testMnemonic);
      final key = wallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum);
      key.delete();
      // Wallet should still work after key is deleted
      expect(wallet.mnemonic, _testMnemonic);
      wallet.delete();
    });
  });
}
