// @no-integration-test: the QR scanner is camera/MethodChannel-coupled
// (mobile_scanner) and can only be exercised on a real device with a live
// camera. The decode logic it feeds is unit-tested in lnurl_decoder_test.dart
// and the cubit behaviour in pay_scan_cubit_test.dart; the camera preview
// itself is out of scope for widget tests.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_scan/pay_scan_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_quote_page.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_diagram.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_sheet.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';
import 'package:realunit_wallet/styles/colors.dart';
import 'package:realunit_wallet/widgets/scanner/push_then_rearm.dart';
import 'package:realunit_wallet/widgets/scanner/qr_scanner_view.dart';

class PayScanPage extends StatelessWidget {
  /// A DFX OpenCryptoPay payload already extracted from a payment deeplink
  /// (e.g. `lightning:LNURL1...`), fed into the cubit as if it had been
  /// scanned. Null for the normal live-camera entry (dashboard "Pay" button).
  final String? initialPayload;

  const PayScanPage({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PayScanCubit(),
      child: PayScanView(initialPayload: initialPayload),
    );
  }
}

class PayScanView extends StatefulWidget {
  final String? initialPayload;

  const PayScanView({super.key, this.initialPayload});

  @override
  State<PayScanView> createState() => _PayScanViewState();
}

class _PayScanViewState extends State<PayScanView> {
  /// True while waiting for the one-shot [initialPayload] decode; drives the
  /// spinner so it can be dismissed after invalid/decoded (unlike the
  /// immutable [PayScanView.initialPayload] widget field).
  bool _awaitingInitialDecode = false;

  /// True while the payment flow explanation sheet covers the scanner. The
  /// camera keeps running underneath, so its frames are ignored until the
  /// sheet is closed; otherwise a code in view would push the quote page on
  /// top of the sheet. Not part of the build, so no rebuild is needed.
  bool _explaining = false;

  Future<void> _showExplanation(BuildContext context) async {
    if (_explaining) return;
    _explaining = true;
    try {
      await PayFlowSheet.show(context);
    } finally {
      _explaining = false;
    }
  }

  void _onCodeDetected(BuildContext context, String raw) {
    if (_explaining) return;
    context.read<PayScanCubit>().onCodeDetected(raw);
  }

  @override
  void initState() {
    super.initState();
    final payload = widget.initialPayload;
    if (payload == null) return;
    _awaitingInitialDecode = true;
    // Deferred to after the first frame: BlocConsumer below only subscribes
    // during that first build. Calling onCodeDetected synchronously here
    // (before it subscribes) would emit PayScanDecoded/Invalid before
    // anything is listening — BlocConsumer would just pick it up as its
    // INITIAL state on first build, and its `listener` callback never fires
    // for the initial state, only for later transitions. Deferring one frame
    // guarantees the listener is already subscribed when the emission
    // happens, so the PayQuotePage push / invalid-snackbar actually fires.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PayScanCubit>().onCodeDetected(payload);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PayScanCubit, PayScanState>(
      listenWhen: (previous, current) =>
          (current is PayScanDecoded && previous is! PayScanDecoded) ||
          (current is PayScanInvalid && previous is! PayScanInvalid),
      listener: (context, state) {
        if (state is PayScanDecoded) {
          setState(() => _awaitingInitialDecode = false);
          unawaited(
            pushThenRearm(
              context,
              page: PayQuotePage(paymentLinkId: state.link.id),
              rearm: () => context.read<PayScanCubit>().reset(),
            ),
          );
        }
        if (state is PayScanInvalid) {
          setState(() => _awaitingInitialDecode = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).payScanInvalid),
              backgroundColor: RealUnitColors.status.red600,
            ),
          );
          context.read<PayScanCubit>().reset();
        }
      },
      builder: (context, state) {
        final preview = _awaitingInitialDecode
            ? const Center(child: CupertinoActivityIndicator())
            : QrScannerView(
                onDetect: (raw) => _onCodeDetected(context, raw),
                errorBuilder: (context, error) {
                  final message = error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? S.of(context).payScanCameraPermissionDenied
                      : S.of(context).payScanCameraUnavailable;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RealUnitColors.neutral500,
                        ),
                      ),
                    ),
                  );
                },
              );
        return Scaffold(
          appBar: AppBar(title: Text(S.of(context).payScanTitle)),
          body: Column(
            children: [
              // The payment flow stays in view on every payment, small here and
              // full size with its explanation after a tap.
              Semantics(
                button: true,
                label: S.of(context).payFlowShow,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showExplanation(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: RealUnitColors.neutral200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          spacing: 8,
                          children: [
                            Expanded(child: PayFlowDiagram(compact: true)),
                            Icon(
                              Icons.open_in_full,
                              size: 18,
                              color: RealUnitColors.realUnitBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!context.mounted) return;
                  context.pushNamed(AppRoutes.payLocations);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Text(
                    S.of(context).payInfoLocationsLink,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RealUnitColors.realUnitBlue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Expanded(child: preview),
            ],
          ),
        );
      },
    );
  }
}
