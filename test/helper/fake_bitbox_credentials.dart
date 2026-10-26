import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:eth_sig_util_plus/eth_sig_util_plus.dart';
import 'package:realunit_wallet/packages/hardware_wallet/bitbox_credentials.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/bitbox_exception.dart';
import 'package:realunit_wallet/packages/wallet/exceptions/signing_cancelled_exception.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Behaviour modes for [FakeBitboxCredentials]. Each mode mirrors a real-world
/// outcome of the hardware-wallet sign ceremony that the app must handle.
enum FakeBitboxBehavior {
  /// The user confirms on the device — sign returns a real signature derived
  /// from a deterministic test private key.
  success,

  /// The user cancels on the device — the iOS BitBox bridge returns `'0x'`.
  cancel,

  /// BLE link drops before/during the ceremony — the credentials report
  /// `isConnected == false` and the sign throws `BitboxNotConnectedException`,
  /// mirroring what the real `BitboxCredentials` does when `bitboxManager` is
  /// null.
  disconnect,

  /// The device hangs and never responds — the sign awaits forever (caller
  /// must impose its own outer timeout).
  timeout,

  /// The device returns an unparsable byte stream (frame desync regression
  /// like bitbox_flutter PR #11). The fake returns a non-hex string.
  malformed,
}

/// Deterministic test private key used to derive a stable address and produce
/// real EIP-712 signatures in [FakeBitboxBehavior.success] mode. The
/// derived address is `0x9F5713dEAcb8e9CaB6c2D3FaE1aFc2715F8D2D71`. Do NOT
/// reuse this seed outside of tests.
const String _testPrivateKeyHex =
    'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';

/// In-test stand-in for a real BitBox-backed [BitboxCredentials]. Replaces
/// the BLE/USB-driven `BitboxManager` calls with a controllable outcome.
///
/// `is BitboxCredentials` continues to hold so all production code paths that
/// special-case the hardware wallet (e.g. the BitboxNotConnectedException
/// guard in `RealUnitRegistrationService`) treat instances of this class
/// identically to a real one.
class FakeBitboxCredentials extends BitboxCredentials {
  FakeBitboxCredentials({
    String? address,
    this.behavior = FakeBitboxBehavior.success,
    this.signDelay = const Duration(milliseconds: 50),
  }) : super(address ?? EthPrivateKey.fromHex(_testPrivateKeyHex).address.hexEip55);

  /// Outcome the next sign call will produce. Mutable so a single instance
  /// can simulate a reconnect (e.g. switch from `disconnect` to `success`
  /// without rebuilding the wallet).
  FakeBitboxBehavior behavior;

  /// Simulated time the user spends confirming on the device. Set to zero in
  /// tight unit tests, leave at the default for flows that need to observe
  /// the in-flight loading state.
  Duration signDelay;

  /// Number of successful or attempted signs since construction. Useful for
  /// asserting that a cancelled sign was retried exactly once.
  int signCallCount = 0;

  /// Raw payloads handed to [signToSignature], in call order. Lets a test
  /// assert exactly which transaction bytes reached the device.
  final List<Uint8List> signedPayloads = [];

  @override
  bool get isConnected => behavior != FakeBitboxBehavior.disconnect;

  @override
  Future<String> signTypedDataV4(int chainId, String jsonData) async {
    signCallCount++;
    await Future<void>.delayed(signDelay);
    switch (behavior) {
      case FakeBitboxBehavior.success:
        return EthSigUtil.signTypedData(
          privateKey: _testPrivateKeyHex,
          jsonData: jsonData,
          version: TypedDataVersion.V4,
        );
      case FakeBitboxBehavior.cancel:
        return '0x';
      case FakeBitboxBehavior.disconnect:
        throw const BitboxNotConnectedException();
      case FakeBitboxBehavior.timeout:
        await Completer<void>().future;
        return '';
      case FakeBitboxBehavior.malformed:
        return '0xnot_hex_data';
    }
  }

  @override
  Future<Uint8List> signPersonalMessage(Uint8List payload, {int? chainId}) async {
    signCallCount++;
    await Future<void>.delayed(signDelay);
    switch (behavior) {
      case FakeBitboxBehavior.success:
        final pk = EthPrivateKey.fromHex(_testPrivateKeyHex);
        return pk.signPersonalMessageToUint8List(payload);
      case FakeBitboxBehavior.cancel:
        return Uint8List(0);
      case FakeBitboxBehavior.disconnect:
        throw const BitboxNotConnectedException();
      case FakeBitboxBehavior.timeout:
        await Completer<void>().future;
        return Uint8List(0);
      case FakeBitboxBehavior.malformed:
        return Uint8List.fromList(utf8.encode('not a sig'));
    }
  }

  @override
  Future<MsgSignature> signToSignature(
    Uint8List payload, {
    int? chainId,
    bool isEIP1559 = false,
  }) async {
    signCallCount++;
    signedPayloads.add(Uint8List.fromList(payload));
    await Future<void>.delayed(signDelay);
    switch (behavior) {
      case FakeBitboxBehavior.success:
        final pk = EthPrivateKey.fromHex(_testPrivateKeyHex);
        return pk.signToSignature(payload, chainId: chainId, isEIP1559: isEIP1559);
      case FakeBitboxBehavior.cancel:
        throw const SigningCancelledException();
      case FakeBitboxBehavior.disconnect:
        throw const BitboxNotConnectedException();
      case FakeBitboxBehavior.timeout:
        await Completer<void>().future;
        return MsgSignature(BigInt.zero, BigInt.zero, 0);
      case FakeBitboxBehavior.malformed:
        throw const FormatException('Malformed signature from device');
    }
  }
}
