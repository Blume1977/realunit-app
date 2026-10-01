import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/web_view/web_view_scaffold.dart';

import '../../../helper/helper.dart';

void main() {
  group('$WebViewScaffold', () {
    goldenTest(
      'app bar with title, no external browser button',
      fileName: 'web_view_chrome',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(
        WebViewScaffold(
          title: 'RealUnit',
          showExternalBrowserButton: false,
          onBack: () {},
          onOpenExternal: () {},
          body: const SizedBox.expand(),
        ),
      ),
    );

    goldenTest(
      'app bar with title and external browser button',
      fileName: 'web_view_chrome_external',
      constraints: phoneConstraints,
      builder: () => wrapForGolden(
        WebViewScaffold(
          title: 'RealUnit',
          showExternalBrowserButton: true,
          onBack: () {},
          onOpenExternal: () {},
          body: const SizedBox.expand(),
        ),
      ),
    );
  });
}
