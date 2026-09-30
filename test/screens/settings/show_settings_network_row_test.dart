import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/settings/settings_page.dart';

void main() {
  test('false hides, true shows', () {
    expect(
      showSettingsNetworkRow(networkOptionsEnabled: false),
      isFalse,
    );
    expect(
      showSettingsNetworkRow(networkOptionsEnabled: true),
      isTrue,
    );
  });
}
