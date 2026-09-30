import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/screens/settings/widgets/settings_section.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/styles/colors.dart';

class SettingsInsiderPage extends StatelessWidget {
  const SettingsInsiderPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(S.of(context).settingsInsiderFeatures),
    ),
    body: SingleChildScrollView(
      child: BlocBuilder<SettingsBloc, SettingsState>(
        bloc: getIt<SettingsBloc>(),
        builder: (context, state) => SettingsSections(
          settings: [
            _featureRow(
              context: context,
              title: S.of(context).settingsNetworkOptions,
              icon: Icons.lan_outlined,
              feature: InsiderFeature.networkOptions,
              enabled: state.networkOptionsEnabled,
              centrallyEnabled: false,
            ),
            _featureRow(
              context: context,
              title: S.of(context).pay,
              icon: Icons.qr_code_scanner_rounded,
              feature: InsiderFeature.pay,
              enabled: state.walletFeaturePay,
              centrallyEnabled: state.walletFeaturePayCentral,
            ),
            _featureRow(
              context: context,
              title: S.of(context).send,
              icon: Icons.send_rounded,
              feature: InsiderFeature.send,
              enabled: state.walletFeatureSend,
              centrallyEnabled: state.walletFeatureSendCentral,
            ),
            _featureRow(
              context: context,
              title: S.of(context).settingsInsiderReferral,
              icon: Icons.card_giftcard_outlined,
              feature: InsiderFeature.referral,
              enabled: state.walletFeatureReferral,
              centrallyEnabled: state.walletFeatureReferralCentral,
            ),
            _featureRow(
              context: context,
              title: S.of(context).settingsInsiderBonus,
              icon: Icons.stars_outlined,
              feature: InsiderFeature.bonus,
              enabled: state.walletFeaturePromoCode,
              centrallyEnabled: state.walletFeaturePromoCodeCentral,
            ),
          ],
        ),
      ),
    ),
  );

  SettingOption _featureRow({
    required BuildContext context,
    required String title,
    required IconData icon,
    required InsiderFeature feature,
    required bool enabled,
    required bool centrallyEnabled,
  }) => SettingOption(
    title: title,
    subtitle: centrallyEnabled ? S.of(context).settingsInsiderCentrallyEnabled : null,
    leading: Icon(
      icon,
      size: 24,
      color: RealUnitColors.realUnitBlue,
    ),
    trailing: IgnorePointer(
      child: Switch(
        value: centrallyEnabled ? true : enabled,
        onChanged: (_) {},
        activeTrackColor: RealUnitColors.realUnitBlue,
      ),
    ),
    onTap: centrallyEnabled
        ? () {}
        : () => getIt<SettingsBloc>().add(
            SetInsiderFeatureEnabledEvent(feature, !enabled),
          ),
  );
}
