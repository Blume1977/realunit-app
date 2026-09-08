import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:realunit_wallet/setup/routing/referral_pending_code.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugSetPendingReferralCodeSync(null);
    debugPendingReferralBeforePrefs = null;
  });

  test('stash then peek then take: take clears, peek does not', () async {
    await stashPendingReferralCode('  AB12CD  ');
    expect(await peekPendingReferralCode(), 'AB12CD');
    expect(peekPendingReferralCodeSync(), 'AB12CD');
    expect(pendingReferralCodeIsCurrent('AB12CD'), isTrue);
    expect(pendingReferralCodeIsCurrent('NEWER1'), isFalse);

    expect(await takePendingReferralCode(), 'AB12CD');
    expect(await peekPendingReferralCode(), isNull);
    expect(await takePendingReferralCode(), isNull);
  });

  test('ignores empty stash and caps at 32 characters', () async {
    await stashPendingReferralCode('   ');
    expect(await peekPendingReferralCode(), isNull);

    final long = 'x' * 300;
    await stashPendingReferralCode(long);
    expect((await peekPendingReferralCode())!.length, 32);
  });

  test('percent-decodes a stashed code', () async {
    await stashPendingReferralCode('AB%2F12');
    expect(await peekPendingReferralCode(), 'AB/12');
  });

  test('extracts the code from a stashed invite URL', () async {
    await stashPendingReferralCode('https://realunit.app/invite/AB12CD');
    expect(await peekPendingReferralCode(), 'AB12CD');
    expect(await takePendingReferralCode(), 'AB12CD');
  });

  test('peek extracts a pre-normalize prefs invite URL', () async {
    debugSetPendingReferralCodeSync(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      pendingReferralCodeKey,
      'android-app://swiss.realunit.app/https/realunit.app/promo/EVT1',
    );
    expect(await peekPendingReferralCode(), 'EVT1');
  });

  test('peek and take decode a pre-normalize prefs value', () async {
    debugSetPendingReferralCodeSync(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingReferralCodeKey, 'AB%2F12');
    expect(await peekPendingReferralCode(), 'AB/12');
    expect(await takePendingReferralCode(), 'AB/12');
    expect(await peekPendingReferralCode(), isNull);
  });

  test('clear drops both memory and prefs', () async {
    await stashPendingReferralCode('EVT1');
    await clearPendingReferralCode();
    expect(await peekPendingReferralCode(), isNull);
    expect(peekPendingReferralCodeSync(), isNull);
  });

  test('discardPendingReferralCodeIfEqual drops only a matching stash', () async {
    await stashPendingReferralCode('AB12CD');
    await discardPendingReferralCodeIfEqual('AB12CD');
    expect(await peekPendingReferralCode(), isNull);
  });

  test('discardPendingReferralCodeIfEqual leaves a newer distinct stash', () async {
    await stashPendingReferralCode('AB12CD');
    await stashPendingReferralCode('NEWER1');
    await discardPendingReferralCodeIfEqual('AB12CD');
    expect(await peekPendingReferralCode(), 'NEWER1');
  });

  test('after concurrent take and discard the code is not still claimable', () async {
    await stashPendingReferralCode('AB12CD');
    final gate = Completer<void>();
    debugPendingReferralBeforePrefs = () => gate.future;
    addTearDown(() => debugPendingReferralBeforePrefs = null);

    final discarded = discardPendingReferralCodeIfEqual('AB12CD');
    await Future<void>.delayed(Duration.zero);
    final taken = takePendingReferralCode();
    gate.complete();
    await discarded;
    await taken;

    expect(await peekPendingReferralCode(), isNull);
    expect(await takePendingReferralCode(), isNull);
  });

  test('concurrent take and discard do not throw', () async {
    await stashPendingReferralCode('AB12CD');
    await Future.wait<void>([
      takePendingReferralCode().then<void>((_) {}),
      discardPendingReferralCodeIfEqual('AB12CD'),
      takePendingReferralCode().then<void>((_) {}),
      discardPendingReferralCodeIfEqual('AB12CD'),
    ]);
    expect(await peekPendingReferralCode(), isNull);
  });

  test('a second take while the first is in flight returns null', () async {
    await stashPendingReferralCode('AB12CD');
    final first = takePendingReferralCode();
    final second = takePendingReferralCode();
    final results = await Future.wait([first, second]);
    expect(results.where((code) => code == 'AB12CD').length, 1);
    expect(results.where((code) => code == null).length, 1);
    expect(await peekPendingReferralCode(), isNull);
  });
}
