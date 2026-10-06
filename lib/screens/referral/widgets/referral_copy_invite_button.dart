import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

/// Copies the personalised invite share text and shows «Kopiert» for 2s
/// after a successful clipboard write. A failed write keeps the copy label
/// in the error state for 2s and stays tappable. Copy is loading (not
/// tappable) while the write is in flight. A hung write is treated as a failure
/// after 2s so copy is not stuck (same as the landing copy control).
/// A second tap after Kopiert copies again and restarts the timer.
/// A new share text does not confirm or error a write that started on a
/// previous invite.
class ReferralCopyInviteButton extends StatefulWidget {
  final String text;

  const ReferralCopyInviteButton({super.key, required this.text});

  @override
  State<ReferralCopyInviteButton> createState() =>
      _ReferralCopyInviteButtonState();
}

class _ReferralCopyInviteButtonState extends State<ReferralCopyInviteButton> {
  /// How long a clipboard write may stay silent before the button treats the
  /// attempt as unsuccessful.
  static const _clipboardWriteTimeout = Duration(seconds: 2);

  Timer? _reset;
  Timer? _copyTimeout;
  Completer<bool>? _settled;
  bool _copied = false;
  bool _failed = false;
  bool _copying = false;
  int _copyGeneration = 0;

  @override
  void didUpdateWidget(ReferralCopyInviteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text ||
        (!_copied && !_failed && !_copying)) {
      return;
    }
    _reset?.cancel();
    _copied = false;
    _failed = false;
  }

  @override
  void dispose() {
    // Bump first: mounted is still true during dispose, so a continuation
    // must see the generation change and return before setState.
    _copyGeneration++;
    _reset?.cancel();
    _copyTimeout?.cancel();
    // Release a still-awaiting _copy() so its future cannot outlive the state.
    final settled = _settled;
    _settled = null;
    if (settled != null && !settled.isCompleted) settled.complete(false);
    super.dispose();
  }

  Future<void> _copy() async {
    if (_copying) return;
    final generation = ++_copyGeneration;
    setState(() {
      _copying = true;
      _failed = false;
      _copied = false;
    });
    final text = widget.text;
    // Own the timeout instead of using Future.timeout: its timer cannot be
    // cancelled, so a write that never returns would leave a pending timer and
    // throw a TimeoutException into a future nobody awaits.
    final settled = Completer<bool>();
    _settled = settled;
    _copyTimeout?.cancel();
    final timeout = Timer(_clipboardWriteTimeout, () {
      if (!settled.isCompleted) settled.complete(false);
    });
    _copyTimeout = timeout;
    unawaited(() async {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (!settled.isCompleted) settled.complete(true);
      } catch (_) {
        if (!settled.isCompleted) settled.complete(false);
      }
    }());
    try {
      final succeeded = await settled.future;
      // Cancel our own timer, but only clear the fields while they still point
      // at this operation: a late reply must not drop a newer copy's timeout.
      timeout.cancel();
      if (identical(_copyTimeout, timeout)) _copyTimeout = null;
      if (identical(_settled, settled)) _settled = null;
      if (!mounted || generation != _copyGeneration || widget.text != text) {
        return;
      }
      if (succeeded) {
        setState(() {
          _copied = true;
          _failed = false;
        });
        _reset?.cancel();
        _reset = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      } else {
        setState(() {
          _copied = false;
          _failed = true;
        });
        _reset?.cancel();
        _reset = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _failed = false);
        });
      }
    } finally {
      if (mounted && generation == _copyGeneration) {
        setState(() => _copying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = _copied ? s.referralCopied : s.referralCopyInviteLink;
    return Semantics(
      container: true,
      liveRegion: _copied,
      label: _copied ? '${s.referralCopied}. ${widget.text}' : null,
      child: AppFilledButton(
        label: label,
        variant: FilledButtonVariant.secondary,
        state: _copying
            ? FilledButtonState.loading
            : _copied
                ? FilledButtonState.success
                : _failed
                    ? FilledButtonState.error
                    : FilledButtonState.idle,
        onPressed: _copying ? null : _copy,
      ),
    );
  }
}
