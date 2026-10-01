import 'package:flutter/material.dart';
import 'package:realunit_wallet/styles/colors.dart';

class WebViewScaffold extends StatelessWidget {
  final String title;
  final bool showExternalBrowserButton;
  final VoidCallback onBack;
  final VoidCallback onOpenExternal;
  final Widget body;

  const WebViewScaffold({
    super.key,
    required this.title,
    required this.showExternalBrowserButton,
    required this.onBack,
    required this.onOpenExternal,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: RealUnitColors.realUnitBlack,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: RealUnitColors.realUnitBlack,
          fontWeight: .w700,
        ),
      ),
      actions: [
        if (showExternalBrowserButton)
          IconButton(
            onPressed: onOpenExternal,
            icon: const Icon(
              Icons.open_in_new_outlined,
              color: RealUnitColors.realUnitBlack,
              size: 24,
            ),
          ),
      ],
    ),
    body: body,
  );
}
