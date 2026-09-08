import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:realunit_wallet/setup/routing/referral_pending_code.dart';

/// Persist a looked-up invite/promo code for post-auth bind.
///
/// Called before KYC submit (crash after backend accept) and again on
/// success. Null means skip or invalid lookup: leave any deeplink stash in
/// place so automatic takeover still binds. Only a resolved code is written.
/// Last-write-wins: a newer distinct stash must be guarded by
/// [TypedReferralStash.persistIfStillCurrent], not by this function.
Future<void> stashResolvedReferralCode(String? resolved) async {
  final override = debugStashResolvedReferralCode;
  if (override != null) {
    await override(resolved);
    return;
  }
  if (resolved == null) return;
  await stashPendingReferralCode(resolved);
}

@visibleForTesting
Future<void> Function(String? resolved)? debugStashResolvedReferralCode;

/// Test-only: run after the first peek in [TypedReferralStash.persistIfStillCurrent]
/// so a deeplink can land before the synchronous recheck.
@visibleForTesting
Future<void> Function()? debugTypedReferralAfterPeek;

/// Typed registration-field code. Skip/invalid discard this code without
/// touching a newer distinct deeplink. [awaitIdle] must run before submit
/// so a crash after backend accept still has the code in prefs.
class TypedReferralStash {
  String? resolved;
  Future<void> _inflight = Future<void>.value();

  Future<void> onResolved(String? code) {
    final previous = resolved;
    resolved = code;
    _inflight = _inflight.then((_) => _apply(code, previous));
    return _inflight;
  }

  Future<void> awaitIdle() => _inflight;

  /// Wait for in-flight field I/O, then write [resolved] only if the stash
  /// is empty or still this code. A newer deeplink is left in place.
  Future<void> persistIfStillCurrent() async {
    await awaitIdle();
    final code = resolved;
    if (code == null) return;
    try {
      final latest = await peekPendingReferralCode();
      if (latest != null && latest != code) return;
      final pause = debugTypedReferralAfterPeek;
      if (pause != null) await pause();
      if (!pendingReferralCodeIsCurrent(code)) return;
      await stashResolvedReferralCode(code);
    } catch (e) {
      developer.log('Failed to persist typed referral code: $e');
    }
  }

  Future<void> _apply(String? code, String? previous) async {
    try {
      if (code != null) {
        await stashResolvedReferralCode(code);
      } else if (previous != null) {
        await discardPendingReferralCodeIfEqual(previous);
      }
    } catch (e) {
      developer.log('Failed to persist typed referral code: $e');
    }
  }
}
