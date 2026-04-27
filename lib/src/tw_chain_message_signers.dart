import 'native.dart';
import 'tw_private_key.dart';
import 'tw_public_key.dart';
import 'tw_string_helper.dart';

/// Static wrapper around Trust Wallet Core's `TWBitcoinMessageSigner`.
///
/// Implements the legacy "Bitcoin Signed Message" personal-sign scheme used by
/// Bitcoin Core / Electrum. Signatures are Base64-encoded and bound to a
/// legacy (P2PKH) address.
class TWBitcoinMessageSigner {
  TWBitcoinMessageSigner._();

  /// Sign [message] for the given legacy [address]. Returns a Base64-encoded
  /// signature, or empty string on failure.
  static String signMessage(
    TWPrivateKey privateKey,
    String address,
    String message,
  ) {
    final twAddress = toTWString(address);
    final twMsg = toTWString(message);
    try {
      final result = lib.TWBitcoinMessageSignerSignMessage(
        privateKey.pointer,
        twAddress,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twAddress);
      deleteTWString(twMsg);
    }
  }

  /// Verify a Base64-encoded [signature] against [address] and [message].
  static bool verifyMessage(
    String address,
    String message,
    String signature,
  ) {
    final twAddress = toTWString(address);
    final twMsg = toTWString(message);
    final twSig = toTWString(signature);
    try {
      return lib.TWBitcoinMessageSignerVerifyMessage(
        twAddress,
        twMsg,
        twSig,
      );
    } finally {
      deleteTWString(twAddress);
      deleteTWString(twMsg);
      deleteTWString(twSig);
    }
  }
}

/// Static wrapper around Trust Wallet Core's `TWTronMessageSigner`.
///
/// Tron `personal_sign` over the TRC-style message prefix. Signatures are
/// hex-encoded 65-byte recoverable secp256k1 signatures.
class TWTronMessageSigner {
  TWTronMessageSigner._();

  /// Sign [message]. Returns a hex-encoded signature, or empty string on failure.
  static String signMessage(TWPrivateKey privateKey, String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWTronMessageSignerSignMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Verify a hex-encoded [signature] against [pubKey] and [message].
  static bool verifyMessage(
    TWPublicKey pubKey,
    String message,
    String signature,
  ) {
    final twMsg = toTWString(message);
    final twSig = toTWString(signature);
    try {
      return lib.TWTronMessageSignerVerifyMessage(
        pubKey.pointer,
        twMsg,
        twSig,
      );
    } finally {
      deleteTWString(twMsg);
      deleteTWString(twSig);
    }
  }
}

/// Static wrapper around Trust Wallet Core's `TWTONMessageSigner`.
///
/// Signs arbitrary messages on TON using the wallet-core TON message scheme.
/// Signatures are hex-encoded.
class TWTONMessageSigner {
  TWTONMessageSigner._();

  /// Sign [message]. Returns a hex-encoded signature, or empty string on failure.
  static String signMessage(TWPrivateKey privateKey, String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWTONMessageSignerSignMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }
}

/// Static wrapper around Trust Wallet Core's `TWTezosMessageSigner`.
///
/// Implements the Tezos "Signing Standard" (TZIP-affiliated `signPayload`
/// flow): format → input-to-payload → sign → verify. Signatures are
/// Base58Check-encoded (e.g. `edsig…`).
class TWTezosMessageSigner {
  TWTezosMessageSigner._();

  /// Format a human-readable [message] with an originating [url] into the
  /// canonical Tezos signing string.
  static String formatMessage(String message, String url) {
    final twMsg = toTWString(message);
    final twUrl = toTWString(url);
    try {
      final result = lib.TWTezosMessageSignerFormatMessage(twMsg, twUrl);
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
      deleteTWString(twUrl);
    }
  }

  /// Convert a formatted [message] into the hex payload that gets signed.
  static String inputToPayload(String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWTezosMessageSignerInputToPayload(twMsg);
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Sign [hexPayload] (output of [inputToPayload]). Returns a Base58-encoded
  /// signature, or empty string on failure.
  static String signMessage(TWPrivateKey privateKey, String hexPayload) {
    final twMsg = toTWString(hexPayload);
    try {
      final result = lib.TWTezosMessageSignerSignMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Verify a Base58-encoded [base58Sig] against [pubKey] and [hexPayload].
  static bool verifyMessage(
    TWPublicKey pubKey,
    String hexPayload,
    String base58Sig,
  ) {
    final twMsg = toTWString(hexPayload);
    final twSig = toTWString(base58Sig);
    try {
      return lib.TWTezosMessageSignerVerifyMessage(
        pubKey.pointer,
        twMsg,
        twSig,
      );
    } finally {
      deleteTWString(twMsg);
      deleteTWString(twSig);
    }
  }
}

/// Static wrapper around Trust Wallet Core's `TWStarkExMessageSigner`.
///
/// Signs and verifies messages on the StarkEx curve (used by L2s like
/// dYdX-v3 and Immutable X). Signatures are hex-encoded.
class TWStarkExMessageSigner {
  TWStarkExMessageSigner._();

  /// Sign [message]. Returns a hex-encoded signature, or empty string on failure.
  static String signMessage(TWPrivateKey privateKey, String message) {
    final twMsg = toTWString(message);
    try {
      final result = lib.TWStarkExMessageSignerSignMessage(
        privateKey.pointer,
        twMsg,
      );
      return fromTWString(result);
    } finally {
      deleteTWString(twMsg);
    }
  }

  /// Verify a hex-encoded [signature] against [pubKey] and [message].
  static bool verifyMessage(
    TWPublicKey pubKey,
    String message,
    String signature,
  ) {
    final twMsg = toTWString(message);
    final twSig = toTWString(signature);
    try {
      return lib.TWStarkExMessageSignerVerifyMessage(
        pubKey.pointer,
        twMsg,
        twSig,
      );
    } finally {
      deleteTWString(twMsg);
      deleteTWString(twSig);
    }
  }
}
