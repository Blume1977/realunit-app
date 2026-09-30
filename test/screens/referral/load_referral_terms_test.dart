import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/referral/load_referral_terms.dart';

void main() {
  test('loads the locale asset', () async {
    final paths = <String>[];
    final content = await loadReferralTermsMarkdown(
      languageCode: 'en',
      loadAsset: (path) async {
        paths.add(path);
        return '# EN TB';
      },
    );
    expect(content, '# EN TB');
    expect(paths, ['assets/legal/referral_terms_en.md']);
  });

  test('returns null when the locale asset is missing', () async {
    final paths = <String>[];
    final content = await loadReferralTermsMarkdown(
      languageCode: 'en',
      loadAsset: (path) async {
        paths.add(path);
        throw Exception('missing');
      },
    );
    expect(content, isNull);
    expect(paths, ['assets/legal/referral_terms_en.md']);
  });

  test('returns null when bundled assets are all empty or missing', () async {
    expect(
      await loadReferralTermsMarkdown(
        languageCode: 'en',
        loadAsset: (_) async => '   ',
      ),
      isNull,
    );
    expect(
      await loadReferralTermsMarkdown(
        languageCode: 'de',
        loadAsset: (_) async => throw Exception('missing'),
      ),
      isNull,
    );
  });

  test('bundled files are the 26.08 TB, not a paraphrase', () {
    final de = File('assets/legal/referral_terms_de.md').readAsStringSync();
    final en = File('assets/legal/referral_terms_en.md').readAsStringSync();

    expect(de, contains('im eigenen Wallet'));
    expect(de, contains('registriert und verifiziert'));
    expect(de, contains('noch nicht qualifizierte Einladungen'));
    expect(de, isNot(contains('verbundene Unternehmen')));

    expect(en, contains('own wallet'));
    expect(en, contains('have not yet qualified'));
    expect(de, contains('mindestens 70 RealUnit-Aktientoken im eigenen Wallet'));
    expect(de, contains('ersten Kauf über mindestens 200 RealUnit-Aktientoken'));
    expect(en, contains('at least 70 RealUnit share tokens in their own wallet'));
    expect(en, contains('first purchase of at least 200 RealUnit share tokens'));
  });
}
