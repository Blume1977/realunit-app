import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/colors.dart';

class TestnetBanner extends StatelessWidget {
  const TestnetBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    buildWhen: (previous, current) => previous.networkMode != current.networkMode,
    builder: (context, state) {
      if (!state.networkMode.isTestnet) return child;
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Material(
              color: RealUnitColors.okker,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    S.of(context).testnetBanner,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RealUnitColors.realUnitBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );
    },
  );
}
