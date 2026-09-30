import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/debug_auth/cubit/debug_auth_cubit.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/buttons/app_filled_button.dart';
import 'package:realunit_wallet/widgets/buttons/app_text_button.dart';
import 'package:realunit_wallet/widgets/form/labeled_text_field.dart';

class DebugAuthView extends StatefulWidget {
  const DebugAuthView({super.key});

  @override
  State<DebugAuthView> createState() => _DebugAuthViewState();
}

class _DebugAuthViewState extends State<DebugAuthView> {
  late final TextEditingController _addressController;
  late final TextEditingController _signatureController;

  @override
  void initState() {
    super.initState();
    final state = context.read<DebugAuthCubit>().state;
    _addressController = TextEditingController(text: state.address);
    _signatureController = TextEditingController(text: state.savedSignature ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(S.of(context).debugWalletTitle)),
    body: BlocListener<DebugAuthCubit, DebugAuthState>(
      listenWhen: (prev, curr) => !prev.isAuthenticated && curr.isAuthenticated,
      listener: (context, state) {
        context.read<HomeBloc>().add(DebugAuthCompleteEvent(address: state.address));
      },
      child: BlocBuilder<DebugAuthCubit, DebugAuthState>(
        builder: (context, state) => SingleChildScrollView(
          padding: const .symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 16,
            children: [
              LabeledTextField(
                label: S.of(context).address,
                hintText: '0x...',
                controller: _addressController,
              ),
              AppTextButton(
                onPressed: state.isLoading
                    ? null
                    : () => context.read<DebugAuthCubit>().fetchSignMessage(
                        _addressController.text.trim(),
                      ),
                label: S.of(context).signMessageGet,
              ),
              if (state.signMessage != null) ...[
                const Divider(color: RealUnitColors.neutral200),
                Text(
                  '${S.of(context).signMessage}:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: .w600),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: state.signMessage!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.of(context).copyClipboard),
                        backgroundColor: RealUnitColors.green,
                      ),
                    );
                  },
                  child: Container(
                    padding: const .all(12),
                    decoration: BoxDecoration(
                      color: RealUnitColors.neutral100,
                      borderRadius: .circular(8),
                    ),
                    child: SelectableText(
                      state.signMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                LabeledTextField(
                  label: S.of(context).signature,
                  hintText: '0x...',
                  maxLines: null,
                  controller: _signatureController,
                ),
                AppFilledButton(
                  state: state.isLoading ? .loading : .idle,
                  onPressed: () => context.read<DebugAuthCubit>().authenticate(
                    _signatureController.text.trim(),
                  ),
                  label: S.of(context).authenticate,
                ),
              ],
              if (state.missingSignMessage || state.errorMessage != null)
                Container(
                  padding: const .all(12),
                  decoration: BoxDecoration(
                    color: RealUnitColors.status.red600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.missingSignMessage
                        ? S.of(context).debugAuthMissingSignMessage
                        : state.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RealUnitColors.status.red600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
