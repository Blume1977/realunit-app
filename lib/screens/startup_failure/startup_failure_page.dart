import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/screens/startup_failure/widgets/startup_failure_reset_sheet.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/scrollable_actions_layout.dart';

class StartupFailurePage extends StatefulWidget {
  const StartupFailurePage({super.key});

  @override
  State<StartupFailurePage> createState() => _StartupFailurePageState();
}

class _StartupFailurePageState extends State<StartupFailurePage> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<StartupFailureCubit>();
    // A start that failed while the device was locked can succeed on resume;
    // the missing-key case cannot heal, so it is left to the user.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!cubit.state.canResetWallet) {
          cubit.retry();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _openResetSheet(StartupFailureCubit cubit) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StartupFailureResetSheet(),
    );
    if (confirmed == true && mounted) {
      await cubit.resetWallet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<StartupFailureCubit, StartupFailureState>(
            builder: (context, state) {
              final cubit = context.read<StartupFailureCubit>();
              return ScrollableActionsLayout(
                padding: const EdgeInsets.all(20),
                centerBody: true,
                body: Column(
                  spacing: 16,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: RealUnitColors.status.red600,
                    ),
                    Text(
                      s.startupFailureTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    Text(
                      state.canResetWallet
                          ? s.startupFailureKeyMissingDescription
                          : s.startupFailureDescription,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
                    ),
                    if (state.actionFailed)
                      Text(
                        s.startupFailureActionFailed,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: RealUnitColors.status.red600,
                        ),
                      ),
                  ],
                ),
                actions: [
                  AppFilledButton(
                    label: s.retry,
                    state: state.isBusy ? FilledButtonState.loading : FilledButtonState.idle,
                    onPressed: () => cubit.retry(),
                  ),
                  if (state.canResetWallet)
                    AppFilledButton(
                      variant: FilledButtonVariant.secondary,
                      label: s.settingsDeleteWallet,
                      onPressed: state.isBusy ? null : () => _openResetSheet(cubit),
                    ),
                  AppFilledButton(
                    variant: FilledButtonVariant.secondary,
                    label: s.contactSupport,
                    onPressed: state.isBusy
                        ? null
                        : () => launchUrl(
                            Uri.parse('mailto:info@realunit.ch'),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
