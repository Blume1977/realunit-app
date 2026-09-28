/// Share copy from the API when present; otherwise the localised template.
/// Empty `copyText` / `copyTextEn` must not hide the fallback.
/// `http://`, protocol-relative `//`, `www.realunit.app`, and scheme-less
/// `realunit.app/…` in the message are folded onto `https://realunit.app`
/// so the pasted Universal Link host matches Offerte Entwurf 3.
/// `dev.realunit.app` is left unchanged.
String referralShareText({
  required String? fromApi,
  required String guestName,
  required String code,
  required String url,
  required String Function(String guestName, String code, String url) fallback,
  required String Function(String code, String url) fallbackNoName,
}) {
  final name = guestName.trim();
  final text = (fromApi != null && fromApi.trim().isNotEmpty)
      ? fromApi.trim()
      : name.isEmpty
      ? fallbackNoName(code, url)
      : fallback(name, code, url);
  return text.replaceAllMapped(
    _apexInviteHost,
    (match) => '${match[1]}https://realunit.app',
  );
}

final _apexInviteHost = RegExp(
  r'(^|[^a-z0-9.-])(?:(?:https?:)?//)?(?:www\.)?realunit\.app(?=[/?#:]|$)',
  caseSensitive: false,
);
