import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/broadcast_transaction_request_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/real_unit_sell_payment_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/sell_payment_info.dart';
import 'package:realunit_wallet/screens/sell_bitbox/cubit/sell_bitbox_cubit.dart';
import 'package:realunit_wallet/screens/sell_bitbox/widgets/sell_bitbox_deposit_step.dart';
import 'package:realunit_wallet/screens/sell_bitbox/widgets/sell_bitbox_swap_step.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';

import '../../../helper/helper.dart';

class _MockSellBitboxCubit extends MockCubit<SellBitboxState>
    implements SellBitboxCubit {}

Map<String, dynamic> _eip7702Json() => {
      'relayerAddress': '0xrelay',
      'delegationManagerAddress': '0xmgr',
      'delegatorAddress': '0xdr',
      'userNonce': 7,
      'domain': {
        'name': 'RealUnit',
        'version': '1',
        'chainId': 1,
        'verifyingContract': '0xverify',
      },
      'types': {'Delegation': <Map<String, dynamic>>[], 'Caveat': <Map<String, dynamic>>[]},
      'message': {
        'delegate': '0xd',
        'delegator': '0xdr',
        'authority': '0xauth',
        'caveats': <Map<String, dynamic>>[],
        'salt': 0,
      },
      'tokenAddress': '0xtoken',
      'amountWei': '12345',
      'depositAddress': '0xdeposit_full_address_with_long_string',
    };

SellPaymentInfo _info() => SellPaymentInfo(
      id: 42,
      eip7702: Eip7702Data.fromJson(_eip7702Json()),
      amount: 100,
      exchangeRate: 1.0,
      rate: 1.0,
      beneficiary: const BeneficiaryDto(iban: 'CH...'),
      estimatedAmount: 99.5,
      currency: Currency.chf,
      depositAddress: '0xdeposit_full_address_with_long_string',
      tokenAddress: '0xtoken',
      chainId: 1,
      ethBalance: 0.1,
      requiredGasEth: 0.001,
    );

Widget _hostSwap(SellBitboxCubit cubit, SellPaymentInfo info) {
  final settings = MockSettingsBloc();
  when(() => settings.state).thenReturn(const SettingsState());
  return MultiBlocProvider(
    providers: [
      BlocProvider<SellBitboxCubit>.value(value: cubit),
      BlocProvider<SettingsBloc>.value(value: settings),
    ],
    child: SellBitboxSwapStep(paymentInfo: info),
  );
}

Widget _hostDeposit(SellBitboxCubit cubit, SellPaymentInfo info) {
  final settings = MockSettingsBloc();
  when(() => settings.state).thenReturn(const SettingsState());
  return MultiBlocProvider(
    providers: [
      BlocProvider<SellBitboxCubit>.value(value: cubit),
      BlocProvider<SettingsBloc>.value(value: settings),
    ],
    child: SellBitboxDepositStep(paymentInfo: info),
  );
}

void main() {
  late _MockSellBitboxCubit cubit;

  setUp(() {
    cubit = _MockSellBitboxCubit();
  });

  group('$SellBitboxSwapStep', () {
    testWidgets('Preparing: shows a CupertinoActivityIndicator', (tester) async {
      when(() => cubit.state).thenReturn(SellBitboxPreparingSwap());

      await tester.pumpApp(_hostSwap(cubit, _info()));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('AwaitingSwapConfirm: shows the amount + REALU symbol',
        (tester) async {
      when(() => cubit.state).thenReturn(
        SellBitboxAwaitingSwapConfirm('0xswap', '0xdeposit'),
      );

      await tester.pumpApp(_hostSwap(cubit, _info()));

      // realUnitAsset.symbol is 'REALU' — appears in the From row "<amount> REALU".
      expect(find.text('100 REALU'), findsOneWidget);
      // estimatedAmount is 99.5 → formatted "≈ 99.50 ZCHF".
      expect(find.text('≈ 99.50 ZCHF'), findsOneWidget);
    });
  });

  group('$SellBitboxDepositStep', () {
    testWidgets('AwaitingDepositConfirm: shows ZCHF amount + truncated deposit address',
        (tester) async {
      // Bigger viewport so the test row doesn't overflow horizontally.
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => cubit.state).thenReturn(
        SellBitboxAwaitingDepositConfirm(
          const BroadcastTransactionRequestDto(
            unsignedTx: '0xtx', r: '0xr', s: '0xs', v: 27,
          ),
          '0xdeposit',
        ),
      );

      await tester.pumpApp(_hostDeposit(cubit, _info()));

      // estimatedAmount=99.5 → 99.50 ZCHF on the "From" row.
      expect(find.text('99.50 ZCHF'), findsOneWidget);
      // Address truncation: first 6 chars + '…' + last 4 chars.
      // '0xdeposit_full_address_with_long_string' → '0xdepo…ring'.
      expect(find.text('0xdepo…ring'), findsOneWidget);
    });

    testWidgets('Depositing: shows a CupertinoActivityIndicator', (tester) async {
      when(() => cubit.state).thenReturn(SellBitboxDepositing());

      await tester.pumpApp(_hostDeposit(cubit, _info()));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });
}
