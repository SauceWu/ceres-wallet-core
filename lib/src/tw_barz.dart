import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_public_key.dart';
import 'tw_string_helper.dart';

/// Cast a TWString pointer to a TWString1 pointer (same underlying type).
Pointer<raw.TWString1> _castToTWString1(Pointer<raw.TWString> ptr) =>
    Pointer<raw.TWString1>.fromAddress(ptr.address);

/// Cast a TWString1 pointer to a TWString pointer (same underlying type).
Pointer<raw.TWString> _castFromTWString1(Pointer<raw.TWString1> ptr) =>
    Pointer<raw.TWString>.fromAddress(ptr.address);

/// Wrappers for Trust Wallet Core's Barz — ERC-4337 Account Abstraction
/// smart-account helpers (counterfactual addresses, init code, signature
/// formatting).
class TWBarz {
  TWBarz._();

  /// Returns the EIP-7702 authorization hash for the given chain, contract and nonce.
  static Uint8List getAuthorizationHash(
    Uint8List chainId,
    String contractAddress,
    Uint8List nonce,
  ) {
    final twChainId = toTWData1(chainId);
    final twContractAddress = toTWString(contractAddress);
    final twNonce = toTWData1(nonce);
    try {
      final result = lib.TWBarzGetAuthorizationHash(
        twChainId,
        _castToTWString1(twContractAddress),
        twNonce,
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twChainId));
      deleteTWString(twContractAddress);
      deleteTWData(castTWData1(twNonce));
    }
  }

  /// Calculates the counterfactual address for the smart-contract wallet
  /// from a serialized `ContractAddressInput` protobuf payload.
  static String getCounterfactualAddress(Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWBarzGetCounterfactualAddress(twInput);
      return fromTWString(_castFromTWString1(result));
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Returns the encoded `diamondCut` function call used for Barz upgrades
  /// from a serialized `DiamondCutInput` protobuf payload.
  static Uint8List getDiamondCutCode(Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWBarzGetDiamondCutCode(twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }

  /// Returns the EIP-712 encoded hash of an ERC-4337 user operation.
  static Uint8List getEncodedHash(
    Uint8List chainId,
    String codeAddress,
    String codeName,
    String codeVersion,
    String typeHash,
    String domainSeparatorHash,
    String sender,
    String userOpHash,
  ) {
    final twChainId = toTWData1(chainId);
    final twCodeAddress = toTWString(codeAddress);
    final twCodeName = toTWString(codeName);
    final twCodeVersion = toTWString(codeVersion);
    final twTypeHash = toTWString(typeHash);
    final twDomainSeparatorHash = toTWString(domainSeparatorHash);
    final twSender = toTWString(sender);
    final twUserOpHash = toTWString(userOpHash);
    try {
      final result = lib.TWBarzGetEncodedHash(
        twChainId,
        _castToTWString1(twCodeAddress),
        _castToTWString1(twCodeName),
        _castToTWString1(twCodeVersion),
        _castToTWString1(twTypeHash),
        _castToTWString1(twDomainSeparatorHash),
        _castToTWString1(twSender),
        _castToTWString1(twUserOpHash),
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twChainId));
      deleteTWString(twCodeAddress);
      deleteTWString(twCodeName);
      deleteTWString(twCodeVersion);
      deleteTWString(twTypeHash);
      deleteTWString(twDomainSeparatorHash);
      deleteTWString(twSender);
      deleteTWString(twUserOpHash);
    }
  }

  /// Formats a WebAuthn signature into the bytes expected by Barz.
  static Uint8List getFormattedSignature(
    Uint8List signature,
    Uint8List challenge,
    Uint8List authenticatorData,
    String clientDataJson,
  ) {
    final twSignature = toTWData1(signature);
    final twChallenge = toTWData1(challenge);
    final twAuthenticatorData = toTWData1(authenticatorData);
    final twClientDataJson = toTWString(clientDataJson);
    try {
      final result = lib.TWBarzGetFormattedSignature(
        twSignature,
        twChallenge,
        twAuthenticatorData,
        _castToTWString1(twClientDataJson),
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twSignature));
      deleteTWData(castTWData1(twChallenge));
      deleteTWData(castTWData1(twAuthenticatorData));
      deleteTWString(twClientDataJson);
    }
  }

  /// Returns the ERC-4337 user operation `initCode` for a Barz wallet.
  static Uint8List getInitCode(
    String factory,
    TWPublicKey publicKey,
    String verificationFacet,
    int salt,
  ) {
    final twFactory = toTWString(factory);
    final twVerificationFacet = toTWString(verificationFacet);
    try {
      final result = lib.TWBarzGetInitCode(
        _castToTWString1(twFactory),
        publicKey.pointer,
        _castToTWString1(twVerificationFacet),
        salt,
      );
      return fromTWData1(result);
    } finally {
      deleteTWString(twFactory);
      deleteTWString(twVerificationFacet);
    }
  }

  /// Returns the prefixed message hash that Barz signs for messages and typed data.
  static Uint8List getPrefixedMsgHash(
    Uint8List msgHash,
    String barzAddress,
    int chainId,
  ) {
    final twMsgHash = toTWData1(msgHash);
    final twBarzAddress = toTWString(barzAddress);
    try {
      final result = lib.TWBarzGetPrefixedMsgHash(
        twMsgHash,
        _castToTWString1(twBarzAddress),
        chainId,
      );
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twMsgHash));
      deleteTWString(twBarzAddress);
    }
  }

  /// Signs the given hash with the supplied private key, returning the raw signature bytes.
  static Uint8List getSignedHash(String hash, String privateKey) {
    final twHash = toTWString(hash);
    final twPrivateKey = toTWString(privateKey);
    try {
      final result = lib.TWBarzGetSignedHash(
        _castToTWString1(twHash),
        _castToTWString1(twPrivateKey),
      );
      return fromTWData1(result);
    } finally {
      deleteTWString(twHash);
      deleteTWString(twPrivateKey);
    }
  }

  /// Signs an EIP-7702 authorization tuple and returns the encoded signed authorization.
  static String signAuthorization(
    Uint8List chainId,
    String contractAddress,
    Uint8List nonce,
    String privateKey,
  ) {
    final twChainId = toTWData1(chainId);
    final twContractAddress = toTWString(contractAddress);
    final twNonce = toTWData1(nonce);
    final twPrivateKey = toTWString(privateKey);
    try {
      final result = lib.TWBarzSignAuthorization(
        twChainId,
        _castToTWString1(twContractAddress),
        twNonce,
        _castToTWString1(twPrivateKey),
      );
      return fromTWString(_castFromTWString1(result));
    } finally {
      deleteTWData(castTWData1(twChainId));
      deleteTWString(twContractAddress);
      deleteTWData(castTWData1(twNonce));
      deleteTWString(twPrivateKey);
    }
  }
}
