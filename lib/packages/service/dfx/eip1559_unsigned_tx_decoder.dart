/// Decoder for an unsigned EIP-1559 (type 2) ZCHF transfer. The software-wallet
/// pay does not ask the customer to sign this transfer. The customer signs only
/// the EIP-7702 delegation, and the relayer broadcasts the payment.
///
/// The decoder checks raw bytes against `tokenAddress`, `recipient`,
/// `amountWei`, and `chainId`, and rejects a shape it does not understand. It
/// is not a general-purpose Ethereum RLP/ABI library.
library;

import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:realunit_wallet/packages/service/dfx/exceptions/payment/pay_exceptions.dart';

/// A decoded unsigned EIP-1559 transaction. The fields are what a byte check
/// compares with `RealUnitOcpPayUnsignedTransactionDto`. The customer does not
/// sign this transaction.
class DecodedEip1559Transaction {
  final BigInt chainId;

  /// Sender nonce, from RLP field index 1.
  final BigInt nonce;

  /// EIP-1559 max priority fee per gas (wei), from RLP field index 2.
  final BigInt maxPriorityFeePerGas;

  /// EIP-1559 max fee per gas (wei), from RLP field index 3.
  final BigInt maxFeePerGas;

  /// Gas limit, from RLP field index 4.
  final BigInt gasLimit;

  /// The tx's `to` address, normalized to `0x` + 40 lowercase hex chars.
  final String to;

  /// The tx's native ETH value (wei). An ERC20 transfer must carry 0.
  final BigInt value;

  /// The tx's calldata, unparsed.
  final Uint8List data;

  const DecodedEip1559Transaction({
    required this.chainId,
    required this.nonce,
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasLimit,
    required this.to,
    required this.value,
    required this.data,
  });
}

/// Decodes an RLP-encoded unsigned type-2 (EIP-1559) transaction hex. Throws
/// `PayUnsignedTxMismatchException` on any structural anomaly. The customer
/// does not sign this transaction.
abstract final class Eip1559UnsignedTxDecoder {
  static const _typeByte = 0x02;
  static const _fieldCount = 9;
  static const _chainIdFieldIndex = 0;
  static const _nonceFieldIndex = 1;
  static const _maxPriorityFeePerGasFieldIndex = 2;
  static const _maxFeePerGasFieldIndex = 3;
  static const _gasLimitFieldIndex = 4;
  static const _toFieldIndex = 5;
  static const _valueFieldIndex = 6;
  static const _dataFieldIndex = 7;
  static const _accessListFieldIndex = 8;

  static DecodedEip1559Transaction decode(String rawTransaction) {
    final hex = rawTransaction.startsWith('0x') ? rawTransaction.substring(2) : rawTransaction;
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(convert.hex.decode(hex));
    } on FormatException {
      throw const PayUnsignedTxMismatchException('unsigned tx is not valid hex');
    }

    if (bytes.isEmpty || bytes[0] != _typeByte) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx is not an EIP-1559 (type 2) transaction',
      );
    }

    final decoded = _decodeItem(bytes, 1);
    if (decoded.end != bytes.length) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx has trailing bytes after RLP decode',
      );
    }
    final root = decoded.value;
    if (root is! List<Object>) {
      throw const PayUnsignedTxMismatchException('unsigned tx RLP root is not a list');
    }
    if (root.length != _fieldCount) {
      throw PayUnsignedTxMismatchException(
        'unsigned tx has ${root.length} RLP fields, expected $_fieldCount',
      );
    }

    final to = root[_toFieldIndex];
    if (to is! Uint8List || to.length != 20) {
      throw const PayUnsignedTxMismatchException('unsigned tx "to" is not a 20-byte address');
    }
    final data = root[_dataFieldIndex];
    if (data is! Uint8List) {
      throw const PayUnsignedTxMismatchException('unsigned tx "data" is not a byte string');
    }
    // This decoder only understands the plain ERC20 transfer, which has an
    // empty access list. Anything else is rejected.
    final accessList = root[_accessListFieldIndex];
    if (accessList is! List<Object> || accessList.isNotEmpty) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx "accessList" must be an empty RLP list',
      );
    }

    // Canonical RLP for the six quantity fields. Leading-zero-byte integers are
    // non-canonical and rejected before any BigInt conversion.
    _requireCanonicalInteger(root[_chainIdFieldIndex], 'chainId');
    _requireCanonicalInteger(root[_nonceFieldIndex], 'nonce');
    _requireCanonicalInteger(root[_maxPriorityFeePerGasFieldIndex], 'maxPriorityFeePerGas');
    _requireCanonicalInteger(root[_maxFeePerGasFieldIndex], 'maxFeePerGas');
    _requireCanonicalInteger(root[_gasLimitFieldIndex], 'gasLimit');
    _requireCanonicalInteger(root[_valueFieldIndex], 'value');

    return DecodedEip1559Transaction(
      chainId: _asBigInt(root[_chainIdFieldIndex]),
      nonce: _asBigInt(root[_nonceFieldIndex]),
      maxPriorityFeePerGas: _asBigInt(root[_maxPriorityFeePerGasFieldIndex]),
      maxFeePerGas: _asBigInt(root[_maxFeePerGasFieldIndex]),
      gasLimit: _asBigInt(root[_gasLimitFieldIndex]),
      to: '0x${convert.hex.encode(to)}',
      value: _asBigInt(root[_valueFieldIndex]),
      data: data,
    );
  }

  /// Canonical RLP integers: empty byte string = 0; otherwise no leading zero byte.
  /// Zero itself must be the empty string (`0x80`), never `0x00`.
  static void _requireCanonicalInteger(Object field, String name) {
    if (field is! Uint8List) {
      throw PayUnsignedTxMismatchException(
        'unsigned tx "$name" is not a byte string',
      );
    }
    if (field.isNotEmpty && field[0] == 0) {
      throw PayUnsignedTxMismatchException(
        'unsigned tx "$name" has a non-canonical leading zero byte',
      );
    }
  }

  static BigInt _asBigInt(Object field) {
    if (field is! Uint8List) {
      throw const PayUnsignedTxMismatchException('unsigned tx field is not a byte string');
    }
    if (field.isEmpty) return BigInt.zero;
    return BigInt.parse(convert.hex.encode(field), radix: 16);
  }

  /// Decodes a single RLP item starting at [pos]. Returns the decoded value (`Uint8List` for a
  /// byte string, `List<Object>` for a list) and the index immediately after the item.
  static ({Object value, int end}) _decodeItem(Uint8List data, int pos) {
    if (pos >= data.length) {
      throw const PayUnsignedTxMismatchException('RLP: unexpected end of data');
    }
    final prefix = data[pos];
    if (prefix < 0x80) {
      return (value: Uint8List.fromList([prefix]), end: pos + 1);
    } else if (prefix < 0xb8) {
      final length = prefix - 0x80;
      final start = pos + 1;
      _requireBytes(data, start, length);
      final value = data.sublist(start, start + length);
      if (length == 1 && value[0] < 0x80) {
        throw const PayUnsignedTxMismatchException(
          'RLP: non-canonical single-byte short string (must be the bare byte, not a length-1 string)',
        );
      }
      return (value: value, end: start + length);
    } else if (prefix < 0xc0) {
      final lengthOfLength = prefix - 0xb7;
      final start = pos + 1;
      _requireBytes(data, start, lengthOfLength);
      final length = _bytesToLength(data.sublist(start, start + lengthOfLength));
      // Non-minimal long-form string: lengths ≤ 55 must use the short-form prefix.
      if (length <= 55) {
        throw const PayUnsignedTxMismatchException(
          'RLP: non-minimal long-form string length encoding',
        );
      }
      final start2 = start + lengthOfLength;
      _requireBytes(data, start2, length);
      return (value: data.sublist(start2, start2 + length), end: start2 + length);
    } else if (prefix < 0xf8) {
      final length = prefix - 0xc0;
      final start = pos + 1;
      _requireBytes(data, start, length);
      return _decodeListBody(data, start, start + length);
    } else {
      final lengthOfLength = prefix - 0xf7;
      final start = pos + 1;
      _requireBytes(data, start, lengthOfLength);
      final length = _bytesToLength(data.sublist(start, start + lengthOfLength));
      // Non-minimal long-form list: lengths ≤ 55 must use the short-form prefix.
      if (length <= 55) {
        throw const PayUnsignedTxMismatchException(
          'RLP: non-minimal long-form list length encoding',
        );
      }
      final start2 = start + lengthOfLength;
      _requireBytes(data, start2, length);
      return _decodeListBody(data, start2, start2 + length);
    }
  }

  static ({Object value, int end}) _decodeListBody(Uint8List data, int start, int end) {
    final items = <Object>[];
    var pos = start;
    while (pos < end) {
      final item = _decodeItem(data, pos);
      items.add(item.value);
      pos = item.end;
    }
    if (pos != end) {
      throw const PayUnsignedTxMismatchException('RLP: list body length mismatch');
    }
    return (value: items, end: end);
  }

  static void _requireBytes(Uint8List data, int start, int length) {
    if (start < 0 || length < 0 || start + length > data.length) {
      throw const PayUnsignedTxMismatchException('RLP: declared length exceeds available data');
    }
  }

  static int _bytesToLength(Uint8List bytes) {
    // Cap length-of-length at 4 bytes so `start + length` in long-form RLP branches
    // cannot overflow a 64-bit signed int (lengthOfLength=8 can encode ~2^63 and wrap
    // past `_requireBytes`, letting a raw RangeError escape from `sublist`).
    if (bytes.length > 4) {
      throw const PayUnsignedTxMismatchException(
        'RLP: declared length-of-length exceeds practical transaction size',
      );
    }
    // Minimal length-of-length encoding never needs a leading zero byte.
    if (bytes.length > 1 && bytes[0] == 0) {
      throw const PayUnsignedTxMismatchException(
        'RLP: non-minimal length-of-length encoding (leading zero byte)',
      );
    }
    var value = 0;
    for (final b in bytes) {
      value = (value << 8) | b;
    }
    return value;
  }
}

/// A decoded ERC20 `transfer(address,uint256)` call.
class DecodedErc20Transfer {
  /// Normalized to `0x` + 40 lowercase hex chars.
  final String recipient;
  final BigInt amountWei;

  const DecodedErc20Transfer({required this.recipient, required this.amountWei});
}

/// Decodes ERC20 `transfer(address,uint256)` calldata. Anything else is
/// rejected. The customer does not sign this call; the relayer broadcasts it.
abstract final class Erc20TransferCalldataDecoder {
  static const _selector = [0xa9, 0x05, 0x9c, 0xbb]; // transfer(address,uint256)
  static const _calldataLength = 68; // 4 (selector) + 32 (address) + 32 (amount)

  static DecodedErc20Transfer decode(Uint8List data) {
    if (data.length != _calldataLength) {
      throw PayUnsignedTxMismatchException(
        'unsigned tx calldata is ${data.length} bytes, expected $_calldataLength '
        '(ERC20 transfer)',
      );
    }
    for (var i = 0; i < _selector.length; i++) {
      if (data[i] != _selector[i]) {
        throw const PayUnsignedTxMismatchException(
          'unsigned tx calldata is not an ERC20 transfer(address,uint256) call',
        );
      }
    }

    final addressWord = data.sublist(4, 36);
    for (var i = 0; i < 12; i++) {
      if (addressWord[i] != 0) {
        throw const PayUnsignedTxMismatchException(
          'unsigned tx calldata recipient slot is not zero-padded',
        );
      }
    }
    final recipient = '0x${convert.hex.encode(addressWord.sublist(12, 32))}';

    final amountWord = data.sublist(36, 68);
    final amountWei = BigInt.parse(convert.hex.encode(amountWord), radix: 16);

    return DecodedErc20Transfer(recipient: recipient, amountWei: amountWei);
  }
}

/// A decoded ERC-677 `transferAndCall(address,uint256,bytes)` call.
class DecodedErc677TransferAndCall {
  /// Normalized to `0x` + 40 lowercase hex chars.
  final String recipient;
  final BigInt amountWei;

  /// The `bytes` argument.
  final Uint8List callData;

  const DecodedErc677TransferAndCall({
    required this.recipient,
    required this.amountWei,
    required this.callData,
  });
}

/// Decodes ERC-677 `transferAndCall(address,uint256,bytes)` calldata in the
/// standard ABI layout: data offset 96, length word, then the zero-padded
/// bytes. Anything else is rejected.
abstract final class Erc677TransferAndCallCalldataDecoder {
  static const _selector = [0x40, 0x00, 0xae, 0xa0]; // transferAndCall(address,uint256,bytes)
  static const _headLength =
      132; // 4 (selector) + 32 (address) + 32 (amount) + 32 (offset) + 32 (length)
  static const _dataOffset = 96;

  static DecodedErc677TransferAndCall decode(Uint8List data) {
    if (data.length < _headLength) {
      throw PayUnsignedTxMismatchException(
        'unsigned tx calldata is ${data.length} bytes, expected at least $_headLength '
        '(ERC-677 transferAndCall)',
      );
    }
    for (var i = 0; i < _selector.length; i++) {
      if (data[i] != _selector[i]) {
        throw const PayUnsignedTxMismatchException(
          'unsigned tx calldata is not an ERC-677 transferAndCall(address,uint256,bytes) call',
        );
      }
    }

    final recipient = _address(data.sublist(4, 36));
    final amountWei = _uint(data.sublist(36, 68));
    if (_uint(data.sublist(68, 100)) != BigInt.from(_dataOffset)) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx calldata bytes offset is not $_dataOffset',
      );
    }
    final length = _uint(data.sublist(100, _headLength));
    final available = data.length - _headLength;
    if (length > BigInt.from(available)) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx calldata bytes length exceeds the calldata',
      );
    }
    final callLength = length.toInt();
    final paddedLength = (callLength + 31) ~/ 32 * 32;
    if (available != paddedLength) {
      throw const PayUnsignedTxMismatchException(
        'unsigned tx calldata has bytes after the padded bytes argument',
      );
    }
    for (var i = _headLength + callLength; i < data.length; i++) {
      if (data[i] != 0) {
        throw const PayUnsignedTxMismatchException(
          'unsigned tx calldata bytes argument is not zero-padded',
        );
      }
    }

    return DecodedErc677TransferAndCall(
      recipient: recipient,
      amountWei: amountWei,
      callData: data.sublist(_headLength, _headLength + callLength),
    );
  }

  static String _address(Uint8List word) {
    for (var i = 0; i < 12; i++) {
      if (word[i] != 0) {
        throw const PayUnsignedTxMismatchException(
          'unsigned tx calldata recipient slot is not zero-padded',
        );
      }
    }
    return '0x${convert.hex.encode(word.sublist(12, 32))}';
  }

  static BigInt _uint(Uint8List word) => BigInt.parse(convert.hex.encode(word), radix: 16);
}
