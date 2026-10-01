import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';

/// Overlay when a bind code cannot be checked right now.
class ReferralBindUnavailableDialog extends StatelessWidget {
  final bool retrying;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const ReferralBindUnavailableDialog({
    super.key,
    required this.retrying,
    this.onRetry,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(S.of(context).referralCodeUnavailable),
      actions: [
        AppFilledButton(
          label: S.of(context).retry,
          autofocus: !retrying,
          fullWidth: false,
          variant: FilledButtonVariant.secondary,
          state: retrying
              ? FilledButtonState.loading
              : FilledButtonState.idle,
          onPressed: retrying ? null : onRetry,
        ),
        TextButton(
          onPressed: retrying ? null : onClose,
          child: Text(S.of(context).close),
        ),
      ],
    );
  }
}
