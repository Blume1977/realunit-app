import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/pay/pay_info_page.dart';

import '../../../helper/helper.dart';

void main() {
  late MockHomeBloc homeBloc;

  setUp(() {
    homeBloc = MockHomeBloc();
    when(() => homeBloc.state).thenReturn(
      HomeState(
        hasWallet: true,
        openWallet: SoftwareViewWallet(
          1,
          'Software',
          '0x0000000000000000000000000000000000000001',
        ),
      ),
    );
  });

  goldenTest(
    'pay info disclosure',
    fileName: 'pay_info_page',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      BlocProvider<HomeBloc>.value(value: homeBloc, child: const PayInfoPage()),
    ),
  );
}
