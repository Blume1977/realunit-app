/// Website FAQ for a residence-country symbol.
/// `CH`, null, and blank use realunit.ch. Any other symbol uses realunit.de.
/// Both app locales use these German pages until an English FAQ exists.
/// [fragment] is `faqaia` for the automatic-exchange anchor, or null for the FAQ page.
Uri realUnitFaqUri(String? residenceCountrySymbol, {String? fragment}) {
  final symbol = residenceCountrySymbol?.trim();
  final base = (symbol == null || symbol.isEmpty || symbol == 'CH')
      ? 'https://realunit.ch/wissen/faq-haeufige-fragen-zum-realunit/'
      : 'https://realunit.de/wissen/faq-haeufige-fragen-zum-realunit/';
  return Uri.parse(fragment == null ? base : '$base#$fragment');
}
