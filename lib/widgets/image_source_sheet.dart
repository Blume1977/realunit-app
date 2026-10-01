import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';

class ImageSourceSheet extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onLibrary;

  const ImageSourceSheet({
    super.key,
    this.onCamera,
    this.onLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const .all(8.0),
        child: Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(S.of(context).choosePhoto),
              onTap: onCamera,
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(S.of(context).choosePhotoLibrary),
              onTap: onLibrary,
            ),
          ],
        ),
      ),
    );
  }
}
