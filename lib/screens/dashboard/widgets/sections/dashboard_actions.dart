import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/action_button.dart';

/// Pay exists only for the software wallet. BitBox sell is a separate
/// user-signed path; Pay is financed like software-wallet sell and is not offered.
/// The account must also be allowed to pay (GET /v2/user capability); while that
/// is unknown the action stays hidden rather than appearing and vanishing.
bool showPayAction({
  required bool walletFeaturePay,
  required WalletType? walletType,
  required AccountPayAccess payAccess,
}) =>
    walletFeaturePay && walletType == WalletType.software && payAccess == AccountPayAccess.allowed;

class DashboardActions extends StatelessWidget {
  const DashboardActions({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final walletFeaturePay = settings.walletFeaturePay;
    // A locked dashboard has no Pay button, so it does not subscribe to the wallet.
    final walletType = walletFeaturePay
        ? context.watch<HomeBloc>().state.openWallet?.walletType
        : null;
    final showPay = showPayAction(
      walletFeaturePay: walletFeaturePay,
      walletType: walletType,
      payAccess: settings.payAccess,
    );

    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: ActionButton(
            icon: Icon(
              Icons.add_circle_rounded,
              color: RealUnitColors.basic.white,
              size: 20,
            ),
            label: S.of(context).buy,
            onPressed: () => context.pushNamed(AppRoutes.buy),
          ),
        ),
        Expanded(
          child: ActionButton(
            icon: Icon(
              Icons.do_not_disturb_on_rounded,
              color: RealUnitColors.basic.white,
              size: 20,
            ),
            label: S.of(context).sell,
            onPressed: () => context.pushNamed(AppRoutes.sell),
          ),
        ),
        if (showPay)
          Expanded(
            child: ActionButton(
              icon: Icon(
                Icons.qr_code_scanner_rounded,
                color: RealUnitColors.basic.white,
                size: 20,
              ),
              label: S.of(context).pay,
              onPressed: () => context.pushNamed(AppRoutes.pay),
            ),
          ),
      ],
    );
  }
}
