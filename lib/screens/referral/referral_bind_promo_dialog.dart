import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';

/// Promo overlay after a successful promo bind on app open.
///
/// Body is the campaign text from the API so goldens and the live bind share
/// one widget.
class ReferralBindPromoDialog extends StatelessWidget {
  final String campaignText;
  final String textLang;

  const ReferralBindPromoDialog({
    super.key,
    required this.campaignText,
    required this.textLang,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).referralPromoTitle),
      content: SingleChildScrollView(
        child: Text(campaignText, locale: Locale(textLang)),
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
