import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/io/installer_package_port.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/packages/service/dfx/models/client_policy/real_unit_client_policy.dart';
import 'package:realunit_wallet/packages/utils/marketing_version.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:realunit_wallet/screens/home/bloc/home_bloc.dart';
import 'package:realunit_wallet/screens/update_required/bloc/client_policy_cubit.dart';
import 'package:realunit_wallet/screens/update_required/update_required_page.dart';
import 'package:realunit_wallet/setup/di.dart';

import '../../../helper/helper.dart';

class _MockClientPolicyCubit extends MockCubit<ClientPolicyState>
    implements ClientPolicyCubit {}

class _NullInstallerPackage implements InstallerPackagePort {
  const _NullInstallerPackage();

  @override
  Future<String?> readInstallerPackage() async => null;
}

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=swiss.realunit.app';

void main() {
  late _MockClientPolicyCubit clientPolicyCubit;
  late MockHomeBloc homeBloc;
  late MockAppStore appStore;

  setUpAll(() {
    appStore = MockAppStore();
    getIt.registerSingleton<AppStore>(appStore);
  });

  tearDownAll(() async => getIt.reset());

  setUp(() {
    homeBloc = MockHomeBloc();
    clientPolicyCubit = _MockClientPolicyCubit();
    when(() => appStore.isWalletLoaded).thenReturn(false);
  });

  void stubPolicy(RealUnitClientPolicy policy) {
    final loaded = ClientPolicyLoaded(policy);
    when(() => clientPolicyCubit.state).thenReturn(loaded);
    whenListen(
      clientPolicyCubit,
      const Stream<ClientPolicyState>.empty(),
      initialState: loaded,
    );
  }

  void stubHome(HomeState state) {
    when(() => homeBloc.state).thenReturn(state);
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: state,
    );
  }

  Widget buildSubject() => wrapForGolden(
        MultiBlocProvider(
          providers: [
            BlocProvider<ClientPolicyCubit>.value(value: clientPolicyCubit),
            BlocProvider<HomeBloc>.value(value: homeBloc),
          ],
          child: const UpdateRequiredPage(
            installerPackage: _NullInstallerPackage(),
          ),
        ),
      );

  group('$UpdateRequiredPage', () {
    goldenTest(
      'store link present, no wallet',
      fileName: 'update_required_page_ready',
      constraints: phoneConstraints,
      builder: () {
        stubPolicy(
          const RealUnitClientPolicy(
            severity: ClientPolicySeverity.hard,
            playStoreUrl: _playStoreUrl,
          ),
        );
        stubHome(const HomeState());
        return buildSubject();
      },
    );

    goldenTest(
      'no store link, no wallet',
      fileName: 'update_required_page_unavailable',
      constraints: phoneConstraints,
      builder: () {
        stubPolicy(
          const RealUnitClientPolicy(
            severity: ClientPolicySeverity.hard,
          ),
        );
        stubHome(const HomeState());
        return buildSubject();
      },
    );

    goldenTest(
      'store link and software wallet loaded',
      fileName: 'update_required_page_software_wallet',
      constraints: phoneConstraints,
      builder: () {
        final wallet = MockSoftwareWallet();
        when(() => appStore.isWalletLoaded).thenReturn(true);
        when(() => appStore.wallet).thenReturn(wallet);
        when(() => wallet.walletType).thenReturn(WalletType.software);
        stubPolicy(
          const RealUnitClientPolicy(
            severity: ClientPolicySeverity.hard,
            playStoreUrl: _playStoreUrl,
          ),
        );
        stubHome(const HomeState(hasWallet: true));
        return buildSubject();
      },
    );

    goldenTest(
      'store link and different github link, no wallet',
      fileName: 'update_required_page_github_secondary',
      constraints: phoneConstraints,
      builder: () {
        stubPolicy(
          const RealUnitClientPolicy(
            severity: ClientPolicySeverity.hard,
            playStoreUrl: _playStoreUrl,
            githubReleasesUrl: 'https://github.com/RealUnitCH/app/releases',
          ),
        );
        stubHome(const HomeState());
        return buildSubject();
      },
    );
  });
}
