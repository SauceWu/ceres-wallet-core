/// Counterfactual address computation for Barz passkey smart accounts.
///
/// AA-07: Provides [PasskeyBarzAddress.compute] with mandatory round-trip
/// CREATE2 verification (Pitfall 2 prevention — counterfactual address
/// mismatch).
///
/// **Round-trip verification design (Pitfall 2):**
///
/// Path A — wallet-core FFI path: Serialises the `ContractAddressInput` proto
/// and calls `TWBarz.getCounterfactualAddress` (Rust implementation).
///
/// Path B — pure-Dart path: Manually ABI-encodes the constructor arguments,
/// computes `keccak256(barzCreationCode ‖ abiEncoded)` via `TWHash.keccak256`,
/// and derives the address via `TWEthereumEip1014.create2Address`.
///
/// If both paths disagree (e.g., due to encoding bugs), [BarzAddressMismatchError]
/// is thrown before the address is returned to the caller.
library;

import 'dart:typed_data';

import '../tw_barz.dart';
import '../tw_ethereum_utils.dart';
import '../tw_hash.dart';
import 'barz_deployment.dart';
import '_proto_utils.dart' as proto;

/// Thrown when the two independent CREATE2 computation paths in
/// [PasskeyBarzAddress.compute] produce different addresses.
///
/// This indicates an internal consistency bug and should never occur during
/// normal operation. If you see this error, file an issue with the exact
/// inputs and both addresses.
final class BarzAddressMismatchError extends Error {
  /// Creates the error with a [message] describing the disagreement.
  BarzAddressMismatchError(this.message);

  /// Human-readable description of the mismatch.
  final String message;

  @override
  String toString() => 'BarzAddressMismatchError: $message';
}

/// Static utilities for computing counterfactual Barz smart-account addresses.
///
/// AA-07: `PasskeyBarzAddress.compute` derives the EVM address at which a
/// Barz smart account **will** be deployed for a given passkey owner, before
/// any on-chain deployment has occurred (counterfactual).
///
/// **Pitfall 2 prevention:** Every call performs a round-trip CREATE2
/// verification (path A via `TWBarz.getCounterfactualAddress`, path B via
/// pure-Dart ABI encoding + `TWEthereumEip1014.create2Address`) and throws
/// [BarzAddressMismatchError] if the two paths produce different addresses.
///
/// **Input constraints:**
/// - `p256PubKey`: exactly 64 bytes — raw uncompressed P-256 key without the
///   `04` prefix byte (X‖Y each 32 bytes). The `04` prefix is added internally.
/// - `salt`: valid uint32 value (0 ≤ salt ≤ 0xFFFF_FFFF). The factory uses
///   `bytes32(salt)` in CREATE2 (zero-padded to 32 bytes, big-endian).
abstract final class PasskeyBarzAddress {
  /// Computes the counterfactual address for a Barz passkey smart account.
  ///
  /// Performs a round-trip CREATE2 verification and throws
  /// [BarzAddressMismatchError] if the two independent computation paths
  /// disagree (Pitfall 2 prevention).
  ///
  /// Throws [ArgumentError] if [p256PubKey] is not exactly 64 bytes.
  /// Throws [RangeError] if [salt] is outside [0, 0xFFFF_FFFF].
  ///
  /// **Platform note:** This function calls into native wallet-core code via
  /// FFI. Tests should mark FFI-dependent cases with
  /// `skip: 'macOS host dylib unavailable — see TODO(P13)'` if the native
  /// library is not loaded.
  static String compute(
    BarzDeployment deployment,
    Uint8List p256PubKey,
    int salt,
  ) {
    if (p256PubKey.length != 64) {
      throw ArgumentError.value(
        p256PubKey,
        'p256PubKey',
        'P-256 public key must be 64 bytes (X‖Y without 04 prefix); '
            'got ${p256PubKey.length} bytes',
      );
    }
    if (salt < 0 || salt > 0xFFFFFFFF) {
      throw RangeError.value(salt, 'salt', 'Must be a uint32 (0..0xFFFF_FFFF)');
    }

    // Prepend 0x04 for uncompressed point encoding expected by wallet-core.
    final pubKeyUncompressed = Uint8List(65)..[0] = 0x04
      ..setRange(1, 65, p256PubKey);

    // Path A: FFI path via wallet-core's Rust implementation.
    final addressA = _computeViaProto(deployment, pubKeyUncompressed, salt);

    // Path B: Pure-Dart ABI encoding + keccak256 + EIP-1014 create2.
    final addressB = _computeViaCreate2(deployment, pubKeyUncompressed, salt);

    if (addressA.toLowerCase() != addressB.toLowerCase()) {
      throw BarzAddressMismatchError(
        'Round-trip CREATE2 verification failed — '
        'getCounterfactualAddress=$addressA vs create2Address=$addressB. '
        'Deployment: $deployment, salt: $salt',
      );
    }

    return addressA;
  }

  /// Computes counterfactual Barz addresses for a passkey across multiple
  /// chains in a single call.
  ///
  /// AA-15: For each [chainId] in [chainIds], looks up the registered
  /// [BarzDeployment] from [BarzDeployments.byChainId] and calls [compute]
  /// with the per-chain deployment parameters. Each entry in the result map
  /// matches the single-chain [compute] result (Pitfall 9 prevention — no
  /// cross-chain factory equivalence assumption).
  ///
  /// Throws [ArgumentError] if any [chainId] in [chainIds] has no registered
  /// [BarzDeployment].
  ///
  /// Throws [ArgumentError] if [p256PubKey] is not exactly 64 bytes.
  /// Throws [RangeError] if [salt] is outside [0, 0xFFFF_FFFF].
  static Map<int, String> acrossChains(
    Uint8List p256PubKey,
    int salt,
    List<int> chainIds,
  ) {
    // Validate inputs before iterating to give clear errors.
    if (p256PubKey.length != 64) {
      throw ArgumentError.value(
        p256PubKey,
        'p256PubKey',
        'P-256 public key must be 64 bytes (X‖Y without 04 prefix); '
            'got ${p256PubKey.length} bytes',
      );
    }
    if (salt < 0 || salt > 0xFFFFFFFF) {
      throw RangeError.value(salt, 'salt', 'Must be a uint32 (0..0xFFFF_FFFF)');
    }
    final result = <int, String>{};
    for (final chainId in chainIds) {
      final deployment = BarzDeployments.byChainId[chainId];
      if (deployment == null) {
        throw ArgumentError(
          'No BarzDeployment registered for chainId $chainId. '
          'Available chains: ${BarzDeployments.byChainId.keys.join(", ")}. '
          'Use a custom BarzDeployment for unlisted chains.',
        );
      }
      result[chainId] = compute(deployment, p256PubKey, salt);
    }
    return result;
  }

  // ── Path A: proto-serialised FFI call ────────────────────────────────────

  static String _computeViaProto(
    BarzDeployment dep,
    Uint8List pubKey65,
    int salt,
  ) {
    final pubKeyHex = '0x${_bytesToHex(pubKey65)}';
    final protoBytes = _serializeContractAddressInput(
      entryPoint: dep.entryPointV06,
      factory: dep.factory,
      accountFacet: dep.accountFacet,
      verificationFacet: dep.verificationFacet,
      facetRegistry: dep.facetRegistry,
      defaultFallback: dep.defaultFallback,
      barzCreationCodeHex: dep.barzCreationCodeHex,
      publicKeyHex: pubKeyHex,
      salt: salt,
    );
    return TWBarz.getCounterfactualAddress(protoBytes);
  }

  // ── Path B: pure-Dart CREATE2 computation ────────────────────────────────

  static String _computeViaCreate2(
    BarzDeployment dep,
    Uint8List pubKey65,
    int salt,
  ) {
    // fullBytecode = type(Barz).creationCode ‖ abi.encode(constructor args)
    final creationCode = _hexStringToBytes(dep.barzCreationCodeHex);
    final encodedArgs = _abiEncodeConstructorArgs(dep, pubKey65);

    final fullBytecode = Uint8List(creationCode.length + encodedArgs.length)
      ..setRange(0, creationCode.length, creationCode)
      ..setRange(creationCode.length, creationCode.length + encodedArgs.length,
          encodedArgs);

    final initCodeHash = TWHash.keccak256(fullBytecode);

    // BarzFactory uses `new Barz{salt: bytes32(_salt)}(...)`:
    // the CREATE2 salt is the user's uint32 value zero-padded to 32 bytes.
    final salt32 = _uint32ToBigEndian32(salt);

    return TWEthereumEip1014.create2Address(dep.factory, salt32, initCodeHash);
  }

  // ── Proto3 manual serialisation ──────────────────────────────────────────

  /// Manually serialises a `ContractAddressInput` proto3 message.
  ///
  /// Proto field numbers (all string unless noted):
  ///   1=entry_point, 2=factory, 3=account_facet, 4=verification_facet,
  ///   5=facet_registry, 6=default_fallback, 7=bytecode, 8=public_key,
  ///   9=salt (uint32).
  static Uint8List _serializeContractAddressInput({
    required String entryPoint,
    required String factory,
    required String accountFacet,
    required String verificationFacet,
    required String facetRegistry,
    required String defaultFallback,
    required String barzCreationCodeHex,
    required String publicKeyHex,
    required int salt,
  }) {
    final buf = BytesBuilder(copy: false);

    proto.writeProto3String(buf, 1, entryPoint);
    proto.writeProto3String(buf, 2, factory);
    proto.writeProto3String(buf, 3, accountFacet);
    proto.writeProto3String(buf, 4, verificationFacet);
    proto.writeProto3String(buf, 5, facetRegistry);
    proto.writeProto3String(buf, 6, defaultFallback);
    proto.writeProto3String(buf, 7, barzCreationCodeHex);
    proto.writeProto3String(buf, 8, publicKeyHex);
    proto.writeProto3Uint32(buf, 9, salt); // omitted automatically when 0

    return buf.toBytes();
  }

  // ── ABI encoding helpers ─────────────────────────────────────────────────

  /// ABI-encodes `(address accountFacet, address verificationFacet,
  ///               address entryPoint, address facetRegistry,
  ///               address defaultFallback, bytes owner)`.
  ///
  /// Mirrors the Rust `encode::encode_tokens` call in
  /// `tw_evm/src/modules/barz/core.rs::get_counterfactual_address`.
  static Uint8List _abiEncodeConstructorArgs(
    BarzDeployment dep,
    Uint8List pubKey65,
  ) {
    const headSlots = 6; // 5 addresses + 1 offset for bytes
    const headSize = headSlots * 32; // 192

    final dataLen = pubKey65.length; // 65
    final dataPadded = ((dataLen + 31) ~/ 32) * 32; // 96
    final total = headSize + 32 + dataPadded; // 192 + 32 + 96 = 320

    final result = Uint8List(total);

    // Slots 0-4: addresses (each 20 bytes right-aligned in 32-byte slot).
    final addresses = [
      dep.accountFacet,
      dep.verificationFacet,
      dep.entryPointV06,
      dep.facetRegistry,
      dep.defaultFallback,
    ];
    for (var i = 0; i < addresses.length; i++) {
      final addr = _hexAddressToBytes20(addresses[i]);
      result.setRange(i * 32 + 12, i * 32 + 32, addr);
    }

    // Slot 5: offset for the dynamic `bytes` field = headSize = 192.
    _writeUint256BE(result, 5 * 32, headSize);

    // Tail — bytes length.
    _writeUint256BE(result, headSize, dataLen);

    // Tail — bytes data (65 bytes, zero-padded to 96 bytes).
    result.setRange(headSize + 32, headSize + 32 + dataLen, pubKey65);

    return result;
  }

  // ── Low-level byte helpers ────────────────────────────────────────────────

  /// Writes [value] as a 256-bit big-endian unsigned integer at [offset].
  static void _writeUint256BE(Uint8List buf, int offset, int value) {
    // For values that fit in an int (≤ 2^63-1), write the last 8 bytes.
    var v = value;
    for (var i = 31; i >= 24; i--) {
      buf[offset + i] = v & 0xFF;
      v >>>= 8;
    }
  }

  /// Parses a 0x-prefixed Ethereum address into 20 bytes.
  static Uint8List _hexAddressToBytes20(String address) {
    var s = address;
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length != 40) {
      throw ArgumentError.value(
        address,
        'address',
        'Ethereum address must be 40 hex chars after 0x prefix (got ${s.length})',
      );
    }
    final out = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      final byte = int.tryParse(s.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw ArgumentError.value(
          address,
          'address',
          'Invalid hex character at position ${i * 2}',
        );
      }
      out[i] = byte;
    }
    return out;
  }

  /// Decodes a 0x-prefixed hex string to bytes.
  static Uint8List _hexStringToBytes(String hex) {
    var s = hex;
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    assert(s.length.isEven, 'hex string must have even length: $hex');
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  /// Encodes bytes as a lowercase hex string (no 0x prefix).
  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Encodes a uint32 [value] as a 32-byte big-endian Uint8List.
  ///
  /// Mirrors the Rust `input.salt.to_be_bytes()` + zero-pad-to-32 in
  /// `get_counterfactual_address`.
  static Uint8List _uint32ToBigEndian32(int value) {
    final out = Uint8List(32);
    out[28] = (value >> 24) & 0xFF;
    out[29] = (value >> 16) & 0xFF;
    out[30] = (value >> 8) & 0xFF;
    out[31] = value & 0xFF;
    return out;
  }
}
