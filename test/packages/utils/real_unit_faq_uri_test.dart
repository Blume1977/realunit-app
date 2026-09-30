import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/utils/real_unit_faq_uri.dart';

void main() {
  group('realUnitFaqUri', () {
    const swiss = 'https://realunit.ch/wissen/faq-haeufige-fragen-zum-realunit/';
    const german = 'https://realunit.de/wissen/faq-haeufige-fragen-zum-realunit/';

    test('null uses realunit.ch', () {
      expect(realUnitFaqUri(null), Uri.parse(swiss));
    });

    test('blank uses realunit.ch', () {
      expect(realUnitFaqUri(''), Uri.parse(swiss));
      expect(realUnitFaqUri('  '), Uri.parse(swiss));
    });

    test('CH uses realunit.ch', () {
      expect(realUnitFaqUri('CH'), Uri.parse(swiss));
    });

    test('DE uses realunit.de', () {
      expect(realUnitFaqUri('DE'), Uri.parse(german));
    });

    test('FR uses realunit.de', () {
      expect(realUnitFaqUri('FR'), Uri.parse(german));
    });

    test('fragment faqaia on CH', () {
      expect(
        realUnitFaqUri('CH', fragment: 'faqaia'),
        Uri.parse(
          'https://realunit.ch/wissen/faq-haeufige-fragen-zum-realunit/#faqaia',
        ),
      );
    });
  });
}
