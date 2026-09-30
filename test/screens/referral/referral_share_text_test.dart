import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/referral/referral_share_text.dart';

void main() {
  String fallback(String guestName, String code, String url) =>
      'Hallo $guestName, Code $code: $url';
  String fallbackNoName(String code, String url) => 'Hallo, Code $code: $url';

  test('uses the API share text when present', () {
    expect(
      referralShareText(
        fromApi: 'Hey Alice, Björn lädt dich ein: https://realunit.app/invite/AB',
        guestName: 'Alice',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hey Alice, Björn lädt dich ein: https://realunit.app/invite/AB',
    );
  });

  test('folds www and http invite hosts onto the apex', () {
    expect(
      referralShareText(
        fromApi:
            'Hey Alice: https://www.realunit.app/invite/AB http://realunit.app/invite/AB //www.realunit.app/invite/AB',
        guestName: 'Alice',
        code: 'AB',
        url: 'https://www.realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hey Alice: https://realunit.app/invite/AB https://realunit.app/invite/AB https://realunit.app/invite/AB',
    );
    expect(
      referralShareText(
        fromApi: 'Dev: https://dev.realunit.app/invite/AB',
        guestName: 'Alice',
        code: 'AB',
        url: 'https://dev.realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Dev: https://dev.realunit.app/invite/AB',
    );
    expect(
      referralShareText(
        fromApi: 'Hey Alice: www.realunit.app/invite/AB realunit.app/invite/AB',
        guestName: 'Alice',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hey Alice: https://realunit.app/invite/AB https://realunit.app/invite/AB',
    );
  });

  test('leaves the prospectus hosts realunit.ch and realunit.de untouched', () {
    expect(
      referralShareText(
        fromApi: 'Unterlagen: realunit.ch/downloads | realunit.de/downloads',
        guestName: 'Alice',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Unterlagen: realunit.ch/downloads | realunit.de/downloads',
    );
  });

  test('falls back with the trimmed guest name and the code when the API text is blank', () {
    expect(
      referralShareText(
        fromApi: '  ',
        guestName: ' Alice ',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hallo Alice, Code AB: https://realunit.app/invite/AB',
    );
    expect(
      referralShareText(
        fromApi: null,
        guestName: 'Alice',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hallo Alice, Code AB: https://realunit.app/invite/AB',
    );
  });

  test('uses the nameless fallback when the guest name is blank', () {
    expect(
      referralShareText(
        fromApi: null,
        guestName: '  ',
        code: 'AB',
        url: 'https://realunit.app/invite/AB',
        fallback: fallback,
        fallbackNoName: fallbackNoName,
      ),
      'Hallo, Code AB: https://realunit.app/invite/AB',
    );
  });
}
