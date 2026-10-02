import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/models/balance.dart';
import 'package:realunit_wallet/packages/utils/default_assets.dart';
import 'package:realunit_wallet/screens/sell/cubits/sell_balance/sell_balance_cubit.dart';
import 'package:realunit_wallet/screens/send/cubits/send_amount/send_amount_cubit.dart';
import 'package:realunit_wallet/screens/send/cubits/send_process/send_process_cubit.dart';
import 'package:realunit_wallet/screens/send/cubits/send_recipient/send_recipient_cubit.dart';
import 'package:realunit_wallet/screens/send/send_amount_page.dart';
import 'package:realunit_wallet/screens/send/send_confirm_page.dart';
import 'package:realunit_wallet/screens/send/send_info_page.dart';
import 'package:realunit_wallet/screens/send/send_process_page.dart';
import 'package:realunit_wallet/screens/send/send_recipient_page.dart';

import '../../../helper/helper.dart';

class _MockSendRecipientCubit extends MockCubit<SendRecipientState> implements SendRecipientCubit {}

class _MockSellBalanceCubit extends MockCubit<Balance> implements SellBalanceCubit {}

class _MockSendAmountCubit extends MockCubit<SendAmountState> implements SendAmountCubit {}

class _MockSendProcessCubit extends MockCubit<SendProcessState> implements SendProcessCubit {}

Balance _balance(int shares) => Balance(
  chainId: realUnitAsset.chainId,
  contractAddress: realUnitAsset.address,
  walletAddress: '0xwallet',
  balance: BigInt.from(shares),
  asset: realUnitAsset,
);

void main() {
  setUpAll(() {
    registerFallbackValue(BigInt.zero);
    stubMobileScannerChannel();
  });

  group('$SendInfoPage', () {
    goldenTest(
      'shareholder transfer disclosure',
      fileName: 'send_info_page',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(const SendInfoPage()),
    );
  });

  group('$SendRecipientView', () {
    late _MockSendRecipientCubit recipientCubit;

    setUp(() {
      recipientCubit = _MockSendRecipientCubit();
      when(() => recipientCubit.state).thenReturn(const SendRecipientEmpty());
    });

    goldenTest(
      'scan + manual-entry state',
      fileName: 'send_recipient_page_empty',
      constraints: phoneConstraints,
      // The camera preview never reaches an isInitialized frame headlessly, so
      // pumpAndSettle would await a settle that never comes. pumpOnce captures
      // the deterministic placeholder frame.
      pumpBeforeTest: pumpOnce,
      builder: () => wrapForGolden(
        BlocProvider<SendRecipientCubit>.value(
          value: recipientCubit,
          child: const SendRecipientView(),
        ),
      ),
    );
  });

  group('$SendAmountView', () {
    late _MockSellBalanceCubit balanceCubit;
    late _MockSendAmountCubit amountCubit;

    setUp(() {
      balanceCubit = _MockSellBalanceCubit();
      amountCubit = _MockSendAmountCubit();
      when(() => balanceCubit.state).thenReturn(_balance(42));
      when(() => amountCubit.availableShares).thenReturn(BigInt.from(42));
      when(() => amountCubit.availableSharesChanged(any())).thenReturn(null);
      when(() => amountCubit.state).thenReturn(const SendAmountState());
    });

    goldenTest(
      'amount entry with available balance',
      fileName: 'send_amount_page_empty',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
            BlocProvider<SendAmountCubit>.value(value: amountCubit),
          ],
          child: const SendAmountView(recipient: '0xRecipient'),
        ),
      ),
    );

    goldenTest(
      'available after Kauf — 85194',
      fileName: 'send_holding_kauf',
      constraints: phoneConstraints,
      builder: () {
        when(() => balanceCubit.state).thenReturn(_balance(85194));
        when(() => amountCubit.availableShares).thenReturn(BigInt.from(85194));
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
              BlocProvider<SendAmountCubit>.value(value: amountCubit),
            ],
            child: const SendAmountView(recipient: '0xRecipient'),
          ),
        );
      },
    );

    goldenTest(
      'available after on-chain transferOut — 85094',
      fileName: 'send_holding_transfer_out',
      constraints: phoneConstraints,
      builder: () {
        when(() => balanceCubit.state).thenReturn(_balance(85094));
        when(() => amountCubit.availableShares).thenReturn(BigInt.from(85094));
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
              BlocProvider<SendAmountCubit>.value(value: amountCubit),
            ],
            child: const SendAmountView(recipient: '0xRecipient'),
          ),
        );
      },
    );

    goldenTest(
      'available after on-chain transferIn — 78094',
      fileName: 'send_holding_transfer_in',
      constraints: phoneConstraints,
      builder: () {
        when(() => balanceCubit.state).thenReturn(_balance(78094));
        when(() => amountCubit.availableShares).thenReturn(BigInt.from(78094));
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
              BlocProvider<SendAmountCubit>.value(value: amountCubit),
            ],
            child: const SendAmountView(recipient: '0xRecipient'),
          ),
        );
      },
    );

    goldenTest(
      'over-balance amount shows the insufficient error',
      fileName: 'send_amount_page_insufficient',
      constraints: phoneConstraints,
      builder: () {
        when(() => amountCubit.state).thenReturn(
          const SendAmountState(
            text: '99',
            amount: 99,
            status: SendAmountStatus.insufficientBalance,
          ),
        );
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<SellBalanceCubit>.value(value: balanceCubit),
              BlocProvider<SendAmountCubit>.value(value: amountCubit),
            ],
            child: const SendAmountView(recipient: '0xRecipient'),
          ),
        );
      },
    );
  });

  group('$SendConfirmPage', () {
    goldenTest(
      'transfer summary',
      fileName: 'send_confirm_page',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(
        const SendConfirmPage(
          recipient: '0x9F5713DEacB8e9CAB6c2d3FaE1AFc2715F8D2D71',
          amount: 5,
        ),
      ),
    );
  });

  group('$SendProcessView', () {
    late _MockSendProcessCubit processCubit;

    setUp(() {
      processCubit = _MockSendProcessCubit();
      when(() => processCubit.state).thenReturn(const SendProcessInitial());
    });

    // Success and the older failure reasons stay in the widget test: the sheet
    // is a modal from the listener, not the build tree. The unregistered
    // recipient wording is its own surface and has a baseline below.
    goldenTest(
      'in-progress signing state',
      fileName: 'send_process_page_signing',
      constraints: phoneConstraints,
      // The CupertinoActivityIndicator animates forever; pumpOnce captures the
      // first frame.
      pumpBeforeTest: pumpOnce,
      builder: () {
        when(() => processCubit.state).thenReturn(const SendProcessSigning());
        return wrapForGolden(
          BlocProvider<SendProcessCubit>.value(
            value: processCubit,
            child: const SendProcessView(),
          ),
        );
      },
    );

    goldenTest(
      'unregistered recipient failure sheet',
      fileName: 'send_process_recipient_not_registered',
      constraints: phoneConstraints,
      // The page behind the sheet keeps a CupertinoActivityIndicator spinning,
      // so pumpAndSettle never returns. Fixed pumps open the modal the same
      // way the responsive matrix test does.
      pumpBeforeTest: (tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
      builder: () {
        whenListen(
          processCubit,
          Stream<SendProcessState>.value(
            const SendProcessFailure(
              SendProcessFailureReason.recipientNotRegistered,
              message: 'Recipient is not a registered RealUnit shareholder',
            ),
          ),
          initialState: const SendProcessSigning(),
        );
        return wrapForGolden(
          BlocProvider<SendProcessCubit>.value(
            value: processCubit,
            child: const SendProcessView(),
          ),
        );
      },
    );
  });
}
