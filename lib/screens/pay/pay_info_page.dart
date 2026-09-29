import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_scan_page.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';

class PayInfoPage extends StatelessWidget {
  final String? initialPayload;

  const PayInfoPage({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    final payAllowed =
        context.watch<HomeBloc>().state.openWallet?.walletType == WalletType.software;
    if (!payAllowed) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).payInfoTitle)),
        body: SafeArea(
          child: Padding(
            padding: const .symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Text(
                S.of(context).payFailurePayUnavailable,
                textAlign: .center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).payInfoTitle)),
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: 20, vertical: 16),
          child: ScrollableActionsLayout(
            centerBody: true,
            body: Text(
              S.of(context).payInfoBody,
              textAlign: .center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PayScanPage(initialPayload: initialPayload),
                  ),
                ),
                child: Text(S.of(context).next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
