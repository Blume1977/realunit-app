import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/kyc/steps/registration/stash_resolved_referral_code.dart';
import 'package:realunit_wallet/setup/routing/referral_pending_code.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugSetPendingReferralCodeSync(null);
    debugStashResolvedReferralCode = null;
    debugTypedReferralAfterPeek = null;
  });

  tearDown(() {
    debugStashResolvedReferralCode = null;
    debugTypedReferralAfterPeek = null;
  });

  test('null resolved leaves a deeplink stash in place', () async {
    await stashPendingReferralCode('AB12CD');
    await stashResolvedReferralCode(null);
    expect(await peekPendingReferralCode(), 'AB12CD');
  });

  test('a resolved code overwrites the stash for post-auth bind', () async {
    await stashPendingReferralCode('OLD1');
    await stashResolvedReferralCode('EVT1');
    expect(await peekPendingReferralCode(), 'EVT1');
  });

  test('Skip discards the typed code and does not bind it later', () async {
    final stash = TypedReferralStash();
    await stash.onResolved('AB12CD');
    expect(await peekPendingReferralCode(), 'AB12CD');

    await stash.onResolved(null);
    expect(stash.resolved, isNull);
    expect(await peekPendingReferralCode(), isNull);
  });

  test('Skip leaves a distinct deeplink when nothing was typed', () async {
    await stashPendingReferralCode('EVT1');
    final stash = TypedReferralStash();
    await stash.onResolved(null);
    expect(await peekPendingReferralCode(), 'EVT1');
  });

  test('persistIfStillCurrent does not overwrite a newer deeplink', () async {
    final stash = TypedReferralStash();
    await stash.onResolved('AB12CD');
    await stashPendingReferralCode('NEWER1');
    await stash.persistIfStillCurrent();
    expect(await peekPendingReferralCode(), 'NEWER1');
  });

  test('persistIfStillCurrent does not overwrite a deeplink that lands after peek', () async {
    final stash = TypedReferralStash();
    await stash.onResolved('AB12CD');
    debugTypedReferralAfterPeek = () => stashPendingReferralCode('NEWER1');
    await stash.persistIfStillCurrent();
    expect(await peekPendingReferralCode(), 'NEWER1');
  });

  test('persistIfStillCurrent writes the typed code when stash is empty', () async {
    final stash = TypedReferralStash();
    stash.resolved = 'AB12CD';
    await stash.persistIfStillCurrent();
    expect(await peekPendingReferralCode(), 'AB12CD');
  });
}
