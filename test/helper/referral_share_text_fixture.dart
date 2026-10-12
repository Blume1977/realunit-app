/// Share text exactly as the API sends it (`RealUnitReferralDtoMapper.inviteShareText` in the
/// backend, wording approved by RealUnit legal on 28.09. and 30.09.2026, advertising note of
/// 12.10.2026), so the handbook screenshots of the invite screens show the text a customer
/// actually shares.
const _shareTextBody =
    'Kennst du die RealUnit App? Ich nutze RealUnit mit dem Ziel, mein Vermögen '
    'langfristig zu schützen. Mit dem Kauf von RealUnit-Aktientoken wirst du AktionärIn '
    'der RealUnit Schweiz AG, einer Schweizer Investmentgesellschaft, die u.a. in '
    'physisches Gold, Silber und Firmen investiert.';
const _shareTextNotice =
    'Dieser Inhalt ist Werbung. Die genehmigten Prospekte zur RealUnit Schweiz AG sind '
    'abrufbar unter: https://realunit.ch/downloads/ (Schweiz) | '
    'https://realunit.de/downloads/ (Deutschland/EU). Ihre Genehmigung ist keine '
    'Befürwortung der Wertpapiere. Anlegern wird empfohlen, vor einer Anlageentscheidung '
    'den Prospekt zu lesen, um Risiken und Chancen zu verstehen.';

/// Personal invite for Alice with code AB12CD.
const personalShareTextAlice =
    'Hallo Alice\n\n$_shareTextBody\n\n'
    'Gib bei der Registrierung meinen Code AB12CD ein oder benutze für den App-Download '
    'am einfachsten diesen Link: https://realunit.app/invite/AB12CD\n\n$_shareTextNotice';

/// Impersonal invite with code IMP1.
const impersonalShareTextImp1 =
    'Hallo\n\n$_shareTextBody\n\n'
    'Gib bei der Registrierung meinen Code IMP1 ein oder benutze für den App-Download '
    'am einfachsten diesen Link: https://realunit.app/invite/IMP1\n\n$_shareTextNotice';
