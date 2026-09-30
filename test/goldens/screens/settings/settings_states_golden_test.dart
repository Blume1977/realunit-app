import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/settings/widgets/settings_confirm_logout_wallet_sheet.dart';

import '../../../helper/helper.dart';

void main() {
  // `settings_page_{default,bitbox}` and the unchecked
  // `settings_confirm_logout_wallet_sheet_default` live in
  // `settings_golden_test.dart` / `settings_confirm_logout_wallet_sheet_golden_test.dart`.
  //
  // Documented skip — Settings Network tile:
  // the Settings Network tile appears only when `networkOptionsEnabled` is true,
  // the remaining settings-page goldens leave that flag off, and
  // `settings_page_network_options_on` is the baseline that shows the row.
  //
  // Covered here: the confirm-logout sheet with the checkbox ticked, which
  // enables the Reset button (`isChecked ? … : null`,
  // settings_confirm_logout_wallet_sheet.dart:122).
  group('$SettingsConfirmLogoutWalletSheet', () {
    goldenTest(
      'checkbox checked — Reset button enabled',
      fileName: 'settings_confirm_logout_wallet_sheet_checked',
      constraints: phoneConstraints,
      // The whole row is one opaque GestureDetector (the inner Checkbox is
      // wrapped in AbsorbPointer), so a tap at the checkbox toggles `isChecked`
      // via the ancestor detector; pumpAndSettle finishes the check animation.
      pumpBeforeTest: (tester) async {
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
      },
      builder: () => wrapForGolden(
        const Scaffold(
          backgroundColor: Colors.black54,
          bottomSheet: SettingsConfirmLogoutWalletSheet(),
        ),
      ),
    );
  });
}
