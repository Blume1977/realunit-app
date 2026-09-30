import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/handlebars.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';

class StartupFailureResetSheet extends StatefulWidget {
  const StartupFailureResetSheet({super.key});

  @override
  State<StartupFailureResetSheet> createState() => _StartupFailureResetSheetState();
}

class _StartupFailureResetSheetState extends State<StartupFailureResetSheet> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Handlebars.horizontal(
            context,
            margin: const EdgeInsets.only(top: 5),
            width: 36,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: ScrollableActionsLayout(
              shrinkWrap: true,
              actionsSpacing: 16,
              padding: const EdgeInsets.symmetric(
                vertical: 40,
                horizontal: 30,
              ),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(
                    s.realunitWalletLogout,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  Text(
                    s.startupFailureResetDescription,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: RealUnitColors.neutral500,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Semantics(
                    identifier: 'startup-failure-reset-confirm-checkbox',
                    toggled: _isChecked,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isChecked = !_isChecked),
                      child: Row(
                        spacing: 12,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: AbsorbPointer(
                              child: Checkbox(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                checkColor: RealUnitColors.basic.white,
                                activeColor: RealUnitColors.green,
                                value: _isChecked,
                                onChanged: (value) => setState(
                                  () => _isChecked = value ?? false,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s.startupFailureResetCheck,
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: AppFilledButton(
                        variant: FilledButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                        label: s.close,
                      ),
                    ),
                    Expanded(
                      child: AppFilledButton(
                        onPressed: _isChecked ? () => Navigator.of(context).pop(true) : null,
                        label: s.reset,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
