import 'package:flutter/material.dart';
import 'package:realunit_wallet/screens/pay/widgets/pay_flow_sheet.dart';

import '../../../helper/helper.dart';

void main() {
  goldenTest(
    'payment flow explanation sheet from the scanner',
    fileName: 'pay_flow_sheet',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      const Scaffold(
        backgroundColor: Colors.black54,
        bottomSheet: PayFlowSheet(),
      ),
    ),
  );
}
