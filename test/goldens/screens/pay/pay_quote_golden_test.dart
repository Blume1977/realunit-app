import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/pay/swap_payment_info.dart';
import 'package:realunit_wallet/screens/pay/cubits/pay_quote/pay_quote_cubit.dart';
import 'package:realunit_wallet/screens/pay/pay_quote_page.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

import '../../../helper/helper.dart';

class _MockPayQuoteCubit extends MockCubit<PayQuoteState> implements PayQuoteCubit {}

// One REALU pays 1.20 CHF. The bill is 2.00 CHF (1.66666667 REALU) and the
// fee is 0.05 CHF (0.04166667 REALU). One share does not cover 2.05 CHF, so
// the quote sells 2 shares for 2.40 CHF.
final _now = DateTime.utc(2026, 1, 1);
final _expiresAt = DateTime.utc(2026, 1, 1, 0, 5);

/// The countdown reads `clock.now()` when the view mounts, which is during
/// pump, not while the golden builder runs. Pin the clock around that pump
/// or the January expiry is already in the past and the shot shows "expired".
Future<void> _pumpPinned(WidgetTester tester, Widget widget) {
  return withClock(Clock.fixed(_now), () => tester.pumpWidget(widget));
}

const _swap = SwapPaymentInfo(
  id: 99,
  amount: 2,
  estimatedAmount: 2.4,
  targetAsset: 'ZCHF',
  ethBalance: 1,
  requiredGasEth: 0.001,
  isValid: true,
  ethereumTransactionFeeChf: 0.05,
  ethereumTransactionFeeRealu: 0.05 / 1.2,
);

void main() {
  late _MockPayQuoteCubit quoteCubit;

  setUp(() {
    quoteCubit = _MockPayQuoteCubit();
    when(() => quoteCubit.state).thenReturn(const PayQuoteLoading());
  });

  // PayQuotePage resolves its cubit from getIt and calls load(); the golden
  // renders PayQuoteView directly with a mocked cubit so every state is
  // deterministic without the service/DI graph.
  group('$PayQuoteView', () {
    goldenTest(
      'loading state',
      fileName: 'pay_quote_page_loading',
      constraints: phoneConstraints,
      // The CupertinoActivityIndicator animates forever, so pumpAndSettle
      // would time out; pumpOnce captures the first frame.
      pumpBeforeTest: pumpOnce,
      builder: () => wrapForGolden(
        BlocProvider<PayQuoteCubit>.value(
          value: quoteCubit,
          child: const PayQuoteView(),
        ),
      ),
    );

    // Bill 2.00 CHF. CHF needed on screen is that bill plus the 0.05 fee.
    goldenTest(
      'ready quote with recipient, countdown and REALU total',
      fileName: 'pay_quote_page_ready',
      constraints: phoneConstraints,
      pumpBeforeTest: pumpOnce,
      pumpWidget: _pumpPinned,
      builder: () {
        when(() => quoteCubit.state).thenReturn(
          PayQuoteReady(
            paymentLinkId: 'pl_realunit_ocp_sepolia',
            quoteId: 'plq_realunit_ocp_sepolia',
            fiatAsset: 'CHF',
            fiatAmount: 2,
            zchfAmount: 2.0,
            merchantName: 'Café Zürich',
            merchantCity: 'Zürich',
            expiresAt: _expiresAt,
            swap: _swap,
          ),
        );
        final settingsBloc = MockSettingsBloc();
        when(() => settingsBloc.state).thenReturn(const SettingsState());
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsBloc>.value(value: settingsBloc),
              BlocProvider<PayQuoteCubit>.value(value: quoteCubit),
            ],
            child: const PayQuoteView(),
          ),
        );
      },
    );

    goldenTest(
      'ready quote with merchant and REALU swap details',
      fileName: 'pay_quote_page_ready_with_merchant',
      constraints: phoneConstraints,
      pumpBeforeTest: pumpOnce,
      pumpWidget: _pumpPinned,
      builder: () {
        when(() => quoteCubit.state).thenReturn(
          PayQuoteReady(
            paymentLinkId: 'pl_realunit_ocp_sepolia',
            quoteId: 'plq_realunit_ocp_sepolia',
            fiatAsset: 'CHF',
            fiatAmount: 2,
            zchfAmount: 2.0,
            merchantName: 'Café Zürich',
            merchantCity: 'Zürich',
            expiresAt: _expiresAt,
            swap: _swap,
          ),
        );
        final settingsBloc = MockSettingsBloc();
        when(() => settingsBloc.state).thenReturn(const SettingsState());
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsBloc>.value(value: settingsBloc),
              BlocProvider<PayQuoteCubit>.value(value: quoteCubit),
            ],
            child: const PayQuoteView(),
          ),
        );
      },
    );

    // EUR selected and the quote stored a EUR receipt: fee, rounding, and
    // total show that receipt. The requested row keeps the CHF amount the
    // till asked for and adds the stored EUR amount beside it.
    goldenTest(
      'ready quote shows the stored EUR receipt when EUR is selected',
      fileName: 'pay_quote_page_ready_eur',
      constraints: phoneConstraints,
      pumpBeforeTest: pumpOnce,
      pumpWidget: _pumpPinned,
      builder: () {
        when(() => quoteCubit.state).thenReturn(
          PayQuoteReady(
            paymentLinkId: 'pl_realunit_ocp_sepolia',
            quoteId: 'plq_realunit_ocp_sepolia',
            fiatAsset: 'CHF',
            fiatAmount: 2,
            zchfAmount: 2.0,
            merchantName: 'Café Zürich',
            merchantCity: 'Zürich',
            expiresAt: _expiresAt,
            swap: _swap,
            billEur: 1.84,
            feeEur: 0.04,
            roundingEur: 0.28,
            totalEur: 2.16,
          ),
        );
        final settingsBloc = MockSettingsBloc();
        const settingsState = SettingsState(
          language: Language.de,
          currency: Currency.eur,
        );
        when(() => settingsBloc.state).thenReturn(settingsState);
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsBloc>.value(value: settingsBloc),
              BlocProvider<PayQuoteCubit>.value(value: quoteCubit),
            ],
            child: const PayQuoteView(),
          ),
        );
      },
    );

    goldenTest(
      'expired quote message',
      fileName: 'pay_quote_page_expired',
      constraints: phoneConstraints,
      builder: () {
        when(() => quoteCubit.state).thenReturn(const PayQuoteExpired());
        return wrapForGolden(
          BlocProvider<PayQuoteCubit>.value(
            value: quoteCubit,
            child: const PayQuoteView(),
          ),
        );
      },
    );
  });
}
