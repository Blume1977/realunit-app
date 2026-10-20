import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/lnurl_decoder.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_pay_service.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_scan/pay_scan_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_quote_page.dart';
import 'package:realunit_wallet/screens/pay/pay_scan_page.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_diagram.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_sheet.dart';
import 'package:realunit_wallet/setup/routing/routes/app_routes.dart';

import '../../helper/helper.dart';

class _MockPayScanCubit extends MockCubit<PayScanState> implements PayScanCubit {}

class _MockPayService extends Mock implements RealUnitPayService {}

void main() {
  late _MockPayScanCubit scanCubit;

  setUpAll(() {
    // pay_scan_page.dart carries the `@no-integration-test` note: the live
    // camera is exercised only on a real device. The stub keeps the headless
    // preview deterministic and free of MissingPluginException.
    stubMobileScannerChannel();

    // The decoded-link navigation pushes PayQuotePage, which resolves the pay
    // service from getIt and triggers a load(); register a mock whose quote
    // fetch throws so the pushed route builds deterministically (rendering the
    // PayQuoteError message) without touching a live backend.
    final payService = _MockPayService();
    when(() => payService.getPaymentDetails(any())).thenThrow(
      const ApiException(code: 'TEST', message: 'no backend in widget test'),
    );
    GetIt.instance.registerSingleton<RealUnitPayService>(payService);
  });

  tearDownAll(() async => GetIt.instance.reset());

  setUp(() {
    scanCubit = _MockPayScanCubit();
    when(() => scanCubit.state).thenReturn(const PayScanScanning());
    when(() => scanCubit.reset()).thenReturn(null);
  });

  Widget buildSubject() => BlocProvider<PayScanCubit>.value(
    value: scanCubit,
    child: const PayScanView(),
  );

  group('$PayScanPage', () {
    testWidgets('builds its own cubit and renders $PayScanView', (tester) async {
      await tester.pumpApp(const PayScanPage());

      expect(find.byType(PayScanView), findsOne);
    });
  });

  group('$PayScanView', () {
    testWidgets('renders the scan title and the scanner preview', (tester) async {
      await tester.pumpApp(buildSubject());

      expect(find.text(S.current.payScanTitle), findsOne);
      expect(find.text(S.current.payInfoLocationsLink), findsOne);
      expect(find.byType(MobileScanner), findsOne);
    });

    testWidgets('shows the payment flow small and opens the full explanation on tap', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());

      final compact = find.byKey(PayFlowDiagram.compactKey);
      expect(compact, findsOne);
      expect(find.text(S.current.payFlowStep1), findsNothing);
      expect(find.bySemanticsLabel(S.current.payFlowShow), findsOne);
      final scannerElement = tester.element(find.byType(MobileScanner));

      await tester.tap(compact);
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsOne);
      expect(find.text(S.current.payInfoTitle), findsOne);
      expect(find.text(S.current.payInfoBodyIntro), findsOne);
      expect(find.text(S.current.payFlowStep1), findsOne);
      expect(find.text(S.current.payFlowStep2), findsOne);
      expect(
        find.text(S.current.payInfoBodyDetails(S.current.transactionSaleAndPayment)),
        findsOne,
      );

      await tester.tap(find.text(S.current.close));
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsNothing);
      expect(compact, findsOne);
      // The scanner underneath is the same element as before and was not reset.
      expect(tester.element(find.byType(MobileScanner)), same(scannerElement));
      verifyNever(() => scanCubit.reset());
    });

    testWidgets('a second activation while the sheet opens does not open a second sheet', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());

      // The handler is called directly: a second touch is absorbed by the
      // navigator until the next frame, but a second activation through
      // accessibility reaches the handler before the sheet is on screen.
      final tile = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byKey(PayFlowDiagram.compactKey),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      tile.onTap!();
      tile.onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsOne);

      await tester.tap(find.text(S.current.close));
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsNothing);

      // Closing releases the guard: the next tap opens the sheet again.
      await tester.tap(find.byKey(PayFlowDiagram.compactKey));
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsOne);

      await tester.tap(find.text(S.current.close));
      await tester.pumpAndSettle();

      expect(find.byType(PayFlowSheet), findsNothing);
    });

    testWidgets('camera frames are ignored while the explanation sheet is open', (
      tester,
    ) async {
      when(() => scanCubit.onCodeDetected(any())).thenReturn(null);
      await tester.pumpApp(buildSubject());
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));

      await tester.tap(find.byKey(PayFlowDiagram.compactKey));
      await tester.pumpAndSettle();
      scanner.onDetect!(const BarcodeCapture(barcodes: [Barcode(rawValue: 'lnurl_while_open')]));
      verifyNever(() => scanCubit.onCodeDetected(any()));

      await tester.tap(find.text(S.current.close));
      await tester.pumpAndSettle();
      scanner.onDetect!(const BarcodeCapture(barcodes: [Barcode(rawValue: 'lnurl_after_close')]));
      verify(() => scanCubit.onCodeDetected('lnurl_after_close')).called(1);
    });

    testWidgets('the locations link opens the shop map', (tester) async {
      final router = GoRouter(
        initialLocation: '/scan',
        routes: [
          GoRoute(path: '/scan', builder: (_, _) => buildSubject()),
          GoRoute(
            path: '/payLocations',
            name: AppRoutes.payLocations,
            builder: (_, _) => const Text('shop-map'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
        ),
      );
      await tester.pump();

      await tester.tap(find.text(S.current.payInfoLocationsLink));
      await tester.pump();
      await tester.pump();

      expect(find.text('shop-map'), findsOneWidget);
    });

    testWidgets('onDetect forwards a scanned raw value to the cubit', (tester) async {
      when(() => scanCubit.onCodeDetected(any())).thenReturn(null);

      await tester.pumpApp(buildSubject());

      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      // A capture with no barcodes is ignored (rawValue is null) …
      scanner.onDetect!(const BarcodeCapture());
      // … while a barcode with a raw value is forwarded to the cubit.
      scanner.onDetect!(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'lnurl_raw')]),
      );

      verify(() => scanCubit.onCodeDetected('lnurl_raw')).called(1);
    });

    testWidgets('an invalid scan shows a snackbar and resets the cubit', (tester) async {
      whenListen(
        scanCubit,
        Stream<PayScanState>.fromIterable([const PayScanInvalid('bad code')]),
        initialState: const PayScanScanning(),
      );

      await tester.pumpApp(buildSubject());
      await tester.pump();

      expect(find.byType(SnackBar), findsOne);
      expect(find.text(S.current.payScanInvalid), findsOne);
      verify(() => scanCubit.reset()).called(1);
    });

    testWidgets(
      'a decoded link navigates to the quote step; reset waits until pop',
      (tester) async {
        final link = DecodedPaymentLink(
          id: 'pl_abc123',
          lnurlpUrl: Uri.parse('https://api.dfx.swiss/v1/lnurlp/pl_abc123'),
        );
        whenListen(
          scanCubit,
          Stream<PayScanState>.fromIterable([PayScanDecoded(link)]),
          initialState: const PayScanScanning(),
        );

        await tester.pumpApp(buildSubject());
        await tester.pumpAndSettle();

        // The quote step is pushed and rendered; reset is deferred until pop
        // so the Decoded guard still blocks frame 2 from double-pushing.
        expect(find.byType(PayQuoteView), findsOne);
        verifyNever(() => scanCubit.reset());

        await tester.pageBack();
        await tester.pumpAndSettle();

        verify(() => scanCubit.reset()).called(1);
      },
    );

    testWidgets(
      'errorBuilder shows the camera-unavailable message for non-permission-denied errors',
      (tester) async {
        await tester.pumpApp(buildSubject());

        final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
        final context = tester.element(find.byType(MobileScanner));
        final nonPermissionCode = MobileScannerErrorCode.values.firstWhere(
          (code) => code != MobileScannerErrorCode.permissionDenied,
        );
        final errorWidget = scanner.errorBuilder!(
          context,
          MobileScannerException(errorCode: nonPermissionCode),
        );

        await tester.pumpWidget(MaterialApp(home: errorWidget));

        expect(find.text(S.current.payScanCameraUnavailable), findsOne);
        expect(find.text(S.current.payScanCameraPermissionDenied), findsNothing);
      },
    );

    testWidgets(
      'an initialPayload feeds the cubit exactly once and skips the live camera',
      (tester) async {
        when(() => scanCubit.onCodeDetected(any())).thenReturn(null);

        await tester.pumpApp(
          BlocProvider<PayScanCubit>.value(
            value: scanCubit,
            child: const PayScanView(
              initialPayload: 'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
            ),
          ),
        );
        // CupertinoActivityIndicator animates indefinitely, so pumpAndSettle
        // would hang. One extra pump is enough for the deferred post-frame
        // onCodeDetected callback to fire.
        await tester.pump();

        verify(
          () => scanCubit.onCodeDetected(
            'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
          ),
        ).called(1);
        expect(find.byType(MobileScanner), findsNothing);
      },
    );

    testWidgets(
      'an initialPayload with a successful decode dismisses the spinner and navigates to the quote step',
      (tester) async {
        when(() => scanCubit.onCodeDetected(any())).thenReturn(null);
        final link = DecodedPaymentLink(
          id: 'pl_abc123',
          lnurlpUrl: Uri.parse('https://api.dfx.swiss/v1/lnurlp/pl_abc123'),
        );
        whenListen(
          scanCubit,
          Stream<PayScanState>.fromIterable([PayScanDecoded(link)]),
          initialState: const PayScanScanning(),
        );

        await tester.pumpApp(
          BlocProvider<PayScanCubit>.value(
            value: scanCubit,
            child: const PayScanView(
              initialPayload: 'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Spinner dismissed, quote step pushed; reset waits until pop.
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(find.byType(PayQuoteView), findsOne);
        verifyNever(() => scanCubit.reset());

        await tester.pageBack();
        await tester.pumpAndSettle();

        verify(() => scanCubit.reset()).called(1);
      },
    );

    testWidgets(
      'an invalid initialPayload dismisses the spinner and shows the live camera',
      (tester) async {
        whenListen(
          scanCubit,
          Stream<PayScanState>.fromIterable([
            const PayScanInvalid('bad code'),
          ]),
          initialState: const PayScanScanning(),
        );

        await tester.pumpApp(
          BlocProvider<PayScanCubit>.value(
            value: scanCubit,
            child: const PayScanView(
              initialPayload: 'lightning:LNURL1DP68GURN8GHJ7VF3XGENJVE5UMD',
            ),
          ),
        );
        // CupertinoActivityIndicator animates indefinitely, so pumpAndSettle
        // would hang. One extra pump is enough for the listener (invalid →
        // setState dismissing the spinner) and snackbar to run.
        await tester.pump();

        expect(find.byType(SnackBar), findsOne);
        expect(find.byType(MobileScanner), findsOneWidget);
      },
    );

    testWidgets(
      'no initialPayload never calls onCodeDetected and shows the live camera',
      (tester) async {
        await tester.pumpApp(buildSubject());
        await tester.pumpAndSettle();

        verifyNever(() => scanCubit.onCodeDetected(any()));
        expect(find.byType(MobileScanner), findsOneWidget);
      },
    );
  });
}
