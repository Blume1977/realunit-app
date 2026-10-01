import 'package:flutter/material.dart';
import 'package:realunit_wallet/widgets/image_source_sheet.dart';

import '../../../helper/helper.dart';

void main() {
  goldenTest(
    'camera and library tiles',
    fileName: 'image_source_sheet',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      const Scaffold(
        backgroundColor: Colors.black54,
        bottomSheet: ImageSourceSheet(),
      ),
    ),
  );
}
