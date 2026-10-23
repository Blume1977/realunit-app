import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/delegation_caveat_dto.dart';

/// Which signed delegation the caveat list must match.
enum DelegationCaveatKind { tokenTransfer, brokerbotSell }

/// A timestamp caveat is accepted only when `validUntil` is at most this many
/// seconds after the check instant. Equal is accepted.
const delegationValiditySeconds = 1800;

const _exactExecutionHex = '0x146713078D39eCC1F5338309c28405ccf85Abfbb';
const _allowedTargetsHex = '0x7F20f61b1f09b08D970938F6fa563634d65c4EeB';
const _allowedMethodsHex = '0x2c21fD0Cb9DC8445CB3fb0DC5E7Bb0Aca01842B5';
const _limitedCallsHex = '0x04658B29F6b82ed55274221a06Fc97D318E25416';
const _timestampHex = '0x1046bb45C8d673d4ea75321280DB34899413c069';
const _logicalOrHex = '0xE1302607a3251AF54c3a6e69318d6aa07F5eB46c';

const _mainnetBrokerbotHex = '0xCFF32C60B87296B8c0c12980De685bEd6Cb9dD6d';
const _sepoliaBrokerbotHex = '0x39c33c2fd5b07b8e890fd2115d4adff7235fc9d2';
const _mainnetZchfHex = '0xB58E61C3098d85632Df34EecfB899A1Ed80921cB';
const _sepoliaZchfHex = '0xD3117681cA462268048f57D106d312Ba0b1215eA';

const _erc20TransferSelectorHex = '0xa9059cbb';
const _transferAndCallSelectorHex = '0x4000aea0';

final Uint8List _exactExecution = _pinnedAddress(_exactExecutionHex);
final Uint8List _allowedTargets = _pinnedAddress(_allowedTargetsHex);
final Uint8List _allowedMethods = _pinnedAddress(_allowedMethodsHex);
final Uint8List _limitedCalls = _pinnedAddress(_limitedCallsHex);
final Uint8List _timestampEnforcer = _pinnedAddress(_timestampHex);
final Uint8List _logicalOr = _pinnedAddress(_logicalOrHex);

// Network pins. The delegation payload's deposit address is not the brokerbot.
final Uint8List _mainnetBrokerbot = _pinnedAddress(_mainnetBrokerbotHex);
final Uint8List _sepoliaBrokerbot = _pinnedAddress(_sepoliaBrokerbotHex);
final Uint8List _mainnetZchf = _pinnedAddress(_mainnetZchfHex);
final Uint8List _sepoliaZchf = _pinnedAddress(_sepoliaZchfHex);

final Uint8List _erc20TransferSelector = _pinnedBytes(_erc20TransferSelectorHex);
final Uint8List _transferAndCallSelector = _pinnedBytes(_transferAndCallSelectorHex);

final List<Uint8List> _pinnedEnforcers = [
  _exactExecution,
  _allowedTargets,
  _allowedMethods,
  _limitedCalls,
  _timestampEnforcer,
  _logicalOr,
];

class _Caveat {
  final Uint8List enforcer;
  final Uint8List terms;

  _Caveat(this.enforcer, this.terms);
}

/// Rejects a signed caveat list that is not the exact shape for [kind].
///
/// [now] null uses `DateTime.now().toUtc()`. Comparison is in unix seconds.
/// An empty list is rejected. Hex case does not matter.
void checkDelegationCaveats({
  required List<DelegationCaveatDto> caveats,
  required DelegationCaveatKind kind,
  required String tokenAddress,
  required BigInt amountWei,
  String? recipient,
  required bool testnet,
  DateTime? now,
}) {
  if (amountWei.isNegative || amountWei.bitLength > 256) {
    _reject('amount does not fit in uint256');
  }
  final DateTime instant;
  if (now == null) {
    instant = DateTime.now().toUtc();
  } else {
    instant = now;
  }
  final nowSeconds = instant.toUtc().millisecondsSinceEpoch ~/ 1000;
  final parsed = _parseCaveats(caveats);
  switch (kind) {
    case DelegationCaveatKind.tokenTransfer:
      _checkTokenTransfer(
        parsed: parsed,
        tokenAddress: tokenAddress,
        amountWei: amountWei,
        recipient: recipient,
        nowSeconds: nowSeconds,
      );
    case DelegationCaveatKind.brokerbotSell:
      _checkBrokerbotSell(
        parsed: parsed,
        tokenAddress: tokenAddress,
        amountWei: amountWei,
        testnet: testnet,
        nowSeconds: nowSeconds,
      );
  }
}

Never _reject(String reason) {
  throw Exception('EIP-7702 caveats: $reason');
}

List<_Caveat> _parseCaveats(List<DelegationCaveatDto> caveats) {
  if (caveats.isEmpty) {
    _reject('the caveat list is empty');
  }
  final parsed = <_Caveat>[];
  for (final caveat in caveats) {
    final terms = _decodeHex(caveat.terms);
    if (terms == null) {
      _reject('terms are not 0x hex');
    }
    final enforcer = _decodeHex(caveat.enforcer);
    if (enforcer == null || enforcer.length != 20 || !_isPinnedEnforcer(enforcer)) {
      _reject('enforcer is not one of the six pinned enforcers');
    }
    parsed.add(_Caveat(enforcer, terms));
  }
  return parsed;
}

bool _isPinnedEnforcer(Uint8List enforcer) {
  for (final pinned in _pinnedEnforcers) {
    if (_sameBytes(enforcer, pinned)) {
      return true;
    }
  }
  return false;
}

void _checkTokenTransfer({
  required List<_Caveat> parsed,
  required String tokenAddress,
  required BigInt amountWei,
  required String? recipient,
  required int nowSeconds,
}) {
  if (recipient == null) {
    _reject('token transfer is missing a recipient');
  }
  if (parsed.length != 3) {
    _reject('token transfer requires exactly three caveats');
  }
  if (!_sameBytes(parsed[0].enforcer, _exactExecution) ||
      !_sameBytes(parsed[1].enforcer, _limitedCalls) ||
      !_sameBytes(parsed[2].enforcer, _timestampEnforcer)) {
    _reject('token transfer caveats are not ExactExecution, LimitedCalls, Timestamp');
  }
  final token = _requireAddress(tokenAddress, 'token');
  final to = _requireAddress(recipient, 'recipient');
  final expected = _exactExecutionTerms(
    token: token,
    value: BigInt.zero,
    calldata: _concat([
      _erc20TransferSelector,
      _addressWord(to),
      _word(amountWei),
    ]),
  );
  if (!_sameBytes(parsed[0].terms, expected)) {
    _reject('ExactExecution does not bind the token, recipient and amount');
  }
  if (!_sameBytes(parsed[1].terms, _word(BigInt.one))) {
    _reject('LimitedCalls is not exactly one call');
  }
  _checkTimestamp(parsed[2].terms, nowSeconds);
}

void _checkBrokerbotSell({
  required List<_Caveat> parsed,
  required String tokenAddress,
  required BigInt amountWei,
  required bool testnet,
  required int nowSeconds,
}) {
  if (parsed.length != 2) {
    _reject('brokerbot sell requires exactly two caveats');
  }
  if (!_sameBytes(parsed[0].enforcer, _logicalOr) ||
      !_sameBytes(parsed[1].enforcer, _timestampEnforcer)) {
    _reject('brokerbot sell caveats are not LogicalOrWrapper, Timestamp');
  }
  final token = _requireAddress(tokenAddress, 'token');
  final Uint8List brokerbot;
  final Uint8List zchf;
  if (testnet) {
    brokerbot = _sepoliaBrokerbot;
    zchf = _sepoliaZchf;
  } else {
    brokerbot = _mainnetBrokerbot;
    zchf = _mainnetZchf;
  }
  final execution = _exactExecutionTerms(
    token: token,
    value: BigInt.zero,
    calldata: _concat([
      _transferAndCallSelector,
      _addressWord(brokerbot),
      _word(amountWei),
      _word(BigInt.from(96)),
      _word(BigInt.zero),
    ]),
  );
  final group0 = _group([
    _caveatTuple(_exactExecution, execution),
    _caveatTuple(_limitedCalls, _word(BigInt.one)),
  ]);
  final group1 = _group([
    _caveatTuple(_allowedTargets, zchf),
    _caveatTuple(_allowedMethods, _erc20TransferSelector),
  ]);
  final expected = _concat([_word(BigInt.from(32)), _dynamicArray([group0, group1])]);
  if (!_sameBytes(parsed[0].terms, expected)) {
    _reject('LogicalOr terms do not bind the token, brokerbot and amount');
  }
  _checkTimestamp(parsed[1].terms, nowSeconds);
}

void _checkTimestamp(Uint8List terms, int nowSeconds) {
  if (terms.length != 32) {
    _reject('timestamp terms are not 32 bytes');
  }
  for (var i = 0; i < 16; i++) {
    if (terms[i] != 0) {
      _reject('timestamp validAfter is not zero');
    }
  }
  final validUntil = _unsigned(terms, 16, 16);
  // Zero disables the upper bound in the timestamp enforcer. It is not an expiry.
  if (validUntil == BigInt.zero) {
    _reject('timestamp validUntil is unset');
  }
  final latest = BigInt.from(nowSeconds) + BigInt.from(delegationValiditySeconds);
  if (validUntil > latest) {
    _reject('timestamp validUntil is later than $delegationValiditySeconds seconds from now');
  }
}

Uint8List _exactExecutionTerms({
  required Uint8List token,
  required BigInt value,
  required Uint8List calldata,
}) {
  return _concat([token, _word(value), calldata]);
}

/// `(address enforcer, bytes terms, bytes args)` with empty args.
/// Offsets are from the start of this tuple.
Uint8List _caveatTuple(Uint8List enforcer, Uint8List terms) {
  final encodedTerms = _encBytes(terms);
  final encodedArgs = _encBytes(Uint8List(0));
  return _concat([
    _addressWord(enforcer),
    _word(BigInt.from(96)),
    _word(BigInt.from(96 + encodedTerms.length)),
    encodedTerms,
    encodedArgs,
  ]);
}

/// One-field group `{ caveats: caveat[] }`: offset word, then the array.
Uint8List _group(List<Uint8List> caveatTuples) {
  return _concat([_word(BigInt.from(32)), _dynamicArray(caveatTuples)]);
}

/// Dynamic array. Each offset is relative to the first offset word.
Uint8List _dynamicArray(List<Uint8List> items) {
  final parts = <Uint8List>[_word(BigInt.from(items.length))];
  var cursor = 32 * items.length;
  for (final item in items) {
    parts.add(_word(BigInt.from(cursor)));
    cursor += item.length;
  }
  parts.addAll(items);
  return _concat(parts);
}

Uint8List _encBytes(Uint8List data) {
  return _concat([_word(BigInt.from(data.length)), _pad32(data)]);
}

Uint8List _pad32(Uint8List data) {
  final remainder = data.length % 32;
  if (remainder == 0) {
    return data;
  }
  final out = Uint8List(data.length + (32 - remainder));
  out.setRange(0, data.length, data);
  return out;
}

Uint8List _addressWord(Uint8List address) {
  if (address.length != 20) {
    // Callers pass a checked 20-byte address. This throw has no test path.
    _reject('address is not 20 bytes'); // coverage:ignore-line
  }
  final out = Uint8List(32);
  out.setRange(12, 32, address);
  return out;
}

Uint8List _word(BigInt value) {
  if (value.isNegative || value.bitLength > 256) {
    // The public check rejects a bad amount. Every other word is a small constant.
    _reject('value does not fit in a 32-byte word'); // coverage:ignore-line
  }
  final out = Uint8List(32);
  var remaining = value;
  final mask = BigInt.from(0xff);
  for (var i = 31; i >= 0; i--) {
    out[i] = (remaining & mask).toInt();
    remaining >>= 8;
  }
  return out;
}

BigInt _unsigned(Uint8List bytes, int offset, int length) {
  var value = BigInt.zero;
  for (var i = 0; i < length; i++) {
    value = (value << 8) | BigInt.from(bytes[offset + i]);
  }
  return value;
}

Uint8List _requireAddress(String value, String label) {
  final bytes = _decodeHex(value);
  if (bytes == null || bytes.length != 20) {
    _reject('$label is not a 20-byte 0x address');
  }
  return bytes;
}

Uint8List _pinnedAddress(String hex) {
  final bytes = _decodeHex(hex);
  if (bytes == null || bytes.length != 20) {
    // Pin constants are valid addresses. A bad constant fails while the library loads.
    throw StateError('pinned address is not 20 bytes'); // coverage:ignore-line
  }
  return bytes;
}

Uint8List _pinnedBytes(String hex) {
  final bytes = _decodeHex(hex);
  if (bytes == null || bytes.isEmpty) {
    // Pin constants are non-empty hex. A bad constant fails while the library loads.
    throw StateError('pinned hex is empty'); // coverage:ignore-line
  }
  return bytes;
}

Uint8List? _decodeHex(String value) {
  final lower = value.toLowerCase();
  if (!lower.startsWith('0x')) {
    return null;
  }
  final body = lower.substring(2);
  if (body.length.isOdd) {
    return null;
  }
  for (var i = 0; i < body.length; i++) {
    final unit = body.codeUnitAt(i);
    final digit = unit >= 0x30 && unit <= 0x39;
    final letter = unit >= 0x61 && unit <= 0x66;
    if (!digit && !letter) {
      return null;
    }
  }
  if (body.isEmpty) {
    return Uint8List(0);
  }
  return Uint8List.fromList(convert.hex.decode(body));
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

Uint8List _concat(List<Uint8List> parts) {
  var length = 0;
  for (final part in parts) {
    length += part.length;
  }
  final out = Uint8List(length);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}
