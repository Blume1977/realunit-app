import 'package:flutter/material.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:realunit_wallet/screens/web_view/web_view_scaffold.dart';

class WebViewRouteParams {
  final String title;
  final Uri url;
  final bool showExternalBrowserButton;

  const WebViewRouteParams({
    required this.title,
    required this.url,
    this.showExternalBrowserButton = false,
  });
}

class WebViewPage extends StatelessWidget {
  WebViewPage(WebViewRouteParams params, {super.key})
    : _title = params.title,
      _url = params.url,
      _showExternalBrowserButton = params.showExternalBrowserButton;

  final String _title;
  final Uri _url;
  final bool _showExternalBrowserButton;

  @override
  Widget build(BuildContext context) => WebViewScaffold(
    title: _title,
    showExternalBrowserButton: _showExternalBrowserButton,
    onBack: () => context.pop(),
    onOpenExternal: () => launchUrl(_url, mode: LaunchMode.externalApplication),
    body: WebViewPageBody(uri: _url),
  );
}

class WebViewPageBody extends StatelessWidget {
  const WebViewPageBody({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) => InAppWebView(
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      javaScriptEnabled: false,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      allowFileAccess: false,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
    ),
    initialUrlRequest: URLRequest(
      url: WebUri.uri(uri),
    ),
  );
}
