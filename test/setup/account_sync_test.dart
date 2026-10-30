import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/models/kyc/kyc_level.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/setup/account_sync.dart';
import 'package:realunit_wallet/styles/currency.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState> implements SettingsBloc {}

class _MockKycService extends Mock implements DfxKycService {}

class _MockWallet extends Mock implements AWallet {}

UserDto _user({Currency? currency, bool? canPayWithRealUnit}) => UserDto(
  kyc: const UserKycDto(hash: 'h', level: KycLevel.level0, dataComplete: false),
  currency: currency,
  capabilities: UserCapabilitiesDto(canPayWithRealUnit: canPayWithRealUnit),
);

void main() {
  late _MockSettingsBloc settings;
  late _MockKycService kyc;
  late _MockWallet wallet;
  late AWallet? current;

  setUpAll(() {
    registerFallbackValue(const ApplyAccountCurrencyEvent(Currency.chf));
    registerFallbackValue(const ClearAccountCurrencyEvent());
  });

  setUp(() {
    settings = _MockSettingsBloc();
    kyc = _MockKycService();
    wallet = _MockWallet();
    current = wallet;
  });

  AccountSync build() => AccountSync(settings: settings, kyc: kyc, currentWallet: () => current);

  test(
    'onOpened applies GET /v2/user.currency when the wallet is still open',
    () async {
      when(
        () => kyc.getUser(),
      ).thenAnswer((_) async => _user(currency: Currency.chf));

      final sync = build();
      sync.onOpened(wallet);
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verify(
        () => settings.add(const ApplyAccountCurrencyEvent(Currency.chf)),
      ).called(1);
      verifyNever(() => settings.add(const ClearAccountCurrencyEvent()));
    },
  );

  test(
    'onOpened does not apply a currency when GET /v2/user has none',
    () async {
      when(() => kyc.getUser()).thenAnswer((_) async => _user());

      final sync = build();
      sync.onOpened(wallet);
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verifyNever(
        () => settings.add(any(that: isA<ApplyAccountCurrencyEvent>())),
      );
    },
  );

  group('retry', () {
    test('a failed GET /v2/user is retried after 2 s and 5 s, then given up', () {
      fakeAsync((async) {
        when(
          () => kyc.getUser(),
        ).thenAnswer((_) async => throw Exception('offline'));

        build().onOpened(wallet);
        async.flushMicrotasks();
        verify(() => kyc.getUser()).called(1);

        async.elapse(const Duration(milliseconds: 1999));
        verifyNever(() => kyc.getUser());
        async.elapse(const Duration(milliseconds: 1));
        verify(() => kyc.getUser()).called(1);

        async.elapse(const Duration(seconds: 5));
        verify(() => kyc.getUser()).called(1);

        async.elapse(const Duration(minutes: 1));
        verifyNever(() => kyc.getUser());
        verifyNever(() => settings.add(any()));
      });
    });

    test('a successful retry applies the account', () {
      fakeAsync((async) {
        var calls = 0;
        when(() => kyc.getUser()).thenAnswer((_) async {
          if (++calls == 1) throw Exception('offline');
          return _user(currency: Currency.chf, canPayWithRealUnit: true);
        });

        build().onOpened(wallet);
        async.elapse(const Duration(seconds: 2));

        verify(
          () => settings.add(const ApplyAccountCurrencyEvent(Currency.chf)),
        ).called(1);
        verify(
          () => settings.add(const ApplyAccountPayAccessEvent(true)),
        ).called(1);
      });
    });

    test('onClosed during the retry wait drops the retry', () {
      fakeAsync((async) {
        when(
          () => kyc.getUser(),
        ).thenAnswer((_) async => throw Exception('offline'));

        final sync = build();
        sync.onOpened(wallet);
        async.elapse(const Duration(seconds: 1));
        sync.onClosed();
        current = null;
        async.elapse(const Duration(minutes: 1));

        verify(() => kyc.getUser()).called(1);
        verifyNever(
          () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
        );
      });
    });

    test('onSwitched during the retry wait fetches only the new wallet', () {
      fakeAsync((async) {
        final other = _MockWallet();
        var calls = 0;
        when(() => kyc.getUser()).thenAnswer((_) async {
          if (++calls == 1) throw Exception('offline');
          return _user(currency: Currency.eur, canPayWithRealUnit: false);
        });

        final sync = build();
        sync.onOpened(wallet);
        async.elapse(const Duration(seconds: 1));
        current = other;
        sync.onSwitched(other);
        async.elapse(const Duration(minutes: 1));

        verify(() => kyc.getUser()).called(2);
        verify(
          () => settings.add(const ApplyAccountPayAccessEvent(false)),
        ).called(1);
      });
    });
  });

  group('pay access', () {
    test('onOpened applies canPayWithRealUnit true', () async {
      when(
        () => kyc.getUser(),
      ).thenAnswer((_) async => _user(canPayWithRealUnit: true));

      build().onOpened(wallet);
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verify(
        () => settings.add(const ApplyAccountPayAccessEvent(true)),
      ).called(1);
    });

    test('onOpened applies canPayWithRealUnit false', () async {
      when(
        () => kyc.getUser(),
      ).thenAnswer((_) async => _user(canPayWithRealUnit: false));

      build().onOpened(wallet);
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verify(
        () => settings.add(const ApplyAccountPayAccessEvent(false)),
      ).called(1);
    });

    test(
      'a backend without the capability does not gate pay (legacy fallback)',
      () async {
        when(() => kyc.getUser()).thenAnswer((_) async => _user());

        build().onOpened(wallet);
        await untilCalled(
          () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
        );

        verify(
          () => settings.add(const ApplyAccountPayAccessEvent(true)),
        ).called(1);
      },
    );
  });

  test('onClosed clears the unset account default and the pay access', () {
    build().onClosed();

    verifyInOrder([
      () => settings.add(const ClearAccountCurrencyEvent()),
      () => settings.add(const ClearAccountPayAccessEvent()),
    ]);
  });

  test('a late apply after onClosed is dropped', () async {
    final held = Completer<UserDto>();
    when(() => kyc.getUser()).thenAnswer((_) => held.future);

    final sync = build();
    sync.onOpened(wallet);
    sync.onClosed();
    current = null;
    held.complete(_user(currency: Currency.chf, canPayWithRealUnit: true));
    await Future<void>.delayed(Duration.zero);

    verify(() => settings.add(const ClearAccountCurrencyEvent())).called(1);
    verify(() => settings.add(const ClearAccountPayAccessEvent())).called(1);
    verifyNever(
      () => settings.add(any(that: isA<ApplyAccountCurrencyEvent>())),
    );
    verifyNever(
      () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
    );
  });

  test('onSwitched clears then applies the new wallet account', () async {
    final other = _MockWallet();
    when(() => kyc.getUser()).thenAnswer(
      (_) async => _user(currency: Currency.eur, canPayWithRealUnit: false),
    );

    final sync = build();
    current = other;
    sync.onSwitched(other);
    await untilCalled(
      () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
    );

    verifyInOrder([
      () => settings.add(const ClearAccountCurrencyEvent()),
      () => settings.add(const ClearAccountPayAccessEvent()),
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.eur)),
      () => settings.add(const ApplyAccountPayAccessEvent(false)),
    ]);
  });

  test('a late apply from wallet A is dropped after switch to B', () async {
    final held = Completer<UserDto>();
    when(() => kyc.getUser()).thenAnswer((_) => held.future);
    final other = _MockWallet();

    final sync = build();
    sync.onOpened(wallet);
    when(
      () => kyc.getUser(),
    ).thenAnswer((_) async => _user(currency: Currency.eur));
    current = other;
    sync.onSwitched(other);
    held.complete(_user(currency: Currency.chf, canPayWithRealUnit: false));
    await untilCalled(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.eur)),
    );

    verify(() => settings.add(const ClearAccountCurrencyEvent())).called(1);
    verifyNever(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.chf)),
    );
    verifyNever(() => settings.add(const ApplyAccountPayAccessEvent(false)));
    verify(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.eur)),
    ).called(1);
  });

  test('applyFromUser dispatches when captured is still the open wallet', () {
    build().applyFromUser(
      _user(currency: Currency.chf, canPayWithRealUnit: true),
      captured: wallet,
    );

    verify(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.chf)),
    ).called(1);
    verify(
      () => settings.add(const ApplyAccountPayAccessEvent(true)),
    ).called(1);
  });

  test('applyFromUser dispatches the pay access even without a currency', () {
    build().applyFromUser(_user(canPayWithRealUnit: false), captured: wallet);

    verifyNever(
      () => settings.add(any(that: isA<ApplyAccountCurrencyEvent>())),
    );
    verify(
      () => settings.add(const ApplyAccountPayAccessEvent(false)),
    ).called(1);
  });

  test('applyFromUser is ignored when captured is a different wallet', () {
    build().applyFromUser(
      _user(currency: Currency.chf),
      captured: _MockWallet(),
    );

    verifyNever(() => settings.add(any()));
  });

  test('applyFromUser drops an in-flight onOpened apply', () async {
    final held = Completer<UserDto>();
    when(() => kyc.getUser()).thenAnswer((_) => held.future);

    final sync = build();
    sync.onOpened(wallet);
    sync.applyFromUser(_user(currency: Currency.chf), captured: wallet);
    held.complete(_user(currency: Currency.eur));
    await Future<void>.delayed(Duration.zero);

    verify(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.chf)),
    ).called(1);
    verify(
      () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
    ).called(1);
    verifyNever(
      () => settings.add(const ApplyAccountCurrencyEvent(Currency.eur)),
    );
  });

  group('onResumed', () {
    test('fetches again while the pay access is unknown', () async {
      when(() => settings.state).thenReturn(const SettingsState());
      when(
        () => kyc.getUser(),
      ).thenAnswer((_) async => _user(canPayWithRealUnit: true));

      build().onResumed();
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verify(
        () => settings.add(const ApplyAccountPayAccessEvent(true)),
      ).called(1);
      verifyNever(() => settings.add(const ClearAccountPayAccessEvent()));
    });

    test('does nothing once the pay access is known', () {
      when(
        () => settings.state,
      ).thenReturn(const SettingsState(payAccess: AccountPayAccess.allowed));

      build().onResumed();

      verifyNever(() => kyc.getUser());
    });

    test('does nothing without an open wallet', () {
      when(() => settings.state).thenReturn(const SettingsState());
      current = null;

      build().onResumed();

      verifyNever(() => kyc.getUser());
    });

    test('does not start a second fetch while one is running', () async {
      when(() => settings.state).thenReturn(const SettingsState());
      final held = Completer<UserDto>();
      when(() => kyc.getUser()).thenAnswer((_) => held.future);

      final sync = build();
      sync.onOpened(wallet);
      sync.onResumed();
      held.complete(_user(canPayWithRealUnit: false));
      await untilCalled(
        () => settings.add(any(that: isA<ApplyAccountPayAccessEvent>())),
      );

      verify(() => kyc.getUser()).called(1);
    });
  });
}
