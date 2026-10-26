import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/screens/sell_bitbox/cubit/sell_bitbox_cubit.dart';
import 'package:realunit_wallet/screens/sell_bitbox/sell_bitbox_page.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../helper/golden_mocks.dart';
import '../../helper/pump_app.dart';
import '../../helper/sell_bitbox_unsigned_txs.dart';

class _MockSellBitboxCubit extends MockCubit<SellBitboxState> implements SellBitboxCubit {}

SellPaymentInfo _paymentInfo() => SellPaymentInfo(
  id: 42,
  eip7702: Eip7702Data.fromJson(const {
    'relayerAddress': '',
    'delegationManagerAddress': '',
    'delegatorAddress': '',
    'userNonce': 0,
    'domain': {'name': '', 'version': '', 'chainId': 1, 'verifyingContract': ''},
    'types': {'Delegation': <Map<String, dynamic>>[], 'Caveat': <Map<String, dynamic>>[]},
    'message': {
      'delegate': '',
      'delegator': '',
      'authority': '',
      'caveats': <Map<String, dynamic>>[],
      'salt': 0,
    },
    'tokenAddress': '',
    'amountWei': '0',
    'depositAddress': '',
  }),
  amount: sellQuoteShares,
  exchangeRate: 1.0,
  rate: 1.0,
  beneficiary: const BeneficiaryDto(iban: 'CH...'),
  estimatedAmount: sellQuoteZchfAmount,
  currency: Currency.chf,
  depositAddress: sellQuoteDepositAddress,
  tokenAddress: sellQuoteRealuAddress,
  chainId: 1,
  ethBalance: 1.0,
  requiredGasEth: 0.001,
  zchfAmount: sellQuoteZchfAmount,
);

void main() {
  late _MockSellBitboxCubit cubit;
  late MockSettingsBloc settingsBloc;

  setUp(() {
    cubit = _MockSellBitboxCubit();
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(const SettingsState());
  });

  Future<void> pumpWithError(WidgetTester tester, SellBitboxError error) async {
    whenListen(
      cubit,
      Stream<SellBitboxState>.value(error),
      initialState: SellBitboxPreparingSwap(),
    );
    await tester.pumpApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<SellBitboxCubit>.value(value: cubit),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: SellBitboxView(paymentInfo: _paymentInfo()),
      ),
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('$SellBitboxView error snackbar', () {
    testWidgets('states that nothing was signed when the transactions do not match', (
      tester,
    ) async {
      await pumpWithError(
        tester,
        SellBitboxTransactionMismatch('swap recipient is not the brokerbot'),
      );

      expect(
        find.text(
          'These transactions do not match the sale you confirmed. Nothing was signed. '
          'Please start the sale again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('brokerbot'), findsNothing);
    });

    testWidgets('shows the error message for other errors', (tester) async {
      await pumpWithError(tester, SellBitboxError('network error'));

      expect(find.text('network error'), findsOneWidget);
    });
  });
}
