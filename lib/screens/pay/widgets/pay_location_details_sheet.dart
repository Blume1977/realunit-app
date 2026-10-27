import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/styles/colors.dart';

Color _payLocationColor(String activity) => payLocationActivityPaint(activity);

String _payLocationActivityLabel(BuildContext context, String activity) {
  final strings = S.of(context);
  return switch (activity) {
    'daily' => strings.payLocationsActivityDaily,
    'within7Days' => strings.payLocationsActivityWeekly,
    'within30Days' => strings.payLocationsActivityMonthly,
    'olderThan30Days' => strings.payLocationsActivityIdle,
    _ => strings.payLocationsActivityNone,
  };
}

String _payLocationActivityHelp(BuildContext context, String activity) {
  final strings = S.of(context);
  return switch (activity) {
    'daily' => strings.payLocationsActivityDailyHelp,
    'within7Days' => strings.payLocationsActivityWeeklyHelp,
    'within30Days' => strings.payLocationsActivityMonthlyHelp,
    'olderThan30Days' => strings.payLocationsActivityIdleHelp,
    _ => strings.payLocationsActivityNoneHelp,
  };
}

class PayLocationActivityLine extends StatelessWidget {
  const PayLocationActivityLine({super.key, required this.pin});

  final PayLocationPin pin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _payLocationColor(pin.activity),
            shape: BoxShape.circle,
            border: Border.all(color: RealUnitColors.basic.black.withValues(alpha: 0.25)),
          ),
        ),
        Flexible(
          child: Text(
            _payLocationActivityLabel(context, pin.activity),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class PayLocationDetailsSheet extends StatelessWidget {
  const PayLocationDetailsSheet({
    super.key,
    required this.pinListenable,
    required this.loadPhotos,
    required this.loadBytes,
  });

  final ValueListenable<PayLocationPin?> pinListenable;
  final Future<List<PayLocationPhoto>> Function(PayLocationPin pin) loadPhotos;
  final Future<Uint8List?> Function(String url) loadBytes;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<PayLocationPin?>(
        valueListenable: pinListenable,
        builder: (context, pin, _) {
          if (pin == null) {
            return const SizedBox.shrink();
          }
          return Stack(
            children: [
              _PayLocationDetailsBody(
                key: ValueKey('${pin.id}:${pin.name}:${pin.lat}:${pin.lon}'),
                pin: pin,
                loadPhotos: loadPhotos,
                loadBytes: loadBytes,
              ),
              Positioned(
                top: 0,
                right: 8,
                child: IconButton(
                  tooltip: S.of(context).payLocationsDetailClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: RealUnitColors.basic.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayLocationDetailsBody extends StatefulWidget {
  const _PayLocationDetailsBody({
    super.key,
    required this.pin,
    required this.loadPhotos,
    required this.loadBytes,
  });

  final PayLocationPin pin;
  final Future<List<PayLocationPhoto>> Function(PayLocationPin pin) loadPhotos;
  final Future<Uint8List?> Function(String url) loadBytes;

  @override
  State<_PayLocationDetailsBody> createState() => _PayLocationDetailsBodyState();
}

class _PayLocationDetailsBodyState extends State<_PayLocationDetailsBody> {
  late final Future<List<PayLocationPhoto>> _photos;
  final Map<String, Uint8List> _photoBytes = {};
  final Set<String> _startedPhotos = {};
  final Set<String> _shownPhotos = {};
  final Set<String> _failedPhotos = {};
  final Set<String> _queuedPhotos = {};

  @override
  void initState() {
    super.initState();
    _photos = widget.loadPhotos(widget.pin);
  }

  void _ensurePhotoLoads(List<PayLocationPhoto> photos) {
    for (final photo in photos) {
      if (!_startedPhotos.add(photo.url)) {
        continue;
      }
      unawaited(_loadPhoto(photo.url));
    }
  }

  Future<void> _loadPhoto(String url) async {
    try {
      final bytes = await widget.loadBytes(url);
      if (!mounted || bytes == null || bytes.isEmpty) {
        return;
      }
      setState(() => _photoBytes[url] = bytes);
    } catch (_) {
      // A photo that never arrives is left out of the sheet.
    }
  }

  void _queuePhoto(String url, void Function() apply) {
    if (_queuedPhotos.contains(url) || _shownPhotos.contains(url) || _failedPhotos.contains(url)) {
      return;
    }
    _queuedPhotos.add(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedPhotos.remove(url);
      if (mounted) {
        apply();
      }
    });
  }

  void _showPhoto(String url) {
    _queuePhoto(url, () => setState(() => _shownPhotos.add(url)));
  }

  void _hidePhoto(String url) {
    _queuePhoto(url, () {
      setState(() {
        _failedPhotos.add(url);
        _shownPhotos.remove(url);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final category = pin.category;
    return FutureBuilder<List<PayLocationPhoto>>(
      future: _photos,
      builder: (context, snapshot) {
        final photos = _detailPhotos(pin.coverUrl, snapshot.data ?? const []);
        _ensurePhotoLoads(photos);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      for (final photo in photos)
                        if (_shownPhotos.contains(photo.url))
                          _PayLocationPhotoFrame(
                            bytes: _photoBytes[photo.url]!,
                            caption: photo.caption,
                          ),
                      Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Text(
                          pin.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              PayLocationActivityLine(pin: pin),
                              Text(
                                _payLocationActivityHelp(context, pin.activity),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          for (final line in payLocationAddressLines(pin))
                            Text(line, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      if (pin.description.isNotEmpty)
                        Text(pin.description, style: Theme.of(context).textTheme.bodyMedium),
                      if (category != null && category.isNotEmpty)
                        _PayLocationDetailValue(
                          label: S.of(context).payLocationsDetailCategory,
                          value: category,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      if (pin.shopType.isNotEmpty)
                        _PayLocationDetailValue(
                          label: S.of(context).payLocationsDetailShopType,
                          value: pin.shopType == 'Others'
                              ? S.of(context).payLocationsShopTypeOthers
                              : pin.shopType,
                        ),
                      if (pin.techProvider.isNotEmpty)
                        _PayLocationDetailValue(
                          label: S.of(context).payLocationsDetailProvider,
                          value: pin.techProvider,
                        ),
                      _PayLocationDetailValue(
                        label: S.of(context).payLocationsDetailPayment,
                        value: S.of(context).payLocationsDetailPaymentValue,
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 0,
                top: 0,
                child: IgnorePointer(
                  child: Opacity(opacity: 0, child: _photoProbes(photos)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _photoProbes(List<PayLocationPhoto> photos) {
    return Column(
      children: [
        for (final photo in photos)
          if (_photoBytes.containsKey(photo.url) &&
              !_shownPhotos.contains(photo.url) &&
              !_failedPhotos.contains(photo.url))
            Image.memory(
              _photoBytes[photo.url]!,
              width: 8,
              height: 8,
              frameBuilder: (context, child, frame, _) {
                if (frame != null) {
                  _showPhoto(photo.url);
                }
                return child;
              },
              errorBuilder: (_, _, _) {
                _hidePhoto(photo.url);
                return const SizedBox.shrink();
              },
            ),
      ],
    );
  }
}

List<PayLocationPhoto> _detailPhotos(
  String? coverUrl,
  List<PayLocationPhoto> detailPhotos,
) {
  final photos = <PayLocationPhoto>[];
  final indexes = <String, int>{};
  if (coverUrl != null) {
    indexes[coverUrl] = 0;
    photos.add(PayLocationPhoto(url: coverUrl));
  }
  for (final photo in detailPhotos) {
    final existing = indexes[photo.url];
    if (existing != null) {
      photos[existing] = photo;
      continue;
    }
    indexes[photo.url] = photos.length;
    photos.add(photo);
  }
  return photos;
}

class _PayLocationPhotoFrame extends StatelessWidget {
  const _PayLocationPhotoFrame({required this.bytes, required this.caption});

  final Uint8List bytes;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: double.infinity, height: 200, fit: BoxFit.cover),
        ),
        if (caption != null) Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PayLocationDetailValue extends StatelessWidget {
  const _PayLocationDetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
