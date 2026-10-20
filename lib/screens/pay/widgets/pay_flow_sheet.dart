import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_diagram.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/handlebars.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';

/// The full «Bevor Sie bezahlen» explanation again, opened from the small
/// picture on the scanner. Same content and order as [PayInfoPage]: the
/// intro, the payment flow picture, the details. Close is the only action.
class PayFlowSheet extends StatelessWidget {
  const PayFlowSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const PayFlowSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final body = Theme.of(context).textTheme.bodyMedium;
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Handlebars.horizontal(context, margin: const EdgeInsets.only(top: 5), width: 36),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: ScrollableActionsLayout(
                shrinkWrap: true,
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Text(
                        s.payInfoTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(s.payInfoBodyIntro, textAlign: TextAlign.center, style: body),
                      const PayFlowDiagram(),
                      Text(
                        s.payInfoBodyDetails(s.transactionSaleAndPayment),
                        textAlign: TextAlign.center,
                        style: body,
                      ),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: AppFilledButton(
                      variant: FilledButtonVariant.secondary,
                      fullWidth: false,
                      onPressed: () => Navigator.of(context).pop(),
                      label: s.close,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
