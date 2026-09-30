import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/startup_failure/widgets/startup_failure_reset_sheet.dart';

import '../../../helper/helper.dart';

void main() {
  // Shown with showModalBottomSheet; the black scrim stands in for the dimmed
  // page.
  group('$StartupFailureResetSheet', () {
    goldenTest(
      'default state with unchecked confirmation',
      fileName: 'startup_failure_reset_sheet_default',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(
        const Scaffold(
          backgroundColor: Colors.black54,
          bottomSheet: StartupFailureResetSheet(),
        ),
      ),
    );
  });
}
