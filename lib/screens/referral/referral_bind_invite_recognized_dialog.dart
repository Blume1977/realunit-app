import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';

/// Invite-recognized overlay after a successful invite bind on app open.
///
/// Body is [S.referralInviteRecognized] so goldens and the live bind share
/// one widget.
class ReferralBindInviteRecognizedDialog extends StatelessWidget {
  final String inviterName;

  const ReferralBindInviteRecognizedDialog({
    super.key,
    required this.inviterName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SingleChildScrollView(
        child: Text(S.of(context).referralInviteRecognized(inviterName)),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.of(context).close),
        ),
      ],
    );
  }
}
