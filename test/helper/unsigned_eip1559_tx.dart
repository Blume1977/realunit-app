import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

/// Builds unsigned EIP-1559 (type 2) transactions and ERC20 / ERC-677 calldata
/// for tests. Every field can be set on its own so a test can change exactly
/// one value of an otherwise valid transaction.
///
/// Only what the tests need: canonical RLP for byte strings and lists, an empty
/// access list, and fixed-size ABI words.
class UnsignedEip1559Tx {
  const UnsignedEip1559Tx({
    required this.chainId,
    required this.nonce,
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasLimit,
    required this.to,
    required this.value,
    required this.data,
    this.typeByte = 0x02,
    this.trailingHex = '',
  });

  final int chainId;
  final int nonce;
  final BigInt maxPriorityFeePerGas;
  final BigInt maxFeePerGas;
  final int gasLimit;
  final String to;
  final BigInt value;
  final Uint8List data;
  final int typeByte;

  /// Raw hex appended after the RLP payload.
  final String trailingHex;

  UnsignedEip1559Tx copyWith({
    int? chainId,
    int? nonce,
    BigInt? maxPriorityFeePerGas,
    BigInt? maxFeePerGas,
    int? gasLimit,
    String? to,
    BigInt? value,
    Uint8List? data,
    int? typeByte,
    String? trailingHex,
  }) => UnsignedEip1559Tx(
    chainId: chainId ?? this.chainId,
    nonce: nonce ?? this.nonce,
    maxPriorityFeePerGas: maxPriorityFeePerGas ?? this.maxPriorityFeePerGas,
    maxFeePerGas: maxFeePerGas ?? this.maxFeePerGas,
    gasLimit: gasLimit ?? this.gasLimit,
    to: to ?? this.to,
    value: value ?? this.value,
    data: data ?? this.data,
    typeByte: typeByte ?? this.typeByte,
    trailingHex: trailingHex ?? this.trailingHex,
  );

  /// `0x`-prefixed hex of `typeByte || rlp([...fields, []]) || trailing`.
  String toHex() {
    final body = rlpList([
      rlpInt(BigInt.from(chainId)),
      rlpInt(BigInt.from(nonce)),
      rlpInt(maxPriorityFeePerGas),
      rlpInt(maxFeePerGas),
      rlpInt(BigInt.from(gasLimit)),
      rlpBytes(hexToBytes(to)),
      rlpInt(value),
      rlpBytes(data),
      rlpList(const []),
    ]);
    final typePrefix = typeByte.toRadixString(16).padLeft(2, '0');
    return '0x$typePrefix${convert.hex.encode(body)}$trailingHex';
  }
}

const erc20TransferSelector = 'a9059cbb'; // transfer(address,uint256)
const erc20ApproveSelector = '095ea7b3'; // approve(address,uint256)
const erc677TransferAndCallSelector = '4000aea0'; // transferAndCall(address,uint256,bytes)

/// `transfer(address,uint256)` or any other `(address,uint256)` call.
Uint8List addressAmountCalldata(String selector, String address, BigInt amount) =>
    hexToBytes('$selector${addressWord(address)}${uintWord(amount)}');

/// `transferAndCall(address,uint256,bytes)` with a standard head (offset 96)
/// and the given tail bytes, zero-padded to a 32-byte boundary.
Uint8List transferAndCallCalldata(
  String recipient,
  BigInt amount, {
  Uint8List? tail,
  BigInt? offset,
}) {
  final bytes = tail ?? Uint8List(0);
  final padded = (bytes.length + 31) ~/ 32 * 32;
  final tailHex = convert.hex.encode(bytes).padRight(padded * 2, '0');
  return hexToBytes(
    '$erc677TransferAndCallSelector'
    '${addressWord(recipient)}'
    '${uintWord(amount)}'
    '${uintWord(offset ?? BigInt.from(96))}'
    '${uintWord(BigInt.from(bytes.length))}'
    '$tailHex',
  );
}

String addressWord(String address) => _strip0x(address).toLowerCase().padLeft(64, '0');

String uintWord(BigInt value) => value.toRadixString(16).padLeft(64, '0');

Uint8List hexToBytes(String hex) => Uint8List.fromList(convert.hex.decode(_strip0x(hex)));

String _strip0x(String hex) => hex.startsWith('0x') ? hex.substring(2) : hex;

Uint8List rlpInt(BigInt value) {
  if (value == BigInt.zero) return rlpBytes(Uint8List(0));
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  return rlpBytes(hexToBytes(hex));
}

Uint8List rlpBytes(Uint8List bytes) {
  if (bytes.length == 1 && bytes[0] < 0x80) return bytes;
  return Uint8List.fromList([..._lengthPrefix(bytes.length, 0x80), ...bytes]);
}

Uint8List rlpList(List<Uint8List> items) {
  final body = items.expand((e) => e).toList();
  return Uint8List.fromList([..._lengthPrefix(body.length, 0xc0), ...body]);
}

List<int> _lengthPrefix(int length, int offset) {
  if (length <= 55) return [offset + length];
  var hex = length.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final lengthBytes = convert.hex.decode(hex);
  return [offset + 55 + lengthBytes.length, ...lengthBytes];
}
