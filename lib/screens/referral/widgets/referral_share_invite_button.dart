import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/referral/share_referral_invite.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

/// Shares the personalised invite text. A second tap while the sheet is
/// open is ignored. A platform share failure keeps the label in the error
/// state for 2s and stays tappable. A new share text while the sheet is
/// open does not show that error on the new invite. If the sheet never
/// returns, resuming the app clears loading so Versenden is tappable; without
/// a resume the attempt is given up after [_shareSheetTimeout] and shows the
/// same transient error state as a failed share.
class ReferralShareInviteButton extends StatefulWidget {
  final String text;
  final bool autofocus;

  const ReferralShareInviteButton({
    super.key,
    required this.text,
    this.autofocus = false,
  });

  @override
  State<ReferralShareInviteButton> createState() =>
      _ReferralShareInviteButtonState();
}

class _ReferralShareInviteButtonState extends State<ReferralShareInviteButton>
    with WidgetsBindingObserver {
  /// How long the platform share sheet may stay silent before the button
  /// treats the attempt as unsuccessful.
  static const _shareSheetTimeout = Duration(seconds: 30);

  Timer? _reset;
  Timer? _shareTimeout;
  Completer<ShareResult?>? _settled;
  bool _failed = false;
  bool _sharing = false;
  int _shareGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ReferralShareInviteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text || (!_failed && !_sharing)) return;
    _reset?.cancel();
    _failed = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reset?.cancel();
    _shareTimeout?.cancel();
    // Release a still-awaiting _share() so its future cannot outlive the state.
    final settled = _settled;
    _settled = null;
    if (settled != null && !settled.isCompleted) settled.complete(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_sharing) return;
    // Abandon the hung sheet for good: bump the generation so a late reply is
    // ignored, and cancel the timeout so no stray timer outlives the tap.
    _shareGeneration++;
    _shareTimeout?.cancel();
    _shareTimeout = null;
    // Complete the pending wait as well: a sheet that never answers would
    // otherwise leave _share() suspended for the lifetime of the widget.
    final settled = _settled;
    _settled = null;
    if (settled != null && !settled.isCompleted) settled.complete(null);
    setState(() => _sharing = false);
  }

  Future<void> _share() async {
    if (_sharing) return;
    final generation = ++_shareGeneration;
    setState(() {
      _sharing = true;
      _failed = false;
    });
    final text = widget.text;
    final subject = S.of(context).referralInviteUrlLabel;
    // Own the timeout instead of using Future.timeout: its timer cannot be
    // cancelled, so a sheet that never returns would leave a pending timer and
    // throw a TimeoutException into a future nobody awaits.
    final settled = Completer<ShareResult?>();
    _settled = settled;
    _shareTimeout?.cancel();
    final timeout = Timer(_shareSheetTimeout, () {
      if (!settled.isCompleted) settled.complete(null);
    });
    _shareTimeout = timeout;
    unawaited(() async {
      try {
        final r = await shareReferralInvite(
          context: context,
          text: text,
          subject: subject,
        );
        if (!settled.isCompleted) settled.complete(r);
      } catch (_) {
        if (!settled.isCompleted) settled.complete(null);
      }
    }());
    try {
      final result = await settled.future;
      // Cancel our own timer, but only clear the fields while they still point
      // at this operation: a late reply must not drop a newer share's timeout.
      timeout.cancel();
      if (identical(_shareTimeout, timeout)) _shareTimeout = null;
      if (identical(_settled, settled)) _settled = null;
      if (!mounted || generation != _shareGeneration || widget.text != text) {
        return;
      }
      // null means the sheet timed out or the platform threw: neither reported
      // a successful share, so both surface the same transient failure.
      if (result != null && result.status != ShareResultStatus.unavailable) {
        return;
      }
      setState(() => _failed = true);
      _reset?.cancel();
      _reset = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _failed = false);
      });
    } finally {
      if (mounted && generation == _shareGeneration) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFilledButton(
      label: S.of(context).referralShareInviteLink,
      autofocus: widget.autofocus && !_failed && !_sharing,
      state: _sharing
          ? FilledButtonState.loading
          : _failed
              ? FilledButtonState.error
              : FilledButtonState.idle,
      onPressed: _sharing ? null : _share,
    );
  }
}
