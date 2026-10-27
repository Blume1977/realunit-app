import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/styles/colors.dart';

const String _libertyFixture = 'test/goldens/screens/pay/fixtures/pay_locations_liberty.png';

Uint8List? _libertyBytes;
MemoryImage? _libertyImage;

MemoryImage _libertyProvider() {
  final bytes = _libertyBytes ??= File(_libertyFixture).readAsBytesSync();
  return _libertyImage ??= MemoryImage(bytes);
}

/// Street-map stand-in for widget tests. A platform view cannot host MapLibre,
/// so the golden draws the same Liberty snapshot on the country camera.
class PayLocationsTestMap extends StatelessWidget {
  const PayLocationsTestMap({super.key, required this.pins, required this.selected});

  final List<PayLocationPin> pins;
  final PayLocationPin? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final townStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: RealUnitColors.neutral900,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1,
    );
    final countStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: RealUnitColors.basic.white,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const ColoredBox(color: RealUnitColors.brand200);
        }
        final view = payLocationCountryView(width: width, height: height);
        final markers = payLocationMarkers(visible: pins, selected: selected, zoom: view.zoom);
        const west = payLocationLibertyWest;
        const north = payLocationLibertyNorth;
        const east = payLocationLibertyEast;
        const south = payLocationLibertySouth;
        final topLeft = _project(north, west, view, width, height);
        final bottomRight = _project(south, east, view, width, height);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: RealUnitColors.brand200),
              Positioned(
                left: topLeft.dx,
                top: topLeft.dy,
                width: bottomRight.dx - topLeft.dx,
                height: bottomRight.dy - topLeft.dy,
                child: Image(
                  image: _libertyProvider(),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
              CustomPaint(
                painter: _PayLocationsMarkerPainter(
                  view: view,
                  width: width,
                  height: height,
                  markers: markers,
                  townStyle: townStyle,
                  countStyle: countStyle,
                ),
                child: const SizedBox.expand(),
              ),
              const Positioned(right: 4, bottom: 4, child: _LibertyCredit()),
            ],
          ),
        );
      },
    );
  }
}

Offset _project(double lat, double lon, PayLocationCountryView view, double width, double height) {
  final point = payLocationMapPoint(
    lat: lat,
    lon: lon,
    zoom: view.zoom,
    centerLat: view.centerLat,
    centerLon: view.centerLon,
    width: width,
    height: height,
  );
  return Offset(point.x, point.y);
}

class _LibertyCredit extends StatelessWidget {
  const _LibertyCredit();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RealUnitColors.basic.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'OpenFreeMap © OpenMapTiles © OpenStreetMap',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: RealUnitColors.neutral900,
            fontSize: 9,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _PayLocationsMarkerPainter extends CustomPainter {
  _PayLocationsMarkerPainter({
    required this.view,
    required this.width,
    required this.height,
    required this.markers,
    required this.townStyle,
    required this.countStyle,
  });

  final PayLocationCountryView view;
  final double width;
  final double height;
  final List<PayLocationMarker> markers;
  final TextStyle townStyle;
  final TextStyle countStyle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final marker in markers) {
      _paintMarker(canvas, marker);
    }
    for (final marker in markers) {
      if (marker.count != null) {
        _paintCount(canvas, marker);
      }
    }
    for (final marker in markers) {
      final town = marker.town;
      if (town != null) {
        _paintTown(canvas, marker, town);
      }
    }
  }

  void _paintMarker(Canvas canvas, PayLocationMarker marker) {
    final center = _at(marker.lat, marker.lon);
    final fillRadius = marker.diameter / 2 - marker.strokeWidth;
    canvas.drawCircle(center, fillRadius, Paint()..color = _hex(marker.color));
    canvas.drawCircle(
      center,
      fillRadius + marker.strokeWidth / 2,
      Paint()
        ..color = RealUnitColors.basic.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = marker.strokeWidth,
    );
  }

  void _paintCount(Canvas canvas, PayLocationMarker marker) {
    final center = _at(marker.lat, marker.lon);
    final text = TextPainter(
      text: TextSpan(text: '${marker.count}', style: countStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  void _paintTown(Canvas canvas, PayLocationMarker marker, String town) {
    final center = _at(marker.lat, marker.lon);
    final text = TextPainter(
      text: TextSpan(text: town, style: townStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);
    const padH = 8.0;
    const padV = 3.0;
    final plateWidth = text.width + padH * 2;
    final plateHeight = text.height + padV * 2;
    final top = center.dy - marker.diameter / 2 - 4 - plateHeight;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - plateWidth / 2, top, plateWidth, plateHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = RealUnitColors.basic.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = RealUnitColors.neutral200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    text.paint(canvas, Offset(rect.left + padH, rect.top + padV));
  }

  Offset _at(double lat, double lon) => _project(lat, lon, view, width, height);

  Color _hex(String hex) => payLocationPaintForHex(hex);

  @override
  bool shouldRepaint(covariant _PayLocationsMarkerPainter oldDelegate) {
    return oldDelegate.view.zoom != view.zoom ||
        oldDelegate.width != width ||
        oldDelegate.height != height ||
        !_sameMarkers(oldDelegate.markers, markers);
  }

  bool _sameMarkers(List<PayLocationMarker> previous, List<PayLocationMarker> next) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final left = previous[index];
      final right = next[index];
      if (left.kind != right.kind ||
          left.lat != right.lat ||
          left.lon != right.lon ||
          left.diameter != right.diameter ||
          left.strokeWidth != right.strokeWidth ||
          left.color != right.color ||
          left.count != right.count ||
          left.town != right.town ||
          left.pins.length != right.pins.length) {
        return false;
      }
    }
    return true;
  }
}
