import 'dart:ffi';
import 'dart:typed_data';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_data_helper.dart';
import 'tw_string_helper.dart';

/// Cast a TWString pointer to a TWString1 pointer (same underlying type).
Pointer<raw.TWString1> _castToTWString1(Pointer<raw.TWString> ptr) =>
    Pointer<raw.TWString1>.fromAddress(ptr.address);

/// Static utilities for Ethereum address checksumming.
class TWEthereumAddress {
  TWEthereumAddress._();

  /// Returns the EIP-55 checksummed form of [address].
  static String checksummed(String address) {
    final twAddress = toTWString(address);
    try {
      final result = lib.TWEthereumAddressChecksummed(twAddress);
      return fromTWString(result);
    } finally {
      deleteTWString(twAddress);
    }
  }
}

/// Static utilities for Ethereum RLP encoding.
class TWEthereumRlp {
  TWEthereumRlp._();

  /// Encode an `EthereumRlp::Proto::EncodingInput` and return `EncodingOutput` bytes.
  static Uint8List encode(raw.TWCoinType coin, Uint8List input) {
    final twInput = toTWData1(input);
    try {
      final result = lib.TWEthereumRlpEncode(coin, twInput);
      return fromTWData1(result);
    } finally {
      deleteTWData(castTWData1(twInput));
    }
  }
}

/// Static utilities for EIP-1014 (CREATE2) address derivation.
class TWEthereumEip1014 {
  TWEthereumEip1014._();

  /// Returns the EIP-1014 CREATE2 address for the given inputs.
  static String create2Address(
    String from,
    Uint8List salt,
    Uint8List initCodeHash,
  ) {
    final twFrom = toTWString(from);
    final twSalt = toTWData1(salt);
    final twInitCodeHash = toTWData1(initCodeHash);
    try {
      final result =
          lib.TWEthereumEip1014Create2Address(twFrom, twSalt, twInitCodeHash);
      return fromTWString(result);
    } finally {
      deleteTWString(twFrom);
      deleteTWData(castTWData1(twSalt));
      deleteTWData(castTWData1(twInitCodeHash));
    }
  }
}

/// Static utilities for EIP-1967 transparent proxy init code generation.
class TWEthereumEip1967 {
  TWEthereumEip1967._();

  /// Returns the EIP-1967 proxy init code for [logicAddress] with [data].
  static Uint8List proxyInitCode(String logicAddress, Uint8List data) {
    final twLogicAddress = toTWString(logicAddress);
    final twData = toTWData1(data);
    try {
      final result =
          lib.TWEthereumEip1967ProxyInitCode(twLogicAddress, twData);
      return fromTWData1(result);
    } finally {
      deleteTWString(twLogicAddress);
      deleteTWData(castTWData1(twData));
    }
  }
}

/// Static utilities for EIP-2645 StarkEx HD path derivation.
class TWEthereumEip2645 {
  TWEthereumEip2645._();

  /// Returns the StarkEx HD path for the given Ethereum address and indices.
  static String getPath(
    String ethAddress,
    String layer,
    String application,
    String index,
  ) {
    final twEthAddress = toTWString(ethAddress);
    final twLayer = toTWString(layer);
    final twApplication = toTWString(application);
    final twIndex = toTWString(index);
    try {
      final result = lib.TWEthereumEip2645GetPath(
        twEthAddress,
        twLayer,
        twApplication,
        twIndex,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twEthAddress);
      deleteTWString(twLayer);
      deleteTWString(twApplication);
      deleteTWString(twIndex);
    }
  }
}

/// Static utilities for StarkWare Stark key derivation.
class TWStarkWare {
  TWStarkWare._();

  /// Returns the hex-encoded Stark private key derived from an Ethereum signature.
  ///
  /// The native call accepts a `TWDerivationPath*`, which is created from
  /// [derivationPath] and freed before returning. Returns `null` if the
  /// underlying call fails.
  static String? getStarkKeyFromSignature(
    String derivationPath,
    String ethSignature,
  ) {
    final twPath = toTWString(derivationPath);
    final twSignature = toTWString(ethSignature);
    final pathPtr = lib.TWDerivationPathCreateWithString(twPath);
    try {
      if (pathPtr == nullptr) return null;
      final pkPtr = lib.TWStarkWareGetStarkKeyFromSignature(
        pathPtr,
        _castToTWString1(twSignature),
      );
      if (pkPtr == nullptr) return null;
      try {
        final dataPtr = lib.TWPrivateKeyData(pkPtr);
        final bytes = fromTWData1(dataPtr);
        return _bytesToHex(bytes);
      } finally {
        lib.TWPrivateKeyDelete(pkPtr);
      }
    } finally {
      if (pathPtr != nullptr) lib.TWDerivationPathDelete(pathPtr);
      deleteTWString(twPath);
      deleteTWString(twSignature);
    }
  }

  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
