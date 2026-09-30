import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/config/network_mode.dart';
import 'package:realunit_wallet/packages/repository/settings_repository.dart';
import 'package:realunit_wallet/packages/service/dfx/models/wallet_features/dto/real_unit_wallet_features_dto.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository repo;
  late int authRefreshCount;
  late bool storedPay;
  late bool storedSend;
  late bool storedPromo;
  late bool storedReferral;
  late bool payCentral;
  late bool sendCentral;
  late bool promoCentral;
  late bool referralCentral;

  setUp(() {
    repo = _MockSettingsRepository();
    authRefreshCount = 0;
    storedPay = false;
    storedSend = false;
    storedPromo = false;
    storedReferral = false;
    payCentral = false;
    sendCentral = false;
    promoCentral = false;
    referralCentral = false;
    // Defaults — sane values for the initial state.
    when(() => repo.language).thenReturn('en');
    when(() => repo.currency).thenReturn('EUR');
    when(() => repo.hasStoredCurrency).thenReturn(false);
    when(() => repo.networkMode).thenReturn(NetworkMode.mainnet);
    when(() => repo.insiderFeaturesUnlocked).thenReturn(false);
    when(() => repo.networkOptionsEnabled).thenReturn(false);
    when(() => repo.walletFeaturePay).thenAnswer((_) => payCentral || storedPay);
    when(() => repo.walletFeatureSend).thenAnswer((_) => sendCentral || storedSend);
    when(() => repo.walletFeaturePromoCode).thenAnswer((_) => promoCentral || storedPromo);
    when(() => repo.walletFeatureReferral).thenAnswer((_) => referralCentral || storedReferral);
    when(() => repo.walletFeaturePayCentral).thenAnswer((_) => payCentral);
    when(() => repo.walletFeatureSendCentral).thenAnswer((_) => sendCentral);
    when(() => repo.walletFeaturePromoCodeCentral).thenAnswer((_) => promoCentral);
    when(() => repo.walletFeatureReferralCentral).thenAnswer((_) => referralCentral);
    when(() => repo.walletFeaturePay = any()).thenAnswer((inv) {
      final value = inv.positionalArguments.first as bool;
      if (value) payCentral = true;
      return value;
    });
    when(() => repo.setWalletFeaturePayFromUser(any())).thenAnswer((inv) {
      final enabled = inv.positionalArguments.first as bool;
      if (payCentral) return;
      storedPay = enabled;
    });
    when(() => repo.walletFeatureSend = any()).thenAnswer((inv) {
      final value = inv.positionalArguments.first as bool;
      if (value) sendCentral = true;
      return value;
    });
    when(() => repo.setWalletFeatureSendFromUser(any())).thenAnswer((inv) {
      final enabled = inv.positionalArguments.first as bool;
      if (sendCentral) return;
      storedSend = enabled;
    });
    when(() => repo.walletFeaturePromoCode = any()).thenAnswer((inv) {
      final value = inv.positionalArguments.first as bool;
      if (value) promoCentral = true;
      return value;
    });
    when(() => repo.setWalletFeaturePromoCodeFromUser(any())).thenAnswer((inv) {
      final enabled = inv.positionalArguments.first as bool;
      if (promoCentral) return;
      storedPromo = enabled;
    });
    when(() => repo.walletFeatureReferral = any()).thenAnswer((inv) {
      final value = inv.positionalArguments.first as bool;
      if (value) referralCentral = true;
      return value;
    });
    when(() => repo.setWalletFeatureReferralFromUser(any())).thenAnswer((inv) {
      final enabled = inv.positionalArguments.first as bool;
      if (referralCentral) return;
      storedReferral = enabled;
    });
  });

  SettingsBloc build() => SettingsBloc(
    repo,
    () async {
      authRefreshCount++;
    },
  );

  group('$SettingsBloc', () {
    test('initial state reads from the repository', () {
      when(() => repo.language).thenReturn('de');
      when(() => repo.currency).thenReturn('EUR');
      when(() => repo.networkMode).thenReturn(NetworkMode.testnet);
      when(() => repo.insiderFeaturesUnlocked).thenReturn(true);

      final bloc = build();

      expect(bloc.state.language, Language.de);
      expect(bloc.state.currency, Currency.eur);
      expect(bloc.state.networkMode, NetworkMode.testnet);
      expect(bloc.state.hideAmounts, isFalse);
      expect(bloc.state.insiderFeaturesUnlocked, isTrue);
      expect(bloc.state.networkOptionsEnabled, isFalse);
      expect(bloc.state.walletFeaturePay, isFalse);
      expect(bloc.state.walletFeatureSend, isFalse);
      expect(bloc.state.walletFeaturePromoCode, isFalse);
      expect(bloc.state.walletFeatureReferral, isFalse);
    });

    blocTest<SettingsBloc, SettingsState>(
      'SetLanguageEvent writes to the repo and emits the new language',
      build: build,
      act: (bloc) => bloc.add(const SetLanguageEvent(Language.de)),
      verify: (bloc) {
        expect(bloc.state.language, Language.de);
        verify(() => repo.language = 'de').called(1);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetCurrencyEvent writes to the repo and emits the new currency',
      build: build,
      act: (bloc) => bloc.add(const SetCurrencyEvent(Currency.eur)),
      verify: (bloc) {
        expect(bloc.state.currency, Currency.eur);
        verify(() => repo.currency = 'EUR').called(1);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'ApplyAccountCurrencyEvent emits the account currency when nothing is stored',
      build: build,
      act: (bloc) => bloc.add(const ApplyAccountCurrencyEvent(Currency.chf)),
      expect: () => [
        isA<SettingsState>().having((s) => s.currency, 'currency', Currency.chf),
      ],
      verify: (bloc) {
        verifyNever(() => repo.currency = any());
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'ApplyAccountCurrencyEvent is ignored when the user already stored a currency',
      build: build,
      setUp: () => when(() => repo.hasStoredCurrency).thenReturn(true),
      act: (bloc) => bloc.add(const ApplyAccountCurrencyEvent(Currency.chf)),
      expect: () => <SettingsState>[],
    );

    blocTest<SettingsBloc, SettingsState>(
      'ClearAccountCurrencyEvent restores the unset default when nothing is stored',
      build: build,
      seed: () => const SettingsState(currency: Currency.chf),
      act: (bloc) => bloc.add(const ClearAccountCurrencyEvent()),
      expect: () => [
        isA<SettingsState>().having((s) => s.currency, 'currency', Currency.eur),
      ],
      verify: (bloc) {
        verifyNever(() => repo.currency = any());
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'ClearAccountCurrencyEvent is ignored when the user already stored a currency',
      build: build,
      setUp: () => when(() => repo.hasStoredCurrency).thenReturn(true),
      seed: () => const SettingsState(currency: Currency.chf),
      act: (bloc) => bloc.add(const ClearAccountCurrencyEvent()),
      expect: () => <SettingsState>[],
    );

    test('SetNetworkModeEvent writes the new mode, refreshes auth, and emits', () async {
      final bloc = build();

      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      await bloc.stream.firstWhere((s) => s.networkMode == NetworkMode.testnet);

      expect(bloc.state.networkMode, NetworkMode.testnet);
      expect(authRefreshCount, 1);
      verify(() => repo.networkMode = NetworkMode.testnet).called(1);
    });

    test('SetNetworkModeEvent leaves networkOptionsEnabled true', () async {
      when(() => repo.networkOptionsEnabled).thenReturn(true);
      final bloc = build();

      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      await bloc.stream.firstWhere((s) => s.networkMode == NetworkMode.testnet);

      expect(bloc.state.networkOptionsEnabled, isTrue);
    });

    test('SetNetworkModeEvent invokes onNetworkModeChanged after auth refresh', () async {
      final callOrder = <String>[];
      final bloc = SettingsBloc(
        repo,
        () async {
          callOrder.add('auth');
        },
        onNetworkModeChanged: () => callOrder.add('invalidate'),
      );

      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      await bloc.stream.firstWhere((s) => s.networkMode == NetworkMode.testnet);

      // Reference-data invalidation must happen after the auth refresh so
      // the next fetch hits the new backend with the new token.
      expect(callOrder, ['auth', 'invalidate']);
    });

    test('SetNetworkModeEvent emits feature flags re-read after the mode is persisted', () async {
      when(() => repo.networkMode = NetworkMode.testnet).thenAnswer((_) {
        storedPay = true;
        storedSend = true;
        storedPromo = false;
        storedReferral = true;
        return NetworkMode.testnet;
      });

      final bloc = build();
      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      await bloc.stream.firstWhere((s) => s.networkMode == NetworkMode.testnet);

      expect(bloc.state.walletFeaturePay, isTrue);
      expect(bloc.state.walletFeatureSend, isTrue);
      expect(bloc.state.walletFeaturePromoCode, isFalse);
      expect(bloc.state.walletFeatureReferral, isTrue);
    });

    test('SetNetworkModeEvent refreshes wallet features from the new host', () async {
      var fetchCount = 0;
      final bloc = SettingsBloc(
        repo,
        () async {
          authRefreshCount++;
        },
        fetchWalletFeatures: () async {
          fetchCount++;
          return const RealUnitWalletFeaturesDto();
        },
      );

      await bloc.stream.first;
      expect(fetchCount, 1);

      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      await bloc.stream.firstWhere((s) => s.networkMode == NetworkMode.testnet);
      await bloc.stream.first;
      expect(fetchCount, 2);
    });

    test('SetNetworkModeEvent of the current mode is a no-op', () async {
      var invalidated = false;
      final bloc = SettingsBloc(
        repo,
        () async {
          authRefreshCount++;
        },
        onNetworkModeChanged: () => invalidated = true,
      );

      bloc.add(const SetNetworkModeEvent(NetworkMode.mainnet));
      await Future<void>.delayed(Duration.zero);

      expect(authRefreshCount, 0);
      expect(invalidated, isFalse);
      verifyNever(() => repo.networkMode = NetworkMode.mainnet);
      verifyNever(() => repo.networkMode = NetworkMode.testnet);
    });

    test('SetNetworkModeEvent rolls the mode back when auth refresh fails', () async {
      var invalidated = false;
      final bloc = SettingsBloc(
        repo,
        () async {
          throw StateError('cancelled');
        },
        onNetworkModeChanged: () => invalidated = true,
      );

      final pending = bloc.stream.first;
      bloc.add(const SetNetworkModeEvent(NetworkMode.testnet));
      final emitted = await pending;

      expect(bloc.state.networkMode, NetworkMode.mainnet);
      expect(emitted.networkMode, NetworkMode.mainnet);
      expect(invalidated, isFalse);
      verifyInOrder([
        () => repo.networkMode = NetworkMode.testnet,
        () => repo.networkMode = NetworkMode.mainnet,
      ]);
    });

    blocTest<SettingsBloc, SettingsState>(
      'ToggleHideAmountEvent flips hideAmounts each time',
      build: build,
      act: (bloc) {
        bloc.add(const ToggleHideAmountEvent());
        bloc.add(const ToggleHideAmountEvent());
      },
      verify: (bloc) {
        expect(bloc.state.hideAmounts, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'a single ToggleHideAmountEvent sets hideAmounts=true',
      build: build,
      act: (bloc) => bloc.add(const ToggleHideAmountEvent()),
      verify: (bloc) {
        expect(bloc.state.hideAmounts, isTrue);
      },
    );

    // hideAmounts is intentionally session-only (SettingsRepository has no field for it).
    test('ToggleHideAmountEvent flips state without persisting (session-only by design)', () async {
      final bloc = build();

      bloc.add(const ToggleHideAmountEvent());
      await bloc.stream.firstWhere((s) => s.hideAmounts == true);

      expect(bloc.state.hideAmounts, isTrue);
      verifyNever(() => repo.language = any()); // proxy: no repo call at all
    });

    blocTest<SettingsBloc, SettingsState>(
      'UnlockInsiderFeaturesEvent persists insider unlock and all four feature flags',
      build: build,
      act: (bloc) => bloc.add(const UnlockInsiderFeaturesEvent()),
      verify: (bloc) {
        expect(bloc.state.insiderFeaturesUnlocked, isTrue);
        expect(bloc.state.networkOptionsEnabled, isFalse);
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.walletFeatureSend, isTrue);
        expect(bloc.state.walletFeaturePromoCode, isTrue);
        expect(bloc.state.walletFeatureReferral, isTrue);
        verify(() => repo.insiderFeaturesUnlocked = true).called(1);
        verify(() => repo.setWalletFeaturePayFromUser(true)).called(1);
        verify(() => repo.setWalletFeatureSendFromUser(true)).called(1);
        verify(() => repo.setWalletFeaturePromoCodeFromUser(true)).called(1);
        verify(() => repo.setWalletFeatureReferralFromUser(true)).called(1);
        verifyNever(() => repo.networkOptionsEnabled = any());
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'RefreshWalletFeaturesEvent OR-latches true flags from fetch',
      build: () {
        var calls = 0;
        return SettingsBloc(
          repo,
          () async {},
          fetchWalletFeatures: () async {
            calls++;
            if (calls == 1) {
              return const RealUnitWalletFeaturesDto(pay: true);
            }
            return const RealUnitWalletFeaturesDto(pay: false, send: true);
          },
        );
      },
      act: (bloc) => bloc.add(const RefreshWalletFeaturesEvent()),
      verify: (bloc) {
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.walletFeatureSend, isTrue);
        expect(bloc.state.walletFeaturePromoCode, isFalse);
        expect(bloc.state.walletFeatureReferral, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'RefreshWalletFeaturesEvent catch keeps existing latch and does not emit an error',
      setUp: () => storedPay = true,
      build: () => SettingsBloc(
        repo,
        () async {},
        fetchWalletFeatures: () async {
          throw Exception('unavailable');
        },
      ),
      expect: () => <SettingsState>[],
      verify: (bloc) {
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.walletFeatureSend, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'RefreshWalletFeaturesEvent turns the feature on when the server sends true',
      setUp: () {
        storedPay = false;
        payCentral = false;
      },
      build: () => SettingsBloc(
        repo,
        () async {},
        fetchWalletFeatures: () async => const RealUnitWalletFeaturesDto(pay: true),
      ),
      act: (bloc) => bloc.add(const RefreshWalletFeaturesEvent()),
      verify: (bloc) {
        verify(() => repo.walletFeaturePay = true).called(2);
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.walletFeaturePayCentral, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.pay false leaves pay on when central is true',
      setUp: () {
        payCentral = true;
      },
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, false)),
      verify: (bloc) {
        verify(() => repo.setWalletFeaturePayFromUser(false)).called(1);
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.walletFeaturePayCentral, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.networkOptions true persists via the setter and shows on state',
      setUp: () {
        when(() => repo.networkOptionsEnabled = any()).thenAnswer((inv) {
          final value = inv.positionalArguments.first as bool;
          when(() => repo.networkOptionsEnabled).thenReturn(value);
          return value;
        });
      },
      build: build,
      act: (bloc) => bloc.add(
        const SetInsiderFeatureEnabledEvent(InsiderFeature.networkOptions, true),
      ),
      verify: (bloc) {
        verify(() => repo.networkOptionsEnabled = true).called(1);
        expect(bloc.state.networkOptionsEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.networkOptions false persists via the setter and shows on state',
      setUp: () {
        when(() => repo.networkOptionsEnabled).thenReturn(true);
        when(() => repo.networkOptionsEnabled = any()).thenAnswer((inv) {
          final value = inv.positionalArguments.first as bool;
          when(() => repo.networkOptionsEnabled).thenReturn(value);
          return value;
        });
      },
      build: build,
      act: (bloc) => bloc.add(
        const SetInsiderFeatureEnabledEvent(InsiderFeature.networkOptions, false),
      ),
      verify: (bloc) {
        verify(() => repo.networkOptionsEnabled = false).called(1);
        expect(bloc.state.networkOptionsEnabled, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.pay turns on walletFeaturePay',
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, true)),
      verify: (bloc) {
        verify(() => repo.setWalletFeaturePayFromUser(true)).called(1);
        expect(bloc.state.walletFeaturePay, isTrue);
        expect(bloc.state.insiderPayEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.send turns on walletFeatureSend',
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.send, true)),
      verify: (bloc) {
        verify(() => repo.setWalletFeatureSendFromUser(true)).called(1);
        expect(bloc.state.walletFeatureSend, isTrue);
        expect(bloc.state.insiderSendEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.referral turns on walletFeatureReferral',
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.referral, true)),
      verify: (bloc) {
        verify(() => repo.setWalletFeatureReferralFromUser(true)).called(1);
        expect(bloc.state.walletFeatureReferral, isTrue);
        expect(bloc.state.insiderReferralEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.bonus turns on walletFeaturePromoCode',
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.bonus, true)),
      verify: (bloc) {
        verify(() => repo.setWalletFeaturePromoCodeFromUser(true)).called(1);
        expect(bloc.state.walletFeaturePromoCode, isTrue);
        expect(bloc.state.insiderBonusEnabled, isTrue);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.pay false turns walletFeaturePay off',
      setUp: () => storedPay = true,
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.pay, false)),
      verify: (bloc) {
        verify(() => repo.setWalletFeaturePayFromUser(false)).called(1);
        expect(bloc.state.walletFeaturePay, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.send false turns walletFeatureSend off',
      setUp: () => storedSend = true,
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.send, false)),
      verify: (bloc) {
        verify(() => repo.setWalletFeatureSendFromUser(false)).called(1);
        expect(bloc.state.walletFeatureSend, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.referral false turns walletFeatureReferral off',
      setUp: () => storedReferral = true,
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.referral, false)),
      verify: (bloc) {
        verify(() => repo.setWalletFeatureReferralFromUser(false)).called(1);
        expect(bloc.state.walletFeatureReferral, isFalse);
      },
    );

    blocTest<SettingsBloc, SettingsState>(
      'SetInsiderFeatureEnabledEvent.bonus false turns walletFeaturePromoCode off',
      setUp: () => storedPromo = true,
      build: build,
      act: (bloc) => bloc.add(const SetInsiderFeatureEnabledEvent(InsiderFeature.bonus, false)),
      verify: (bloc) {
        verify(() => repo.setWalletFeaturePromoCodeFromUser(false)).called(1);
        expect(bloc.state.walletFeaturePromoCode, isFalse);
      },
    );
  });
}
