/// Shared proto3 wire-format encoding utilities for hand-rolled serialization.
///
/// Used by [PasskeyBarzAddress] (`ContractAddressInput`) and
/// [BarzDiamondCut] (`DiamondCutInput`) which both need to build proto3
/// payloads without generated Dart protobuf code.
///
/// All helpers operate on a [BytesBuilder] passed by the caller so that
/// message construction is allocation-efficient (one buffer per message).
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

/// Appends a proto3 LEN field (wire type 2) for a [String] value.
///
/// Skips the field entirely when [v] is empty (proto3 default-value omission).
void writeProto3String(BytesBuilder buf, int fieldNum, String v) {
  if (v.isEmpty) return;
  final bytes = utf8.encode(v);
  buf.addByte((fieldNum << 3) | 2); // wire type 2 = LEN
  writeVarint(buf, bytes.length);
  buf.add(bytes);
}

/// Appends a proto3 LEN field (wire type 2) for a [Uint8List] value.
///
/// Skips the field entirely when [v] is empty.
void writeProto3Bytes(BytesBuilder buf, int fieldNum, Uint8List v) {
  if (v.isEmpty) return;
  buf.addByte((fieldNum << 3) | 2); // wire type 2 = LEN
  writeVarint(buf, v.length);
  buf.add(v);
}

/// Appends a proto3 VARINT field (wire type 0) for an [int] value.
///
/// Skips the field when [value] is 0 (proto3 default-value omission).
void writeProto3Uint32(BytesBuilder buf, int fieldNum, int value) {
  if (value == 0) return;
  buf.addByte((fieldNum << 3) | 0); // wire type 0 = VARINT
  writeVarint(buf, value);
}

/// Appends a proto3 tag byte (field number + wire type).
void writeTag(BytesBuilder buf, int fieldNum, int wireType) {
  writeVarint(buf, (fieldNum << 3) | wireType);
}

/// Encodes [value] as a proto3 base-128 varint into [buf].
///
/// [value] must be non-negative. Uses unsigned right-shift (`>>>`) so that
/// the loop terminates for all non-negative values regardless of sign bit.
void writeVarint(BytesBuilder buf, int value) {
  assert(value >= 0, 'proto3 varint value must be non-negative, got $value');
  while (value > 0x7F) {
    buf.addByte((value & 0x7F) | 0x80);
    value >>>= 7;
  }
  buf.addByte(value & 0x7F);
}
