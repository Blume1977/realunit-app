import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/models/registration/kyc/kyc_personal_data.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/real_unit_user_data_dto.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/kyc/cubits/kyc/kyc_cubit.dart';
import 'package:realunit_wallet/screens/kyc/steps/link_wallet/cubits/kyc_link_wallet_cubit.dart';
import 'package:realunit_wallet/screens/kyc/steps/link_wallet/kyc_link_wallet_page.dart';

import '../../../helper/helper.dart';

class _MockKycLinkWalletCubit extends MockCubit<KycLinkWalletState> implements KycLinkWalletCubit {}

class _MockKycCubit extends MockCubit<KycState> implements KycCubit {}

class _MockAppStore extends Mock implements AppStore {}

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
  addressStreet: 'Bahnhofstrasse 1',
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

  setUpAll(() {
    final getIt = GetIt.instance;
    final appStore = _MockAppStore();
    when(() => appStore.wallet).thenReturn(DebugWallet(1, 'Test', _debugAddress));
    getIt.registerSingleton<AppStore>(appStore);
  });

  tearDownAll(() async => await GetIt.instance.reset());

  setUp(() {
    linkCubit = _MockKycLinkWalletCubit();
    kycCubit = _MockKycCubit();
    when(() => kycCubit.state).thenReturn(const KycInitial());
  });

  group('$KycLinkWalletView', () {
    goldenTest(
      'ready with prior userData',
      fileName: 'kyc_link_wallet_page_default',
      constraints: phoneConstraints,
      builder: () {
        when(() => linkCubit.state).thenReturn(const KycLinkWalletReady(_userData));
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<KycCubit>.value(value: kycCubit),
              BlocProvider<KycLinkWalletCubit>.value(value: linkCubit),
            ],
            child: const KycLinkWalletView(),
          ),
        );
      },
    );

    // Locks the visual contract for the BitBox-required state: it must render
    // the idle confirm body (so dismissing the connect sheet lands the user
    // back on the submit button), never a spinner or error dead-end. The
    // connect sheet itself is baselined separately under hardware_connect_bitbox.
    goldenTest(
      'bitbox required renders the idle confirm body',
      fileName: 'kyc_link_wallet_page_bitbox_required',
      constraints: phoneConstraints,
      builder: () {
        when(() => linkCubit.state).thenReturn(const KycLinkWalletBitboxRequired(_userData));
        return wrapForGolden(
          MultiBlocProvider(
            providers: [
              BlocProvider<KycCubit>.value(value: kycCubit),
              BlocProvider<KycLinkWalletCubit>.value(value: linkCubit),
            ],
            child: const KycLinkWalletView(),
          ),
        );
      },
    );
  });
}
