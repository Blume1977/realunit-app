import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_invite_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_summary_dto.dart';
import 'package:realunit_wallet/screens/referral/cubit/referral_cubit.dart';
import 'package:realunit_wallet/screens/referral/referral_overview_page.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';
import 'package:realunit_wallet/styles/currency.dart';
import 'package:realunit_wallet/styles/language.dart';

import '../../../helper/helper.dart';
import '../../../helper/referral_share_text_fixture.dart';

class _MockReferralCubit extends MockCubit<ReferralState> implements ReferralCubit {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState> implements SettingsBloc {}

void main() {
  late _MockReferralCubit cubit;
  late _MockSettingsBloc settings;

  setUp(() {
    cubit = _MockReferralCubit();
    settings = _MockSettingsBloc();
    const settingsState = SettingsState(language: Language.de);
    when(() => settings.state).thenReturn(settingsState);
    whenListen(
      settings,
      const Stream<SettingsState>.empty(),
      initialState: settingsState,
    );
  });

  void useSettings(SettingsState settingsState) {
    when(() => settings.state).thenReturn(settingsState);
    whenListen(
      settings,
      const Stream<SettingsState>.empty(),
      initialState: settingsState,
    );
  }

  Widget buildOverview(ReferralState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<ReferralState>.empty(), initialState: state);
    return wrapForGolden(
      MultiBlocProvider(
        providers: [
          BlocProvider<ReferralCubit>.value(value: cubit),
          BlocProvider<SettingsBloc>.value(value: settings),
        ],
        child: const ReferralOverviewPage(),
      ),
    );
  }

  group('$ReferralOverviewPage', () {
    goldenTest(
      'overview with open invite, Aktienkurs tile',
      fileName: 'referral_overview_page_default',
      constraints: phoneConstraints,
      builder: () {
        const summary = ReferralSummaryDto(
          eligible: true,
          termsAccepted: true,
          minHolding: 70,
          openCount: 1,
          creditedCount: 2,
          realuSum: 40,
          chfSum: 512.4,
          sharePriceLabel: 'Aktienkurs',
          sharePrice: 1.38,
        );
        final invites = [
          ReferralInviteDto(
            id: 1,
            code: 'AB12CD',
            url: 'https://realunit.app/invite/AB12CD',
            guestName: 'Alice',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: personalShareTextAlice,
          ),
        ];
        return buildOverview(
          ReferralOverviewLoaded(summary: summary, invites: invites),
        );
      },
    );

    goldenTest(
      'overview with open impersonal invite',
      fileName: 'referral_overview_page_impersonal',
      constraints: phoneConstraints,
      builder: () {
        const summary = ReferralSummaryDto(
          eligible: true,
          termsAccepted: true,
          minHolding: 70,
          openCount: 1,
          creditedCount: 2,
          realuSum: 40,
          chfSum: 512.4,
          sharePriceLabel: 'Aktienkurs',
          sharePrice: 1.38,
        );
        final invites = [
          ReferralInviteDto(
            id: 1,
            code: 'IMP1',
            url: 'https://realunit.app/invite/IMP1',
            guestName: 'Hidden',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            kind: 'Impersonal',
            prizeCount: 0,
          ),
        ];
        return buildOverview(
          ReferralOverviewLoaded(summary: summary, invites: invites),
        );
      },
    );

    goldenTest(
      'overview with one impersonal reward',
      fileName: 'referral_overview_page_impersonal_one',
      constraints: phoneConstraints,
      builder: () {
        const summary = ReferralSummaryDto(
          eligible: true,
          termsAccepted: true,
          minHolding: 70,
          openCount: 1,
          creditedCount: 2,
          realuSum: 40,
          chfSum: 512.4,
          sharePriceLabel: 'Aktienkurs',
          sharePrice: 1.38,
        );
        final invites = [
          ReferralInviteDto(
            id: 1,
            code: 'IMP1',
            url: 'https://realunit.app/invite/IMP1',
            guestName: 'Hidden',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            kind: 'Impersonal',
            prizeCount: 1,
          ),
        ];
        return buildOverview(
          ReferralOverviewLoaded(summary: summary, invites: invites),
        );
      },
    );

    goldenTest(
      'empty overview with zero counts',
      fileName: 'referral_overview_page_empty',
      constraints: phoneConstraints,
      builder: () {
        const summary = ReferralSummaryDto(
          eligible: true,
          termsAccepted: true,
          minHolding: 70,
          openCount: 0,
          creditedCount: 0,
          realuSum: 0,
          chfSum: 0,
        );
        return buildOverview(
          const ReferralOverviewLoaded(summary: summary, invites: []),
        );
      },
    );

    // 40 shares at a stored share price of 1.27 EUR is 50.80 EUR.
    goldenTest(
      'overview tile shows the stored EUR amount when EUR is selected',
      fileName: 'referral_overview_page_eur',
      constraints: phoneConstraints,
      builder: () {
        useSettings(
          const SettingsState(language: Language.de, currency: Currency.eur),
        );
        const summary = ReferralSummaryDto(
          eligible: true,
          termsAccepted: true,
          minHolding: 70,
          openCount: 1,
          creditedCount: 2,
          realuSum: 40,
          chfSum: 512.4,
          eurSum: 470.2,
          sharePriceLabel: 'Aktienkurs',
          sharePrice: 1.38,
          sharePriceEur: 1.27,
        );
        return buildOverview(
          const ReferralOverviewLoaded(summary: summary, invites: []),
        );
      },
    );
  });
}
