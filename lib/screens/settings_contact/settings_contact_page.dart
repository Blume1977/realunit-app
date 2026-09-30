import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_registration_service.dart';
import 'package:realunit_wallet/packages/utils/real_unit_faq_uri.dart';
import 'package:realunit_wallet/screens/settings_contact/cubit/settings_contact_cubit.dart';
import 'package:realunit_wallet/screens/web_view/web_view_page.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/setup/routing/routes/support_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/outlined_tile.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsContactPage extends StatelessWidget {
  const SettingsContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsContactCubit(
        kycService: getIt<DfxKycService>(),
        registrationService: getIt<RealUnitRegistrationService>(),
      )..init(),
      child: const SettingsContactView(),
    );
  }
}

class SettingsContactView extends StatelessWidget {
  const SettingsContactView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).contact),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const .symmetric(
            horizontal: 20.0,
            vertical: 16.0,
          ),
          child: Column(
            spacing: 20.0,
            crossAxisAlignment: .start,
            children: [
              Column(
                spacing: 12.0,
                children: [
                  BlocBuilder<SettingsContactCubit, SettingsContactState>(
                    builder: (context, state) {
                      return OutlinedTile(
                        leading: const Icon(
                          Icons.support_agent_outlined,
                          color: RealUnitColors.realUnitBlue,
                          size: 24,
                        ),
                        title: S.of(context).contactSupport,
                        subtitle: S.of(context).contactSupportDescription,
                        onTap: () => _onSupportTap(context, state),
                        trailingIcon: Icons.chevron_right_rounded,
                      );
                    },
                  ),
                  BlocBuilder<SettingsContactCubit, SettingsContactState>(
                    builder: (context, state) {
                      final symbol = state is SettingsContactSuccess
                          ? state.residenceCountrySymbol
                          : null;
                      return OutlinedTile(
                        leading: const Icon(
                          Icons.help_outline,
                          color: RealUnitColors.realUnitBlue,
                          size: 24,
                        ),
                        title: S.of(context).contactFaq,
                        subtitle: S.of(context).contactFaqDescription,
                        onTap: () => context.pushNamed(
                          AppRoutes.webView,
                          extra: WebViewRouteParams(
                            title: S.of(context).contactFaq,
                            url: realUnitFaqUri(symbol),
                          ),
                        ),
                        trailingIcon: Icons.open_in_new_outlined,
                      );
                    },
                  ),
                  OutlinedTile(
                    leading: const Icon(
                      Icons.phone_outlined,
                      color: RealUnitColors.realUnitBlue,
                      size: 24,
                    ),
                    title: S.of(context).phone,
                    subtitle: '+41 41 761 00 90',
                    onTap: () => launchUrl(Uri.parse('tel:+41417610090')),
                    trailingIcon: Icons.open_in_new_outlined,
                  ),
                  OutlinedTile(
                    leading: const Icon(
                      Icons.email_outlined,
                      color: RealUnitColors.realUnitBlue,
                      size: 24,
                    ),
                    title: S.of(context).email,
                    subtitle: 'info@realunit.ch',
                    onTap: () => launchUrl(Uri.parse('mailto:info@realunit.ch')),
                    trailingIcon: Icons.open_in_new_outlined,
                  ),
                  OutlinedTile(
                    leading: const Icon(
                      Icons.language_outlined,
                      color: RealUnitColors.realUnitBlue,
                      size: 24,
                    ),
                    title: S.of(context).website,
                    subtitle: 'realunit.ch',
                    onTap: () => context.pushNamed(
                      AppRoutes.webView,
                      extra: WebViewRouteParams(
                        title: S.of(context).website,
                        url: Uri.parse('https://realunit.ch'),
                      ),
                    ),
                    trailingIcon: Icons.open_in_new_outlined,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: .start,
                spacing: 12.0,
                children: [
                  Text(
                    S.of(context).imprint,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 18,
                      height: 24 / 18,
                    ),
                  ),
                  const OutlinedTile(
                    leading: Icon(
                      Icons.business_outlined,
                      color: RealUnitColors.realUnitBlue,
                      size: 24,
                    ),
                    title: 'RealUnit Schweiz AG',
                    subtitle: 'Schochenmühlestrasse 6\n6340 Baar, Schweiz',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSupportTap(
    BuildContext context,
    SettingsContactState state,
  ) async {
    final capability = state is SettingsContactSuccess ? state.capability : null;

    // Branch 1: no capability info (legacy backend / Initial / Loading
    // / Failure). API is the authority — if the call is not allowed,
    // the Support page surfaces the API error.
    if (capability == null) {
      context.pushNamed(SupportRoutes.support);
      return;
    }

    // Branch 2: explicitly available → straight to Support.
    if (capability.available) {
      context.pushNamed(SupportRoutes.support);
      return;
    }

    // Branch 3: a prerequisite is missing. Today the only modeled
    // value is `email`; new enum members get their own routing branch
    // here. `unknown` is the open-enum fallback for additive backend
    // values this app version does not yet recognise.
    switch (capability.missingPrerequisite) {
      case MissingPrerequisite.email:
        await _pushEmailCaptureThenSupport(context);
      case MissingPrerequisite.unknown:
      case null:
        // Defensive: API reported `available: false` without a
        // prerequisite this app version routes for. Push Support
        // directly and let the API render the error.
        context.pushNamed(SupportRoutes.support);
    }
  }

  Future<void> _pushEmailCaptureThenSupport(BuildContext context) async {
    final cubit = context.read<SettingsContactCubit>();
    final captured = await context.pushNamed<bool>(SupportRoutes.emailCapture);
    if (captured != true) return;
    if (!context.mounted) return;

    // Re-fetch the user so the cubit picks up the freshly registered
    // email. Symmetric to Branch 1: a refreshed state with capability
    // == null (legacy backend) or available == true forwards; an
    // explicit unavailable+missingPrerequisite refresh does not (would
    // re-loop the same capture page).
    await cubit.init();
    if (!context.mounted) return;
    final state = cubit.state;
    if (state is! SettingsContactSuccess) return;
    final refreshed = state.capability;
    if (refreshed == null || refreshed.available) {
      context.pushNamed(SupportRoutes.support);
    }
  }
}
