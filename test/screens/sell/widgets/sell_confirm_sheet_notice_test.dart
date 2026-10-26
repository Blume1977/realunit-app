import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_confirm/sell_confirm_cubit.dart';
import 'package:realunit_wallet/screens/sell/widgets/sell_confirm_sheet.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../../helper/helper.dart';

class _MockSellConfirmCubit extends MockCubit<SellConfirmState> implements SellConfirmCubit {}

SellPaymentInfo _paymentInfo() => SellPaymentInfo(
  id: 42,
  eip7702: Eip7702Data.fromJson({
    'relayerAddress': '0xrelay',
    'delegationManagerAddress': '0xmgr',
    'delegatorAddress': '0xdr',
    'userNonce': 7,
    'domain': {
      'name': 'DelegationManager',
      'version': '1',
      'chainId': 1,
      'verifyingContract': '0xverify',
    },
    'types': {
      'Delegation': <Map<String, dynamic>>[],
      'Caveat': <Map<String, dynamic>>[],
    },
    'message': {
      'delegate': '0xd',
      'delegator': '0xdr',
      'authority': '0xauth',
      'caveats': <Map<String, dynamic>>[],
      'salt': 0,
    },
    'tokenAddress': '0xtoken',
    'amountWei': '12345',
    'depositAddress': '0xdeposit',
  }),
  amount: 100,
  exchangeRate: 1.0,
  rate: 1.0,
  beneficiary: const BeneficiaryDto(iban: 'CH9300762011623852957'),
  estimatedAmount: 100.0,
  currency: Currency.chf,
  depositAddress: '0xdeposit',
  tokenAddress: '0xtoken',
  chainId: 1,
  ethBalance: 1.0,
  requiredGasEth: 0.001,
);

void main() {
  late _MockSellConfirmCubit confirmCubit;
  late MockSettingsBloc settingsBloc;

  setUp(() {
    confirmCubit = _MockSellConfirmCubit();
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.state).thenReturn(const SettingsState());
  });

  Future<void> pumpSheet(WidgetTester tester, SellConfirmState state) async {
    whenListen(confirmCubit, Stream.value(state), initialState: SellConfirmLoading());
    await tester.pumpApp(
      Scaffold(
        bottomSheet: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<SellConfirmCubit>.value(value: confirmCubit),
          ],
          child: SellConfirmSheetView(paymentInfo: _paymentInfo()),
        ),
      ),
      locale: const Locale('en'),
    );
    await tester.pump();
  }

  testWidgets('shows why the sale was not sent for an envelope refusal, without a snackbar', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      SellConfirmEnvelopeRejected('DelegationEnvelopeMismatchException: test'),
    );

    expect(find.text('The sale was not sent.'), findsOneWidget);
    expect(
      find.text('The authorization is not in the format this app accepts.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('DelegationEnvelopeMismatchException'), findsNothing);
  });

  testWidgets('keeps the caveat refusal text for a caveat refusal', (tester) async {
    await pumpSheet(tester, SellConfirmFailure('Exception: EIP-7702 caveats: rejected'));

    expect(
      find.textContaining('does not match the confirmed amount'),
      findsOneWidget,
    );
    expect(find.textContaining('not in the format'), findsNothing);
  });
}
