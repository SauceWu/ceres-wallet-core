import 'dart:ffi';
import '../bindings/ceres_wallet_core_bindings.dart' as raw;
import 'native.dart';
import 'tw_string_helper.dart';

final _indexFinalizer = Finalizer<Pointer<raw.TWDerivationPathIndex>>((ptr) {
  lib.TWDerivationPathIndexDelete(ptr);
});

final _pathFinalizer = Finalizer<Pointer<raw.TWDerivationPath>>((ptr) {
  lib.TWDerivationPathDelete(ptr);
});

/// A single index segment of a BIP-32/44 derivation path (e.g. `44'`).
class TWDerivationPathIndex {
  Pointer<raw.TWDerivationPathIndex>? _ptr;

  TWDerivationPathIndex._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _indexFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create an index with [value] and optional [hardened] flag.
  factory TWDerivationPathIndex.create(int value, {bool hardened = false}) {
    final ptr = lib.TWDerivationPathIndexCreate(value, hardened);
    if (ptr == nullptr) {
      throw StateError('Failed to create derivation path index');
    }
    return TWDerivationPathIndex._wrap(ptr);
  }

  /// Wrap an existing native pointer (internal use).
  factory TWDerivationPathIndex.fromPointer(
    Pointer<raw.TWDerivationPathIndex> ptr,
  ) => TWDerivationPathIndex._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWDerivationPathIndex> get pointer => _ptr!;

  /// Numeric value of the index.
  int get value => lib.TWDerivationPathIndexValue(_ptr!);

  /// Whether this index is hardened.
  bool get hardened => lib.TWDerivationPathIndexHardened(_ptr!);

  /// String description of the index (e.g. `44'`).
  String get description =>
      fromTWString(lib.TWDerivationPathIndexDescription(_ptr!));

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _indexFinalizer.detach(this);
      lib.TWDerivationPathIndexDelete(_ptr!);
      _ptr = null;
    }
  }
}

/// A BIP-32/44 derivation path such as `m/44'/60'/0'/0/0`.
class TWDerivationPath {
  Pointer<raw.TWDerivationPath>? _ptr;

  TWDerivationPath._wrap(this._ptr) {
    if (_ptr != null && _ptr != nullptr) {
      _pathFinalizer.attach(this, _ptr!, detach: this);
    }
  }

  /// Create a derivation path from its components.
  factory TWDerivationPath.create({
    required raw.TWPurpose purpose,
    required int coin,
    required int account,
    required int change,
    required int address,
  }) {
    final ptr = lib.TWDerivationPathCreate(
      purpose,
      coin,
      account,
      change,
      address,
    );
    if (ptr == nullptr) {
      throw StateError('Failed to create derivation path');
    }
    return TWDerivationPath._wrap(ptr);
  }

  /// Parse a derivation path from its string form (e.g. `m/44'/60'/0'/0/0`).
  factory TWDerivationPath.createWithString(String path) {
    final twStr = toTWString(path);
    try {
      final ptr = lib.TWDerivationPathCreateWithString(twStr);
      if (ptr == nullptr) {
        throw ArgumentError('Invalid derivation path: $path');
      }
      return TWDerivationPath._wrap(ptr);
    } finally {
      deleteTWString(twStr);
    }
  }

  /// Wrap an existing native pointer (internal use).
  factory TWDerivationPath.fromPointer(Pointer<raw.TWDerivationPath> ptr) =>
      TWDerivationPath._wrap(ptr);

  /// Native pointer.
  Pointer<raw.TWDerivationPath> get pointer => _ptr!;

  /// Number of index segments in the path.
  int get indicesCount => lib.TWDerivationPathIndicesCount(_ptr!);

  /// Returns the index segment at [index]. Caller owns the returned object.
  TWDerivationPathIndex indexAt(int index) {
    final ptr = lib.TWDerivationPathIndexAt(_ptr!, index);
    return TWDerivationPathIndex.fromPointer(ptr);
  }

  /// Purpose component of the path.
  raw.TWPurpose get purpose => lib.TWDerivationPathPurpose(_ptr!);

  /// Coin type component of the path.
  int get coin => lib.TWDerivationPathCoin(_ptr!);

  /// Account component of the path.
  int get account => lib.TWDerivationPathAccount(_ptr!);

  /// Change component of the path.
  int get change => lib.TWDerivationPathChange(_ptr!);

  /// Address component of the path.
  int get address => lib.TWDerivationPathAddress(_ptr!);

  /// String description of the path (e.g. `m/44'/60'/0'/0/0`).
  String get description =>
      fromTWString(lib.TWDerivationPathDescription(_ptr!));

  /// Release native resources. Safe to call multiple times.
  void delete() {
    if (_ptr != null && _ptr != nullptr) {
      _pathFinalizer.detach(this);
      lib.TWDerivationPathDelete(_ptr!);
      _ptr = null;
    }
  }

  @override
  String toString() => description;
}
