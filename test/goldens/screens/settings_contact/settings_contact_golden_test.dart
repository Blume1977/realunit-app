import 'package:alchemist/alchemist.dart' as alchemist;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/screens/settings_contact/cubit/settings_contact_cubit.dart';
import 'package:realunit_wallet/screens/settings_contact/settings_contact_page.dart';

import '../../../helper/helper.dart';

class _MockSettingsContactCubit extends MockCubit<SettingsContactState>
    implements SettingsContactCubit {}

void main() {
  group('$SettingsContactPage', () {
    goldenTest(
      'default state (initial — no capability info yet)',
      fileName: 'settings_contact_page_default',
      constraints: phoneConstraints,
      pumpBeforeTest: (tester) async {
        await alchemist.precacheImages(tester);
        await tester.pumpAndSettle();
        expect(find.text('Kontakt / Support'), findsOneWidget);
        expect(find.text('Kontakt'), findsNothing);
      },
      builder: () {
        // Inject a mocked cubit so the page does not hit DI for
        // DfxKycService during the golden render. The page builds the
        // same tile-layout in Initial / Loading / Success(null) — the
        // visual surface that the golden pins is the static set of
        // tiles.
        final cubit = _MockSettingsContactCubit();
        when(() => cubit.state).thenReturn(const SettingsContactInitial());
        return wrapForGolden(
          BlocProvider<SettingsContactCubit>.value(
            value: cubit,
            child: const SettingsContactView(),
          ),
        );
      },
    );
  });
}
