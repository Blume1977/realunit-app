import 'package:bitbox_flutter/bitbox_flutter.dart' as sdk;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/hardware_wallet/bitbox.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/registration_date_unavailable_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/registration/kyc/kyc_personal_data.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/real_unit_user_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_registration_service.dart';
import 'package:realunit_wallet/packages/service/wallet_service.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/hardware_connect_bitbox/connect_bitbox_page.dart';
import 'package:realunit_wallet/screens/hardware_connect_bitbox/connect_bitbox_view.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/kyc/cubits/kyc/kyc_cubit.dart';
import 'package:realunit_wallet/screens/kyc/steps/link_wallet/cubits/kyc_link_wallet_cubit.dart';
import 'package:realunit_wallet/screens/kyc/steps/link_wallet/kyc_link_wallet_page.dart';
import 'package:web3dart/web3dart.dart';

import '../../../../helper/helper.dart';

class _MockKycLinkWalletCubit extends MockCubit<KycLinkWalletState> implements KycLinkWalletCubit {}

class _MockKycCubit extends MockCubit<KycState> implements KycCubit {}

class _MockAppStore extends Mock implements AppStore {}

class _MockRealUnitRegistrationService extends Mock implements RealUnitRegistrationService {}

class _MockBitboxService extends Mock implements BitboxService {}

class _MockWalletService extends Mock implements WalletService {}

class _MockDfxKycService extends Mock implements DfxKycService {}

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class _FakeBitboxWallet extends Fake implements BitboxWallet {}

const _kycData = KycPersonalData(
  accountType: KycAccountType.personal,
  firstName: 'Ada',
  lastName: 'Lovelace',
  phone: '+41790000000',
  address: KycAddress(street: 'S', zip: '8000', city: 'Zurich', country: 41),
);

const _userData = RealUnitUserDataDto(
  email: 'ada@example.com',
  name: 'Ada Lovelace',
  type: 'HUMAN',
  phoneNumber: '+41790000000',
  birthday: '1815-12-10',
  nationality: 'CH',
  addressStreet: 'S',
  addressPostalCode: '8000',
  addressCity: 'Zurich',
  addressCountry: 'CH',
  swissTaxResidence: true,
  lang: 'de',
  kycData: _kycData,
);

const _debugAddress = '0xfaeefaeefaeefaeefaeefaeefaeefaeefaeeb6a0';

void main() {
  late _MockKycLinkWalletCubit linkCubit;
  late _MockKycCubit kycCubit;
  late _MockHomeBloc homeBloc;

  setUpAll(() {
    registerFallbackValue(_userData);
    registerFallbackValue(SyncWalletServicesEvent(_FakeBitboxWallet()));

    final getIt = GetIt.instance;
    final appStore = _MockAppStore();
    when(() => appStore.wallet).thenReturn(DebugWallet(1, 'Test', _debugAddress));
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton<RealUnitRegistrationService>(
      _MockRealUnitRegistrationService(),
    );

    // ConnectBitboxPage (opened by the BitboxRequired listener) builds a real
    // ConnectBitboxCubit off these getIt dependencies. An empty device list
    // keeps the connect sheet parked in its idle scanning state, so the tests
    // can assert the sheet wiring without driving the pairing ceremony.
    final bitboxService = _MockBitboxService();
    when(() => bitboxService.getAllUsbDevices()).thenAnswer((_) async => <sdk.BitboxDevice>[]);
    when(() => bitboxService.startScan()).thenAnswer((_) async => false);
    getIt.registerSingleton<BitboxService>(bitboxService);
    getIt.registerSingleton<WalletService>(_MockWalletService());
    getIt.registerSingleton<DfxKycService>(_MockDfxKycService());
  });

  tearDownAll(() async => await GetIt.instance.reset());

  setUp(() {
    linkCubit = _MockKycLinkWalletCubit();
    kycCubit = _MockKycCubit();
    homeBloc = _MockHomeBloc();
    when(() => linkCubit.state).thenReturn(const KycLinkWalletReady(_userData));
    when(() => kycCubit.state).thenReturn(const KycInitial());
    when(() => kycCubit.checkKyc()).thenAnswer((_) async {});
    when(() => linkCubit.submit(any())).thenAnswer((_) async {});
  });

  Widget buildSubject() => MultiBlocProvider(
    providers: [
      BlocProvider<KycCubit>.value(value: kycCubit),
      BlocProvider<KycLinkWalletCubit>.value(value: linkCubit),
    ],
    child: const KycLinkWalletView(),
  );

  group('$KycLinkWalletView', () {
    testWidgets('renders the userData name and the current wallet address in Ready', (
      tester,
    ) async {
      when(() => linkCubit.state).thenReturn(const KycLinkWalletReady(_userData));

      await tester.pumpApp(buildSubject());

      expect(find.text(_userData.name), findsOne);
      // hexEip55 of an all-lowercase 0xface…fa address mixes case; assert the
      // 0x prefix is present and the address renders fully so a future change
      // that crops it (e.g. to "0xfaee…b6a0") would fail loud.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('0x') ?? false) && w.data!.length == 42,
        ),
        findsOne,
      );
    });

    testWidgets('button triggers cubit.submit with the userData', (tester) async {
      when(() => linkCubit.state).thenReturn(const KycLinkWalletReady(_userData));

      await tester.pumpApp(buildSubject());

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verify(() => linkCubit.submit(_userData)).called(1);
    });

    testWidgets('button is disabled while Submitting', (tester) async {
      when(() => linkCubit.state).thenReturn(const KycLinkWalletSubmitting(_userData));

      await tester.pumpApp(buildSubject());

      final btn = tester.widget<FilledButton>(find.bySubtype<FilledButton>());
      expect(btn.onPressed, isNull);
    });

    testWidgets('Success state triggers KycCubit.checkKyc', (tester) async {
      whenListen(
        linkCubit,
        Stream.fromIterable([const KycLinkWalletSuccess()]),
        initialState: const KycLinkWalletReady(_userData),
      );

      await tester.pumpApp(buildSubject());
      await tester.pump();

      verify(() => kycCubit.checkKyc()).called(1);
    });

    testWidgets('Failure shows a SnackBar', (tester) async {
      whenListen(
        linkCubit,
        Stream.fromIterable([const KycLinkWalletFailure('boom')]),
        initialState: const KycLinkWalletReady(_userData),
      );

      await tester.pumpApp(buildSubject());
      await tester.pump();

      expect(find.byType(SnackBar), findsOne);
    });

    testWidgets('an unavailable registration date shows the localized message', (tester) async {
      whenListen(
        linkCubit,
        Stream.fromIterable([
          const KycLinkWalletFailure(
            'Invalid registration date in API response',
            cause: RegistrationDateUnavailableException(
              message: 'Invalid registration date in API response',
            ),
          ),
        ]),
        initialState: const KycLinkWalletReady(_userData),
      );

      await tester.pumpApp(buildSubject());
      await tester.pump();

      expect(
        find.text(
          'The registration date could not be loaded. Nothing was signed. Please try again.',
        ),
        findsOne,
      );
      expect(find.textContaining('API response'), findsNothing);
    });
  });

  group('$KycLinkWalletView BitBox connect sheet', () {
    // Drives the cubit from Ready to BitboxRequired so the page listener fires.
    void emitBitboxRequired() => whenListen(
      linkCubit,
      Stream.fromIterable([const KycLinkWalletBitboxRequired(_userData)]),
      initialState: const KycLinkWalletReady(_userData),
    );

    // Opens, then settles, the connect sheet. Popping the modal route disposes
    // the real ConnectBitboxCubit, which cancels its periodic scan timer — so
    // every test must close the sheet to avoid a pending-timer failure.
    Future<void> pumpUntilSheetOpen(WidgetTester tester) async {
      await tester.pumpApp(buildSubject());
      await tester.pump(); // deliver BitboxRequired to the listener
      await tester.pump(const Duration(milliseconds: 350)); // sheet open animation
    }

    NavigatorState sheetNavigator(WidgetTester tester) =>
        Navigator.of(tester.element(find.byType(ConnectBitboxPage)));

    testWidgets('BitboxRequired opens the ConnectBitboxPage connect sheet', (tester) async {
      emitBitboxRequired();

      await pumpUntilSheetOpen(tester);

      expect(find.byType(ConnectBitboxPage), findsOneWidget);

      sheetNavigator(tester).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('a successful connect (sheet returns true) retries registration', (tester) async {
      when(() => linkCubit.retrySubmit(any())).thenAnswer((_) async {});
      emitBitboxRequired();

      await pumpUntilSheetOpen(tester);
      expect(find.byType(ConnectBitboxPage), findsOneWidget);

      // ConnectBitboxView.onFinish pops the sheet with `true` once the device
      // is linked; reproduce that result here.
      sheetNavigator(tester).pop(true);
      await tester.pumpAndSettle();

      verify(() => linkCubit.retrySubmit(_userData)).called(1);
    });

    testWidgets('dismissing the sheet without connecting does not retry', (tester) async {
      when(() => linkCubit.retrySubmit(any())).thenAnswer((_) async {});
      emitBitboxRequired();

      await pumpUntilSheetOpen(tester);
      expect(find.byType(ConnectBitboxPage), findsOneWidget);

      // Back button / scrim tap pops with a null result.
      sheetNavigator(tester).pop();
      await tester.pumpAndSettle();

      verifyNever(() => linkCubit.retrySubmit(any()));
    });

    testWidgets('onFinish syncs the wallet, pops true, and retries registration', (tester) async {
      when(() => linkCubit.retrySubmit(any())).thenAnswer((_) async {});
      emitBitboxRequired();

      // `onFinish` calls `context.pop(true)` (go_router), so host the view in a
      // GoRouter stack; with the sheet route on top, canPop is true.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<KycCubit>.value(value: kycCubit),
                BlocProvider<KycLinkWalletCubit>.value(value: linkCubit),
                BlocProvider<HomeBloc>.value(value: homeBloc),
              ],
              child: const KycLinkWalletView(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: [S.delegate, GlobalMaterialLocalizations.delegate],
          supportedLocales: S.delegate.supportedLocales,
        ),
      );
      await tester.pump(); // deliver BitboxRequired to the listener
      await tester.pump(const Duration(milliseconds: 350)); // sheet open animation
      expect(find.byType(ConnectBitboxView), findsOneWidget);

      // ConnectBitboxPage forwards the page's onFinish straight to the view;
      // invoke it exactly as the connect flow does on BitboxFinishSetup.
      final view = tester.widget<ConnectBitboxView>(find.byType(ConnectBitboxView));
      view.onFinish(_FakeBitboxWallet());
      await tester.pumpAndSettle();

      verify(() => homeBloc.add(any(that: isA<SyncWalletServicesEvent>()))).called(1);
      verify(() => linkCubit.retrySubmit(_userData)).called(1);
    });
  });

  group('$KycLinkWalletPage with missing userData', () {
    testWidgets(
      'renders defensive page with a retry button when no userData is supplied',
      (tester) async {
        // The parent cubit is provided so the retry button can resolve
        // `KycCubit` from the widget tree.
        await tester.pumpApp(
          BlocProvider<KycCubit>.value(
            value: kycCubit,
            child: const KycLinkWalletPage(),
          ),
        );

        // The fallback page must not spin up the cubit (no provider
        // available) and must surface a retry control.
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        verify(() => kycCubit.checkKyc()).called(1);
      },
    );
  });

  group('$KycLinkWalletPage with userData', () {
    testWidgets('wires its own cubit from getIt and renders the confirm body', (tester) async {
      await tester.pumpApp(
        BlocProvider<KycCubit>.value(
          value: kycCubit,
          child: const KycLinkWalletPage(userData: _userData),
        ),
      );

      // The page builds a real KycLinkWalletCubit (seeded to Ready) via getIt
      // and renders the confirm body — exercising the userData branch of build.
      expect(find.text(_userData.name), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });

  group('$KycLinkWalletPage shows every signed field before the sign action', () {
    // Distinct values per field so one field cannot satisfy another's finder.
    RealUnitUserDataDto signedUserData({bool swissTaxResidence = true}) => RealUnitUserDataDto(
      email: 'ada@example.com',
      name: 'Ada Lovelace',
      type: 'HUMAN',
      phoneNumber: '+41790000000',
      birthday: '1815-12-10',
      nationality: 'DE',
      addressStreet: 'Bahnhofstrasse 1',
      addressPostalCode: '8001',
      addressCity: 'Zurich',
      addressCountry: 'CH',
      swissTaxResidence: swissTaxResidence,
      lang: 'de',
      kycData: _kycData,
    );

    // Each field is satisfied by its raw value or a common display form of it.
    final fields = <String, List<Pattern>>{
      'name': ['Ada Lovelace'],
      'email': ['ada@example.com'],
      'phone number': ['+41790000000', '+41 79 000 00 00'],
      'birthday': [
        '1815-12-10',
        '10.12.1815',
        '10/12/1815',
        '12/10/1815',
        RegExp(r'Dec(ember)? 10, 1815'),
        RegExp(r'10 Dec(ember)? 1815'),
      ],
      'nationality': [RegExp(r'\bDE\b'), 'Germany', 'German'],
      'street': ['Bahnhofstrasse 1'],
      'postal code': ['8001'],
      'city': ['Zurich'],
      'country': [RegExp(r'\bCH\b'), 'Switzerland'],
      'Swiss tax residence': [RegExp(r'^Yes$')],
      'wallet address': [EthereumAddress.fromHex(_debugAddress).hexEip55],
      'account type': [
        'HUMAN',
        RegExp('individual person|natural person', caseSensitive: false),
      ],
    };

    for (final MapEntry(key: field, value: patterns) in fields.entries) {
      testWidgets('shows the $field', (tester) async {
        await tester.pumpApp(
          BlocProvider<KycCubit>.value(
            value: kycCubit,
            child: KycLinkWalletPage(userData: signedUserData()),
          ),
          locale: const Locale('en'),
        );

        final shown = find.byWidgetPredicate((widget) {
          final String? text = switch (widget) {
            Text(:final data, :final textSpan) => data ?? textSpan?.toPlainText(),
            RichText(:final text) => text.toPlainText(),
            _ => null,
          };
          return text != null && patterns.any((p) => p.allMatches(text).isNotEmpty);
        });
        expect(shown, findsAtLeastNWidgets(1), reason: 'the signed $field must be shown');
        verifyNever(
          () => GetIt.instance<RealUnitRegistrationService>().registerWallet(any()),
        );
      });
    }

    testWidgets('shows a Swiss tax residence that is not set as No', (tester) async {
      await tester.pumpApp(
        BlocProvider<KycCubit>.value(
          value: kycCubit,
          child: KycLinkWalletPage(userData: signedUserData(swissTaxResidence: false)),
        ),
        locale: const Locale('en'),
      );

      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes'), findsNothing);
    });
  });
}
