import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/delegation_caveat_check.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/delegation_caveat_dto.dart';

const _token = '0x553C7f9C780316FC1D34b8e14ac2465Ab22a090B';
const _recipient100 = '0x9f5713deacb8e9cab6c2d3fae1afc2715f8d2d71';
const _recipient5 = '0x2222222222222222222222222222222222222222';

const _exactExecution = '0x146713078D39eCC1F5338309c28405ccf85Abfbb';
const _limitedCalls = '0x04658B29F6b82ed55274221a06Fc97D318E25416';
const _timestampEnforcer = '0x1046bb45C8d673d4ea75321280DB34899413c069';
const _logicalOr = '0xE1302607a3251AF54c3a6e69318d6aa07F5eB46c';

final Map<String, dynamic> _vectors = _loadVectors();

final DateTime _boundary = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true);

Map<String, dynamic> _loadVectors() {
  final decoded = jsonDecode(
    File('test/packages/service/dfx/delegation_caveat_vectors.json').readAsStringSync(),
  );
  if (decoded is! Map<String, dynamic>) {
    throw StateError('caveat vectors are not a JSON object');
  }
  return decoded;
}

String _vector(String key) {
  final value = _vectors[key];
  if (value is! String) {
    throw StateError('caveat vector $key is missing');
  }
  return value;
}

List<dynamic> _transferCaveats(String termsKey) => <dynamic>[
  <String, dynamic>{'enforcer': _exactExecution, 'terms': _vector(termsKey)},
  <String, dynamic>{'enforcer': _limitedCalls, 'terms': _vector('limited')},
  <String, dynamic>{'enforcer': _timestampEnforcer, 'terms': _vector('timestamp')},
];

List<dynamic> _sellCaveats(String wrapperKey) => <dynamic>[
  <String, dynamic>{'enforcer': _logicalOr, 'terms': _vector(wrapperKey)},
  <String, dynamic>{'enforcer': _timestampEnforcer, 'terms': _vector('timestamp')},
];

String _mutateHex(String terms, String from, String to) {
  final lower = terms.toLowerCase();
  final needle = from.toLowerCase();
  final index = lower.indexOf(needle);
  if (index < 0) {
    throw StateError('pattern not found');
  }
  if (lower.indexOf(needle, index + needle.length) >= 0) {
    throw StateError('pattern is not unique');
  }
  return terms.replaceRange(index, index + needle.length, to);
}

List<dynamic> _withTerms(List<dynamic> caveats, int index, String terms) {
  final copy = <dynamic>[];
  for (var i = 0; i < caveats.length; i++) {
    final source = caveats[i];
    if (source is! Map) {
      throw StateError('caveat is not a map');
    }
    final next = Map<String, dynamic>.from(source);
    if (i == index) {
      next['terms'] = terms;
    }
    copy.add(next);
  }
  return copy;
}

List<dynamic> _withEnforcer(List<dynamic> caveats, int index, String enforcer) {
  final copy = <dynamic>[];
  for (var i = 0; i < caveats.length; i++) {
    final source = caveats[i];
    if (source is! Map) {
      throw StateError('caveat is not a map');
    }
    final next = Map<String, dynamic>.from(source);
    if (i == index) {
      next['enforcer'] = enforcer;
    }
    copy.add(next);
  }
  return copy;
}

void _check({
  required List<dynamic> caveats,
  required DelegationCaveatKind kind,
  required String tokenAddress,
  required BigInt amountWei,
  String? recipient,
  required bool testnet,
  DateTime? now,
}) {
  checkDelegationCaveats(
    caveats: DelegationCaveatDto.listFrom(caveats),
    kind: kind,
    tokenAddress: tokenAddress,
    amountWei: amountWei,
    recipient: recipient,
    testnet: testnet,
    now: now,
  );
}

void _expectRejected({
  required List<dynamic> caveats,
  required DelegationCaveatKind kind,
  required BigInt amountWei,
  String tokenAddress = _token,
  String? recipient,
  required bool testnet,
  DateTime? now,
}) {
  expect(
    () => _check(
      caveats: caveats,
      kind: kind,
      tokenAddress: tokenAddress,
      amountWei: amountWei,
      recipient: recipient,
      testnet: testnet,
      now: now,
    ),
    throwsA(
      isA<Exception>().having(
        (Exception error) => error.toString(),
        'message',
        startsWith('Exception: EIP-7702 caveats'),
      ),
    ),
  );
}

void main() {
  test('accepts the amount-100 transfer at the 1800 second boundary', () {
    _check(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      tokenAddress: _token,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('accepts the amount-5 transfer vector', () {
    _check(
      caveats: _transferCaveats('transferAmount5Recipient2222'),
      kind: DelegationCaveatKind.tokenTransfer,
      tokenAddress: _token,
      amountWei: BigInt.from(5),
      recipient: _recipient5,
      testnet: false,
      now: _boundary,
    );
  });

  test('accepts the amount-100 sell wrapper at the 1800 second boundary', () {
    _check(
      caveats: _sellCaveats('sellWrapperAmount100'),
      kind: DelegationCaveatKind.brokerbotSell,
      tokenAddress: _token,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('accepts the amount-2 sell wrapper', () {
    _check(
      caveats: _sellCaveats('sellWrapperAmount2'),
      kind: DelegationCaveatKind.brokerbotSell,
      tokenAddress: _token,
      amountWei: BigInt.from(2),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects an empty caveat list', () {
    _expectRejected(
      caveats: <dynamic>[],
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a non-map caveat', () {
    _expectRejected(
      caveats: <dynamic>['not-a-map'],
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a caveat field that is not a string', () {
    _expectRejected(
      caveats: <dynamic>[
        <String, dynamic>{'enforcer': 1, 'terms': '0x'},
      ],
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects terms that are not 0x hex', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        '0xzz',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects an enforcer outside the six', () {
    _expectRejected(
      caveats: _withEnforcer(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        '0x1111111111111111111111111111111111111111',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects transfer caveats checked as a brokerbot sell', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects sell caveats checked as a token transfer', () {
    _expectRejected(
      caveats: _sellCaveats('sellWrapperAmount100'),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a fourth caveat', () {
    final caveats = _transferCaveats('transferAmount100Recipient9f57');
    caveats.add(<String, dynamic>{
      'enforcer': _timestampEnforcer,
      'terms': _vector('timestamp'),
    });
    _expectRejected(
      caveats: caveats,
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a transfer that is missing LimitedCalls', () {
    final caveats = _transferCaveats('transferAmount100Recipient9f57')..removeAt(1);
    _expectRejected(
      caveats: caveats,
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects an amount off by one', () {
    final terms = _vector('transferAmount100Recipient9f57');
    if (!terms.endsWith('64')) {
      throw StateError('amount-100 vector does not end in 0x64');
    }
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        '${terms.substring(0, terms.length - 2)}65',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a recipient whose last byte is flipped', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        _mutateHex(_vector('transferAmount100Recipient9f57'), '5f8d2d71', '5f8d2d70'),
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a flipped token byte', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        _mutateHex(_vector('transferAmount100Recipient9f57'), '553c7f9c', '543c7f9c'),
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a non-zero execution value', () {
    final from = 'b22a090b${'0' * 64}a9059cbb';
    final to = 'b22a090b${'0' * 62}01a9059cbb';
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        _mutateHex(_vector('transferAmount100Recipient9f57'), from, to),
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a flipped brokerbot byte', () {
    _expectRejected(
      caveats: _withTerms(
        _sellCaveats('sellWrapperAmount100'),
        0,
        _mutateHex(
          _vector('sellWrapperAmount100'),
          'cff32c60b87296b8c0c12980de685bed6cb9dd6d',
          'cff32c60b87296b8c0c12980de685bed6cb9dd6c',
        ),
      ),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a flipped ZCHF byte', () {
    _expectRejected(
      caveats: _withTerms(
        _sellCaveats('sellWrapperAmount100'),
        0,
        _mutateHex(
          _vector('sellWrapperAmount100'),
          'b58e61c3098d85632df34eecfb899a1ed80921cb',
          'b58e61c3098d85632df34eecfb899a1ed80921ca',
        ),
      ),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects an AllowedMethods selector that is not transfer', () {
    _expectRejected(
      caveats: _withTerms(
        _sellCaveats('sellWrapperAmount100'),
        0,
        _mutateHex(_vector('sellWrapperAmount100'), 'a9059cbb', '095ea7b3'),
      ),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects non-empty transferAndCall bytes', () {
    final brokerbot = 'cff32c60b87296b8c0c12980de685bed6cb9dd6d';
    final amount = '${'0' * 62}64';
    final word96 = '${'0' * 62}60';
    final word0 = '0' * 64;
    final word1 = '${'0' * 63}1';
    _expectRejected(
      caveats: _withTerms(
        _sellCaveats('sellWrapperAmount100'),
        0,
        _mutateHex(
          _vector('sellWrapperAmount100'),
          '$brokerbot$amount$word96$word0',
          '$brokerbot$amount$word96$word1',
        ),
      ),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects the mainnet sell wrapper on testnet', () {
    _expectRejected(
      caveats: _sellCaveats('sellWrapperAmount100'),
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: true,
      now: _boundary,
    );
  });

  test('rejects a timestamp with no upper bound', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        2,
        '0x${'0' * 64}',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a timestamp 1801 seconds ahead', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: DateTime.fromMillisecondsSinceEpoch(1699999999 * 1000, isUtc: true),
    );
  });

  test('rejects a negative amount', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(-1),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects an amount wider than 256 bits', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.one << 256,
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a transfer without a recipient', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects transfer caveats in the wrong order', () {
    _expectRejected(
      caveats: _withEnforcer(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        _timestampEnforcer,
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects LimitedCalls that is not one', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        1,
        '0x${'0' * 62}02',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects two sell caveats that are not the wrapper and a timestamp', () {
    final caveats = _transferCaveats('transferAmount100Recipient9f57')..removeLast();
    _expectRejected(
      caveats: caveats,
      kind: DelegationCaveatKind.brokerbotSell,
      amountWei: BigInt.from(100),
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects timestamp terms that are not 32 bytes', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        2,
        '0x01',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a timestamp whose validAfter is not zero', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        2,
        '0x01${'0' * 62}',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('rejects a token address that is not 20 bytes', () {
    _expectRejected(
      caveats: _transferCaveats('transferAmount100Recipient9f57'),
      kind: DelegationCaveatKind.tokenTransfer,
      tokenAddress: '0x1234',
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });

  test('reads the clock when no instant is passed', () {
    _expectRejected(
      caveats: <dynamic>[],
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: null,
    );
  });

  test('rejects empty hex terms', () {
    _expectRejected(
      caveats: _withTerms(
        _transferCaveats('transferAmount100Recipient9f57'),
        0,
        '0x',
      ),
      kind: DelegationCaveatKind.tokenTransfer,
      amountWei: BigInt.from(100),
      recipient: _recipient100,
      testnet: false,
      now: _boundary,
    );
  });
}
