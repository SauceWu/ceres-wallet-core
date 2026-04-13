import 'native.dart';
import 'tw_string_helper.dart';

/// BIP39 mnemonic utilities.
class TWMnemonic {
  TWMnemonic._();

  /// Check if a mnemonic phrase is valid.
  static bool isValid(String mnemonic) {
    final twStr = toTWString(mnemonic);
    try {
      return lib.TWMnemonicIsValid(twStr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Check if a single mnemonic word is valid.
  static bool isValidWord(String word) {
    final twStr = toTWString(word);
    try {
      return lib.TWMnemonicIsValidWord(twStr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Suggest the closest valid word for a misspelled word.
  static String suggest(String prefix) {
    final twStr = toTWString(prefix);
    try {
      return fromTWString(lib.TWMnemonicSuggest(twStr));
    } finally {
      deleteTWString(twStr);
    }
  }
}
