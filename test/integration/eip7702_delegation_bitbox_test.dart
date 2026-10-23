// Cross-layer integration tests for the EIP-7702 delegation sign flow.
//
// The BitBox-gated EIP-712 delegation sign is invoked from
// `RealUnitSellPaymentInfoService.confirmPayment` on every BitBox sell, but
// the typed-data sign itself happens in [Eip712Signer.signDelegation]. This
// file stitches:
//
//   Eip712Signer.signDelegation
//     → FakeBitboxCredentials.signTypedDataV4 (BitBox boundary)
//     → empty-sig / disconnect guards
//
// and pins the chainId-wiring + signature-routing contract: the chainId
// passed to the BitBox sign call MUST come from the EIP-7702 domain (NOT
// from a hard-coded constant, NOT from the asset config), so a multi-chain
// rollout that changes the domain chainId does not silently sign on the
// wrong chain.
//
// We exercise BOTH credential types (FakeBitboxCredentials + EthPrivateKey)
// to lock in the polymorphic switch inside `Eip712Signer._signTypedData` —
// a regression that broke the EthPrivateKey arm shipped in PR #318.

import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/bitbox_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/wallet/eip712_signer.dart';
import 'package:realunit_wallet/packages/wallet/exceptions/signing_cancelled_exception.dart';
import 'package:web3dart/web3dart.dart';

import '../helper/fake_bitbox_credentials.dart';

/// FakeBitboxCredentials extension that records every `(chainId, jsonData)`
/// the production EIP-712 signer hands to the BitBox boundary. Lets a test
/// assert chainId wiring without mocking the production code it is testing.
class _RecordingFakeBitbox extends FakeBitboxCredentials {
  _RecordingFakeBitbox({super.behavior}) : super(signDelay: Duration.zero);

  final List<int> chainIds = [];
  final List<String> jsonPayloads = [];

  @override
  Future<String> signTypedDataV4(int chainId, String jsonData) {
    chainIds.add(chainId);
    jsonPayloads.add(jsonData);
    return super.signTypedDataV4(chainId, jsonData);
  }
}

// MetaMask Delegation Framework v1.3.0, CREATE2 — identical on all EVM chains.
// These are the only delegator/manager addresses the production service
// accepts. `Eip712Signer.signDelegation` signs the canonical schema itself,
// so this fixture matches the hash the chain verifies.
const _metaMaskDelegator = '0x63c0c19a282a1b52b07dd5a65b58948a07dae32b';
const _delegationManager = '0xdb9b1e94b5b69df7e401ddbede43491141047db3';

/// Builds an [Eip7702Data] with the requested [chainId]. The default value
/// (1) covers the mainnet path; explicit values (e.g. 11155111 for Sepolia,
/// 42161 for Arbitrum) cover the chainId-wiring case below.
Eip7702Data _data({int chainId = 1}) => Eip7702Data.fromJson({
  'relayerAddress': '0x0000000000000000000000000000000000000011',
  'delegationManagerAddress': _delegationManager,
  'delegatorAddress': _metaMaskDelegator,
  'userNonce': 7,
  'domain': {
    'name': 'RealUnit',
    'version': '1',
    'chainId': chainId,
    'verifyingContract': _delegationManager,
  },
  'types': {
    'Delegation': <Map<String, dynamic>>[
      {'name': 'delegate', 'type': 'address'},
      {'name': 'delegator', 'type': 'address'},
      {'name': 'authority', 'type': 'bytes32'},
      {'name': 'caveats', 'type': 'Caveat[]'},
      {'name': 'salt', 'type': 'uint256'},
    ],
    'Caveat': <Map<String, dynamic>>[
      {'name': 'enforcer', 'type': 'address'},
      {'name': 'terms', 'type': 'bytes'},
    ],
  },
  'message': {
    'delegate': '0x0000000000000000000000000000000000000014',
    'delegator': '0x0000000000000000000000000000000000000015',
    'authority': '0x0000000000000000000000000000000000000000000000000000000000000016',
    'caveats': <Map<String, dynamic>>[],
    'salt': 0,
  },
  'tokenAddress': '0x0000000000000000000000000000000000000017',
  'amountWei': '100',
  'depositAddress': '0x0000000000000000000000000000000000000018',
});

void main() {
  group('Eip712Signer.signDelegation × FakeBitboxCredentials', () {
    test(
      'happy: FakeBitbox success + EthPrivateKey fallback → both produce a 65-byte EIP-712 sig',
      () async {
        // BitBox arm — FakeBitboxCredentials.signTypedDataV4 returns an
        // EIP-712-V4 signature derived from the deterministic test private
        // key. The signDelegation helper must NOT mangle the chainId / json
        // it forwards (e.g. by re-serialising with mixed key orders), and
        // must NOT trip the empty-sig guard on a real 65-byte payload.
        final bitbox = _RecordingFakeBitbox();
        final bitboxSig = await Eip712Signer.signDelegation(
          credentials: bitbox,
          eip7702Data: _data(),
        );

        expect(bitboxSig, startsWith('0x'));
        // 65 bytes = 0x + 130 hex chars. A regression that returned a 64-byte
        // sig (missing v) or a 0x-only payload (empty-sig guard misfire)
        // would surface here.
        expect(bitboxSig.length, 132);
        expect(bitbox.signCallCount, 1);

        // EthPrivateKey fallback arm — same call, different credential type.
        // The switch inside `Eip712Signer._signTypedData` must route this to
        // EthSigUtil.signTypedData and NOT throw UnsupportedError. (A bug in
        // PR #318 made every non-BitBox credential throw — caught by this
        // arm specifically.) Use a fixed second key whose value differs from
        // the FakeBitboxCredentials test key — comparing the two sigs pins
        // that the EthPrivateKey arm actually went through its OWN key, not
        // a leaked default from the BitBox arm.
        final pk = EthPrivateKey.fromHex(_secondTestPrivateKeyHex);
        final pkSig = await Eip712Signer.signDelegation(
          credentials: pk,
          eip7702Data: _data(),
        );
        expect(pkSig, startsWith('0x'));
        expect(pkSig.length, 132);

        // The two sigs MUST differ — they were produced by different keys
        // over the same payload. An accidental wiring that always signed
        // with the test key (e.g. a leaked default) would surface as
        // equality here.
        expect(pkSig, isNot(equals(bitboxSig)));
      },
    );

    test(
      'cancel: FakeBitbox.cancel → "0x" → SigningCancelledException propagates',
      () async {
        // The BitBox swift wrapper returns `'0x'` when the user cancels on
        // the device. `_signTypedData`'s post-sign guard must convert that
        // into a typed `SigningCancelledException` — otherwise the empty sig
        // is sent on the wire and the cancel is misread as a success.
        final bitbox = _RecordingFakeBitbox(behavior: FakeBitboxBehavior.cancel);

        await expectLater(
          Eip712Signer.signDelegation(credentials: bitbox, eip7702Data: _data()),
          throwsA(isA<SigningCancelledException>()),
        );
        expect(bitbox.signCallCount, 1);
      },
    );

    test(
      'chainId-wiring: signDelegation forwards eip7702Data.domain.chainId to the BitBox sign call',
      () async {
        // The chainId argument to BitboxCredentials.signTypedDataV4 must be
        // the chainId from the EIP-7702 domain, NOT a constant (`1`), NOT
        // the app's asset chainId (which can differ on a multi-chain
        // rollout), NOT `0`. A wrong chainId here makes the BitBox display
        // the wrong network to the user — silent until the user spots it.
        for (final chainId in const [1, 11155111, 42161]) {
          final bitbox = _RecordingFakeBitbox();
          await Eip712Signer.signDelegation(
            credentials: bitbox,
            eip7702Data: _data(chainId: chainId),
          );
          expect(
            bitbox.chainIds.single,
            chainId,
            reason: 'signDelegation must forward domain.chainId=$chainId unchanged',
          );
          // The chainId must also appear inside the json payload's domain —
          // the BitBox firmware re-derives the digest from the json, so if
          // the json's chainId disagrees with the integer arg the signature
          // would be over a different digest than the wallet expects.
          expect(bitbox.jsonPayloads.single, contains('"chainId":$chainId'));
        }
      },
    );

    test(
      'disconnect: FakeBitbox.disconnect throws BitboxNotConnectedException at the BitBox boundary',
      () async {
        // `BitboxCredentials.signTypedDataV4` throws BitboxNotConnectedException
        // when the BLE link is dropped (the real class checks bitboxManager
        // == null up front, the fake mirrors that). The exception must NOT
        // be swallowed inside Eip712Signer — the caller
        // (RealUnitSellPaymentInfoService.confirmPayment) relies on the
        // typed exception to drive the re-pair UI.
        final bitbox = _RecordingFakeBitbox(behavior: FakeBitboxBehavior.disconnect);

        await expectLater(
          Eip712Signer.signDelegation(credentials: bitbox, eip7702Data: _data()),
          throwsA(isA<BitboxNotConnectedException>()),
        );
        // It must NOT have been re-wrapped as SigningCancelledException.
        await expectLater(
          Eip712Signer.signDelegation(credentials: bitbox, eip7702Data: _data()),
          throwsA(isNot(isA<SigningCancelledException>())),
        );
      },
    );
  });
}

/// Second deterministic test private key — distinct from the one inside
/// [FakeBitboxCredentials] so a sig produced with this key cannot collide
/// with one produced by the BitBox arm. Do NOT reuse outside tests.
const _secondTestPrivateKeyHex = 'aa1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';
