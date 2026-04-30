/// Top-of-stack ERC-4337 UserOperation assembler for Barz smart accounts.
///
/// AA-04, AA-05: Provides [Erc4337Builder] with named `v06(...)` / `v07(...)`
/// constructors, [attachSignature] as the SOLE signature→bytes site,
/// deployed-state tracking, and clientDataJSON challenge round-trip assertion.
///
/// **Version safety (Pitfall 4 prevention):**
/// Separate named constructors map to separate proto types:
/// - [Erc4337Builder.v06] → `Ethereum.UserOperation`
/// - [Erc4337Builder.v07] → `eth_proto.UserOperationV0_7`
/// Calling a v0.6-only method on a v07 builder (or vice versa) throws
/// [StateError] immediately.
///
/// **Deployed-state tracking (Pitfall 12 prevention):**
/// When `deployed: true` is passed, initCode / factory fields are set to
/// empty bytes, preventing initCode regeneration post-deploy.
///
/// **Challenge round-trip (Pitfall 3 prevention):**
/// [attachSignature] accepts an optional `clientDataJSON` parameter.
/// When provided, it parses the JSON, base64url-decodes the `challenge`
/// field, and compares with the stored [computeHash] result. A mismatch
/// throws [PasskeyChallengeMismatch].
library;

import 'dart:convert' show base64Url, jsonDecode;
import 'dart:typed_data';

import '../../bindings/ceres_wallet_core_bindings.dart' show TWCoinType;
import '../../proto/Ethereum.pb.dart' as eth_proto;
import '../../proto/Ethereum.pbenum.dart';
import '../tw_transaction_compiler.dart';
import 'barz_deployment.dart';
import 'evm_signature.dart';

/// Thrown when the passkey challenge encoded in [clientDataJSON] does not
/// match the UserOperation hash computed by [Erc4337Builder.computeHash].
///
/// This indicates the passkey adapter signed a different challenge than
/// the one the builder produced — a fatal ERC-4337 signing error.
final class PasskeyChallengeMismatch extends Error {
  /// Creates the error with a human-readable [message].
  PasskeyChallengeMismatch(this.message);

  /// Human-readable description of the mismatch.
  final String message;

  @override
  String toString() => 'PasskeyChallengeMismatch: $message';
}

/// Top-of-stack ERC-4337 UserOperation builder for Barz passkey smart
/// accounts.
///
/// Use [Erc4337Builder.v06] for EntryPoint v0.6 (monolithic initCode) or
/// [Erc4337Builder.v07] for EntryPoint v0.7 (factory + factoryData split).
///
/// **Typical flow (passkey signing):**
/// ```dart
/// final builder = Erc4337Builder.v06(
///   deployment: BarzDeployments.mainnet,
///   sender: '0xYourBarzWallet',
///   nonce: BigInt.from(1),
///   target: '0xTokenContract',
///   value: BigInt.zero,
///   innerCallData: transferCallData,
///   callGasLimit: BigInt.from(100000),
///   verificationGasLimit: BigInt.from(100000),
///   preVerificationGas: BigInt.from(46856),
///   maxFeePerGas: BigInt.parse('7033440745'),
///   maxPriorityFeePerGas: BigInt.parse('7033440745'),
///   initCode: myInitCode,   // or deployed: true
/// );
///
/// final hash = builder.computeHash();          // store hash internally
/// final sig  = await passkeySigner.signDigest(hash);
/// final sigBytes = builder.attachSignature(sig, clientDataJSON: assertion.clientDataJSON);
/// final outputBytes = builder.buildOutput(sig, clientDataJSON: assertion.clientDataJSON);
/// ```
class Erc4337Builder {
  Erc4337Builder._({
    required bool isV06,
    required BigInt chainId,
    required String sender,
    required BigInt nonce,
    required String target,
    required BigInt value,
    required Uint8List innerCallData,
    required BigInt callGasLimit,
    required BigInt verificationGasLimit,
    required BigInt preVerificationGas,
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
    // v0.6 fields
    Uint8List? initCode,
    Uint8List? paymasterAndData,
    // v0.7 fields
    String? factory,
    Uint8List? factoryData,
    String? paymaster,
    BigInt? paymasterVerificationGasLimit,
    BigInt? paymasterPostOpGasLimit,
    Uint8List? paymasterData,
    // shared
    required String entryPoint,
  })  : _isV06 = isV06,
        _chainId = chainId,
        _sender = sender,
        _nonce = nonce,
        _target = target,
        _value = value,
        _innerCallData = Uint8List.fromList(innerCallData),
        _callGasLimit = callGasLimit,
        _verificationGasLimit = verificationGasLimit,
        _preVerificationGas = preVerificationGas,
        _maxFeePerGas = maxFeePerGas,
        _maxPriorityFeePerGas = maxPriorityFeePerGas,
        _initCode = initCode != null ? Uint8List.fromList(initCode) : null,
        _paymasterAndData = paymasterAndData != null
            ? Uint8List.fromList(paymasterAndData)
            : Uint8List(0),
        _factory = factory,
        _factoryData =
            factoryData != null ? Uint8List.fromList(factoryData) : null,
        _paymaster = paymaster ?? '',
        _paymasterVerificationGasLimit = paymasterVerificationGasLimit,
        _paymasterPostOpGasLimit = paymasterPostOpGasLimit,
        _paymasterData = paymasterData != null
            ? Uint8List.fromList(paymasterData)
            : Uint8List(0),
        _entryPoint = entryPoint;

  // ── Version discriminant ────────────────────────────────────────────────
  final bool _isV06;

  // ── Common fields ───────────────────────────────────────────────────────
  final BigInt _chainId;
  final String _sender;
  final BigInt _nonce;
  final String _target;
  final BigInt _value;
  final Uint8List _innerCallData;
  final BigInt _callGasLimit;
  final BigInt _verificationGasLimit;
  final BigInt _preVerificationGas;
  final BigInt _maxFeePerGas;
  final BigInt _maxPriorityFeePerGas;
  final String _entryPoint;

  // ── v0.6-only fields ────────────────────────────────────────────────────
  final Uint8List? _initCode;
  final Uint8List _paymasterAndData;

  // ── v0.7-only fields ────────────────────────────────────────────────────
  final String? _factory;
  final Uint8List? _factoryData;
  final String _paymaster;
  final BigInt? _paymasterVerificationGasLimit;
  final BigInt? _paymasterPostOpGasLimit;
  final Uint8List _paymasterData;

  // ── Stored hash from computeHash() ─────────────────────────────────────
  Uint8List? _computedHash;

  // ── v0.6 factory constructor ─────────────────────────────────────────────

  /// Creates a v0.6 UserOperation builder.
  ///
  /// [deployment] provides the entry point address and chain ID.
  /// [sender] is the Barz smart account address (counterfactual or deployed).
  /// [nonce] is the UserOp nonce (call `EntryPoint.getNonce(sender)` for this).
  /// [target] is the inner call target address.
  /// [value] is the ETH value for the inner call (use `BigInt.zero` for ERC-20).
  /// [innerCallData] is the inner calldata bytes (e.g. ERC-20 transfer).
  /// [callGasLimit] — gas for the execution step.
  /// [verificationGasLimit] — gas for the verification step.
  /// [preVerificationGas] — overhead gas.
  /// [maxFeePerGas] — EIP-1559 max fee per gas.
  /// [maxPriorityFeePerGas] — EIP-1559 max priority fee.
  /// [initCode] — set for first UserOp (account not yet deployed). Ignored
  ///   when [deployed] is `true`.
  /// [paymasterAndData] — paymaster bytes, or empty for self-sponsored.
  /// [deployed] — when `true`, initCode is forced to empty bytes (Pitfall 12
  ///   prevention). Pass `false` and provide [initCode] for first UserOp.
  factory Erc4337Builder.v06({
    required BarzDeployment deployment,
    required String sender,
    required BigInt nonce,
    required String target,
    required BigInt value,
    required Uint8List innerCallData,
    required BigInt callGasLimit,
    required BigInt verificationGasLimit,
    required BigInt preVerificationGas,
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
    Uint8List? initCode,
    Uint8List? paymasterAndData,
    bool deployed = false,
  }) {
    return Erc4337Builder._(
      isV06: true,
      chainId: BigInt.from(deployment.chainId),
      sender: sender,
      nonce: nonce,
      target: target,
      value: value,
      innerCallData: innerCallData,
      callGasLimit: callGasLimit,
      verificationGasLimit: verificationGasLimit,
      preVerificationGas: preVerificationGas,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      initCode: deployed ? Uint8List(0) : initCode,
      paymasterAndData: paymasterAndData,
      entryPoint: deployment.entryPointV06,
    );
  }

  /// Creates a v0.7 UserOperation builder.
  ///
  /// v0.7 splits the monolithic `initCode` into separate [factory] + [factoryData]
  /// fields. When [deployed] is `true`, both are forced to empty (Pitfall 12).
  ///
  /// [paymaster], [paymasterVerificationGasLimit], [paymasterPostOpGasLimit],
  /// [paymasterData] — paymaster fields, all optional (empty = self-sponsored).
  factory Erc4337Builder.v07({
    required BarzDeployment deployment,
    required String sender,
    required BigInt nonce,
    required String target,
    required BigInt value,
    required Uint8List innerCallData,
    required BigInt callGasLimit,
    required BigInt verificationGasLimit,
    required BigInt preVerificationGas,
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
    String? factory,
    Uint8List? factoryData,
    String paymaster = '',
    BigInt? paymasterVerificationGasLimit,
    BigInt? paymasterPostOpGasLimit,
    Uint8List? paymasterData,
    bool deployed = false,
  }) {
    return Erc4337Builder._(
      isV06: false,
      chainId: BigInt.from(deployment.chainId),
      sender: sender,
      nonce: nonce,
      target: target,
      value: value,
      innerCallData: innerCallData,
      callGasLimit: callGasLimit,
      verificationGasLimit: verificationGasLimit,
      preVerificationGas: preVerificationGas,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      factory: deployed ? null : factory,
      factoryData: deployed ? null : factoryData,
      paymaster: paymaster,
      paymasterVerificationGasLimit: paymasterVerificationGasLimit,
      paymasterPostOpGasLimit: paymasterPostOpGasLimit,
      paymasterData: paymasterData,
      entryPoint: deployment.entryPointV07,
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Whether this builder targets EntryPoint v0.6.
  bool get isV06 => _isV06;

  /// Whether this builder targets EntryPoint v0.7.
  bool get isV07 => !_isV06;

  /// Builds the [eth_proto.SigningInput] proto for this UserOperation.
  ///
  /// For EOA secp256k1 signing, pass [privateKey] to embed the private key
  /// directly and use `TWAnySigner.sign(buildSigningInput(privateKey: pk)
  /// .writeToBuffer(), TWCoinType.ETH)`.
  ///
  /// For passkey signing, omit [privateKey] and use [computeHash] →
  /// [attachSignature] → [buildOutput] instead.
  eth_proto.SigningInput buildSigningInput({Uint8List? privateKey}) {
    final inner = eth_proto.Transaction(
      contractGeneric: eth_proto.Transaction_ContractGeneric(
        amount: _toBigEndianCompact(_value),
        data: _innerCallData,
      ),
    );

    final scwExecute = eth_proto.Transaction(
      scwExecute: eth_proto.Transaction_SCWalletExecute(
        transaction: inner,
        walletType: SCWalletType.Biz4337,
      ),
    );

    final input = eth_proto.SigningInput(
      chainId: _toBigEndianCompact(_chainId),
      nonce: _toBigEndianCompact(_nonce),
      txMode: TransactionMode.UserOp,
      gasLimit: _toBigEndianCompact(_callGasLimit),
      maxFeePerGas: _toBigEndianCompact(_maxFeePerGas),
      maxInclusionFeePerGas: _toBigEndianCompact(_maxPriorityFeePerGas),
      toAddress: _target,
      transaction: scwExecute,
    );

    if (privateKey != null) {
      input.privateKey = privateKey;
    }

    if (_isV06) {
      input.userOperation = eth_proto.UserOperation(
        entryPoint: _entryPoint,
        initCode: _initCode ?? Uint8List(0),
        sender: _sender,
        preVerificationGas: _toBigEndianCompact(_preVerificationGas),
        verificationGasLimit: _toBigEndianCompact(_verificationGasLimit),
        paymasterAndData: _paymasterAndData,
      );
    } else {
      final uop = eth_proto.UserOperationV0_7(
        entryPoint: _entryPoint,
        sender: _sender,
        preVerificationGas: _toBigEndianCompact(_preVerificationGas),
        verificationGasLimit: _toBigEndianCompact(_verificationGasLimit),
        paymaster: _paymaster,
      );
      final factory = _factory;
      if (factory != null) {
        uop.factory = factory;
      }
      final factoryData = _factoryData;
      if (factoryData != null) {
        uop.factoryData = factoryData;
      }
      final pvgl = _paymasterVerificationGasLimit;
      if (pvgl != null) {
        uop.paymasterVerificationGasLimit = _toBigEndianCompact(pvgl);
      }
      final pogl = _paymasterPostOpGasLimit;
      if (pogl != null) {
        uop.paymasterPostOpGasLimit = _toBigEndianCompact(pogl);
      }
      if (_paymasterData.isNotEmpty) {
        uop.paymasterData = _paymasterData;
      }
      input.userOperationV07 = uop;
    }

    return input;
  }

  /// Computes and stores the UserOperation hash via
  /// [TWTransactionCompiler.preImageHashes].
  ///
  /// The returned 32 bytes are the raw digest to pass to
  /// `EvmSigner.signDigest`. The hash is also stored internally for use by
  /// [attachSignature]'s challenge validation.
  ///
  /// **Requires the native library (FFI).** On macOS hosts without the
  /// native dylib, this throws. Use `skip: '...'` in tests.
  Uint8List computeHash() {
    final signingInput = buildSigningInput();
    final preImageOutput = TWTransactionCompiler.preImageHashes(
      TWCoinType.TWCoinTypeEthereum,
      signingInput.writeToBuffer(),
    );

    // The preimage output is a serialized PreSigningOutput proto.
    // For Ethereum, PreSigningOutput.data contains the hash bytes.
    // We parse it directly: the first field (tag 1, wire type 2) is `data`.
    final hash = _extractHashFromPreSigningOutput(preImageOutput);
    _computedHash = hash;
    return hash;
  }

  /// SOLE conversion site from [EvmSignature] to UserOp `signature` bytes.
  ///
  /// - [Secp256k1Signature] → 65-byte `r ‖ s ‖ v`
  /// - [PasskeySignature] → `formattedBlob` (≥200 bytes, Barz-formatted)
  ///
  /// When [clientDataJSON] is provided, validates that the WebAuthn challenge
  /// matches the hash stored by [computeHash]. Throws [PasskeyChallengeMismatch]
  /// on disagreement (Pitfall 3 prevention).
  ///
  /// **Call [computeHash] before calling [attachSignature] with**
  /// **[clientDataJSON] — otherwise challenge validation cannot run.**
  Uint8List attachSignature(EvmSignature sig, {String? clientDataJSON}) {
    // Challenge validation (Pitfall 3 prevention).
    if (clientDataJSON != null) {
      final hash = _computedHash;
      // Warn in debug builds if clientDataJSON is supplied but computeHash()
      // was never called — the challenge cannot be verified in this state,
      // silently weakening the Pitfall 3 defence.
      assert(
        hash != null,
        'attachSignature: clientDataJSON was provided but computeHash() has not '
        'been called yet — challenge validation is skipped (Pitfall 3 defence '
        'inactive). Call computeHash() before attachSignature().',
      );
      if (hash != null) {
        _validateChallenge(clientDataJSON, hash);
      }
    }

    // SOLE conversion from EvmSignature → raw signature bytes.
    return switch (sig) {
      Secp256k1Signature() => sig.rsv,
      PasskeySignature() => sig.formattedBlob,
    };
  }

  /// Convenience method: build the complete signed UserOperation output bytes.
  ///
  /// Calls [computeHash] (if not already called), [attachSignature], and
  /// [TWTransactionCompiler.compileWithSignatures] to produce the final
  /// serialized [Ethereum.SigningOutput].
  ///
  /// [publicKey] is the signer's public key bytes (optional; pass empty list
  /// for ERC-1271 smart-account flows where the bundler doesn't verify
  /// traditional secp256k1 recovery).
  Uint8List buildOutput(
    EvmSignature sig, {
    String? clientDataJSON,
    Uint8List? publicKey,
  }) {
    if (_computedHash == null) computeHash();
    final sigBytes = attachSignature(sig, clientDataJSON: clientDataJSON);
    final signingInput = buildSigningInput();
    return TWTransactionCompiler.compileWithSignatures(
      TWCoinType.TWCoinTypeEthereum,
      signingInput.writeToBuffer(),
      [sigBytes],
      [publicKey ?? Uint8List(0)],
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Parse the `data` field from a serialized `PreSigningOutput` proto.
  ///
  /// `PreSigningOutput` has field 1 (LEN) = `data: bytes` = the hash bytes.
  static Uint8List _extractHashFromPreSigningOutput(Uint8List encoded) {
    var i = 0;
    while (i < encoded.length) {
      final tag = encoded[i] & 0xff;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x07;
      i++;
      if (wireType == 2) {
        // LEN — read varint length
        var len = 0;
        var shift = 0;
        while (i < encoded.length) {
          final b = encoded[i++];
          len |= (b & 0x7F) << shift;
          shift += 7;
          if ((b & 0x80) == 0) break;
        }
        if (fieldNumber == 1) {
          // Field 1 is `data` in PreSigningOutput — that's the hash.
          if (i + len > encoded.length) {
            throw StateError(
              '_extractHashFromPreSigningOutput: proto field 1 length ($len) '
              'exceeds remaining buffer (${encoded.length - i} bytes). '
              'The native PreSigningOutput may be malformed or schema has changed.',
            );
          }
          return Uint8List.fromList(encoded.sublist(i, i + len));
        }
        i += len;
      } else if (wireType == 0) {
        // varint — skip
        while (i < encoded.length && (encoded[i++] & 0x80) != 0) {}
      } else if (wireType == 1) {
        // 64-bit fixed — skip 8 bytes
        i += 8;
      } else if (wireType == 5) {
        // 32-bit fixed — skip 4 bytes
        i += 4;
      } else {
        // Unknown wire type — cannot safely skip; abort parsing.
        break;
      }
    }
    // Fallback: return entire encoded bytes (shouldn't happen).
    return encoded;
  }

  /// Encode [BigInt] as big-endian compact bytes (no leading zeros).
  static Uint8List _toBigEndianCompact(BigInt v) {
    if (v == BigInt.zero) return Uint8List.fromList([0]);
    final hex = v.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final out = Uint8List(padded.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  /// Validate that the base64url-decoded challenge in [clientDataJSON] matches
  /// the expected [userOpHash]. Throws [PasskeyChallengeMismatch] on mismatch.
  static void _validateChallenge(String clientDataJSON, Uint8List userOpHash) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(clientDataJSON) as Map<String, dynamic>;
    } catch (_) {
      throw PasskeyChallengeMismatch(
        'clientDataJSON is not valid JSON',
      );
    }
    final challengeB64 = json['challenge'];
    if (challengeB64 is! String) {
      throw PasskeyChallengeMismatch(
        'clientDataJSON missing "challenge" field',
      );
    }
    // base64url-no-pad → bytes (add padding if needed).
    final normalized = base64Url.normalize(challengeB64);
    final Uint8List challengeBytes;
    try {
      challengeBytes = base64Url.decode(normalized);
    } catch (_) {
      throw PasskeyChallengeMismatch(
        'clientDataJSON.challenge is not valid base64url: "$challengeB64"',
      );
    }
    if (!_bytesEqual(challengeBytes, userOpHash)) {
      throw PasskeyChallengeMismatch(
        'clientDataJSON.challenge decoded to '
        '${challengeBytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join()} '
        'but userOpHash is '
        '${userOpHash.map((b) => b.toRadixString(16).padLeft(2, "0")).join()}',
      );
    }
  }

  /// Constant-time bytes comparison.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
