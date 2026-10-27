import 'dart:math' as math;
import 'dart:ui';

import 'package:realunit_wallet/styles/colors.dart';

const String payLocationsBlockchain = 'Ethereum';
const String payLocationsAsset = 'ZCHF';

const String payLocationsPlacesUrl =
    'https://api.opencryptopay.io/map/places?blockchain=Ethereum&asset=ZCHF';
const String payLocationsStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
String get payLocationClusterColor => payLocationHex(RealUnitColors.darkBlue);

const double payLocationCountrySouth = 45.83003;
const double payLocationCountryNorth = 47.77564;
const double payLocationCountryWest = 5.97002;
const double payLocationCountryEast = 10.45459;

/// MapLibre draws Liberty with 512px tiles. Zoom and the test map share that size.
const double _payLocationTileSize = 512;

/// Edges of the Liberty snapshot used by widget tests.
/// MapLibre unprojects its 1536×1792 zoom-7 canvas, with 512px tiles,
/// to these corners. The canvas is centred on 8.4375°E, 47.98992166741417°N.
const double payLocationLibertyWest = 4.21875;
const double payLocationLibertyEast = 12.65625;
const double payLocationLibertyNorth = 51.179342979289686;
const double payLocationLibertySouth = 44.59046718130912;

/// Country camera used by the street map after the style loads.
class PayLocationCountryView {
  final double zoom;
  final double centerLat;
  final double centerLon;

  const PayLocationCountryView({
    required this.zoom,
    required this.centerLat,
    required this.centerLon,
  });
}

PayLocationCountryView payLocationCountryView({
  required double width,
  required double height,
}) {
  return PayLocationCountryView(
    zoom: payLocationZoomForSpan(
      south: payLocationCountrySouth,
      north: payLocationCountryNorth,
      west: payLocationCountryWest,
      east: payLocationCountryEast,
      width: width,
      height: height,
      padding: 28,
      maxZoom: 16,
    ),
    centerLat: (payLocationCountrySouth + payLocationCountryNorth) / 2,
    centerLon: (payLocationCountryWest + payLocationCountryEast) / 2,
  );
}

/// Web Mercator point in a view whose centre is [centerLat], [centerLon].
class PayLocationMapPoint {
  final double x;
  final double y;

  const PayLocationMapPoint(this.x, this.y);
}

PayLocationMapPoint payLocationMapPoint({
  required double lat,
  required double lon,
  required double zoom,
  required double centerLat,
  required double centerLon,
  required double width,
  required double height,
}) {
  final world = _payLocationTileSize * math.pow(2, zoom);
  double xOf(double longitude) => (longitude + 180) / 360 * world;
  double yOf(double latitude) {
    final latRad = latitude * math.pi / 180;
    final mercator = math.log(math.tan(math.pi / 4 + latRad / 2));
    return (0.5 - mercator / (2 * math.pi)) * world;
  }

  return PayLocationMapPoint(
    width / 2 + (xOf(lon) - xOf(centerLon)),
    height / 2 + (yOf(lat) - yOf(centerLat)),
  );
}

class PayLocationPin {
  final String name;
  final String? category;
  final double lat;
  final double lon;
  final String? id;
  final String description;
  final String techProvider;
  final String shopType;
  final String street;
  final String houseNumber;
  final String postalCode;
  final String city;
  final String country;
  final String activity;
  final String? coverUrl;

  const PayLocationPin({
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    this.id,
    this.description = '',
    this.techProvider = '',
    this.shopType = '',
    this.street = '',
    this.houseNumber = '',
    this.postalCode = '',
    this.city = '',
    this.country = '',
    this.activity = 'none',
    this.coverUrl,
  });
}

class PayLocationPhoto {
  final String url;
  final String? caption;
  final double? width;
  final double? height;

  const PayLocationPhoto({
    required this.url,
    this.caption,
    this.width,
    this.height,
  });
}

Color payLocationActivityPaint(String activity) {
  return switch (activity) {
    'daily' => RealUnitColors.payActivityDaily,
    'within7Days' => RealUnitColors.payActivityWeekly,
    'within30Days' => RealUnitColors.payActivityMonthly,
    'olderThan30Days' => RealUnitColors.payActivityIdle,
    _ => RealUnitColors.payActivityNone,
  };
}

String payLocationActivityColor(String activity) {
  return payLocationHex(payLocationActivityPaint(activity));
}

/// `#RRGGBB` for MapLibre, taken from a palette color.
String payLocationHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Resolves a palette hex back to that color. Unknown values use the none swatch.
Color payLocationPaintForHex(String hex) {
  final normalized = hex.toUpperCase();
  const palette = <Color>[
    RealUnitColors.payActivityDaily,
    RealUnitColors.payActivityWeekly,
    RealUnitColors.payActivityMonthly,
    RealUnitColors.payActivityIdle,
    RealUnitColors.payActivityNone,
    RealUnitColors.darkBlue,
    RealUnitColors.neutral900,
  ];
  for (final color in palette) {
    if (payLocationHex(color) == normalized) {
      return color;
    }
  }
  if (payLocationHex(RealUnitColors.basic.white) == normalized) {
    return RealUnitColors.basic.white;
  }
  return RealUnitColors.payActivityNone;
}

bool payLocationsPlacesBodyIsList(Object? body) {
  return body is Map && body['places'] is List;
}

List<PayLocationPin> keepPayLocationPins(Object? body) {
  if (body is! Map) {
    return const [];
  }

  final places = body['places'];
  if (places is! List) {
    return const [];
  }

  final pins = <PayLocationPin>[];
  for (final place in places) {
    if (place is! Map) {
      continue;
    }

    final lat = _finiteDouble(place['lat']);
    final lon = _finiteDouble(place['lon']);
    if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      continue;
    }

    // The published list omits supports. Keep those places. A present
    // supports list must include ZCHF on Ethereum.
    final supports = place['supports'];
    if (supports != null &&
        (supports is! List ||
            !supports.any(
              (support) =>
                  support is Map &&
                  support['blockchain'] == payLocationsBlockchain &&
                  support['asset'] == payLocationsAsset,
            ))) {
      continue;
    }

    final name = place['name'];
    if (name is! String || name.trim().isEmpty) {
      continue;
    }
    final category = place['category'];
    final id = _nonEmptyString(place['id']);
    final activity = _payLocationActivity(place['activity']);
    final coverPhoto = place['coverPhoto'];
    final coverUrl = coverPhoto is Map ? payLocationPhotoUrl(coverPhoto['url']) : null;
    pins.add(
      PayLocationPin(
        name: name.trim(),
        category: category is String ? category.trim() : null,
        lat: lat,
        lon: lon,
        id: id,
        description: _trimmedString(place['description']),
        techProvider: _trimmedString(place['techProvider']),
        shopType: _trimmedString(place['shopType']),
        street: _trimmedString(place['street']),
        houseNumber: _trimmedString(place['houseNumber']),
        postalCode: _trimmedString(place['postalCode']),
        city: _trimmedString(place['city']),
        country: _trimmedString(place['country']),
        activity: activity,
        coverUrl: coverUrl,
      ),
    );
  }

  return pins;
}

class PayLocationCluster {
  final double lat;
  final double lon;
  final List<PayLocationPin> pins;

  const PayLocationCluster({required this.lat, required this.lon, required this.pins});

  bool get isSingle => pins.length == 1;
}

enum PayLocationMarkerKind { pin, cluster }

class PayLocationMarker {
  final PayLocationMarkerKind kind;
  final double lat;
  final double lon;
  final double diameter;
  final double strokeWidth;
  final String color;
  final int? count;
  final String? town;
  final List<PayLocationPin> pins;

  const PayLocationMarker({
    required this.kind,
    required this.lat,
    required this.lon,
    required this.diameter,
    required this.strokeWidth,
    required this.color,
    required this.pins,
    this.count,
    this.town,
  });
}

/// Cell size for a cluster spacing of about 64 pixels at [zoom].
double payLocationClusterCellDegrees(double zoom) {
  final worldPixels = _payLocationTileSize * math.pow(2, zoom);
  return 360 / worldPixels * 64;
}

List<PayLocationCluster> clusterPayLocationPins(
  List<PayLocationPin> pins, {
  required double cellDegrees,
}) {
  if (pins.isEmpty) {
    return const [];
  }
  if (cellDegrees <= 0) {
    return [
      for (final pin in pins) PayLocationCluster(lat: pin.lat, lon: pin.lon, pins: [pin]),
    ];
  }

  final groups = <String, List<PayLocationPin>>{};
  for (final pin in pins) {
    final key = '${(pin.lat / cellDegrees).floor()}:${(pin.lon / cellDegrees).floor()}';
    groups.putIfAbsent(key, () => []).add(pin);
  }

  return [
    for (final group in groups.values)
      PayLocationCluster(
        lat: group.fold<double>(0, (sum, pin) => sum + pin.lat) / group.length,
        lon: group.fold<double>(0, (sum, pin) => sum + pin.lon) / group.length,
        pins: group,
      ),
  ];
}

List<PayLocationMarker> payLocationMarkers({
  required List<PayLocationPin> visible,
  required PayLocationPin? selected,
  required double zoom,
}) {
  PayLocationPin? selectedPin;
  if (selected != null && visible.any((pin) => samePayLocationPin(pin, selected))) {
    selectedPin = selected;
  }
  final clustered = [
    for (final pin in visible)
      if (selectedPin == null || !samePayLocationPin(pin, selectedPin)) pin,
  ];
  final clusters = clusterPayLocationPins(
    clustered,
    cellDegrees: payLocationClusterCellDegrees(zoom),
  );
  final markers = <PayLocationMarker>[
    for (final cluster in clusters)
      if (cluster.isSingle)
        PayLocationMarker(
          kind: PayLocationMarkerKind.pin,
          lat: cluster.lat,
          lon: cluster.lon,
          diameter: 16,
          strokeWidth: 2,
          color: payLocationActivityColor(cluster.pins.single.activity),
          pins: cluster.pins,
          town: _payLocationMarkerTown(cluster.pins.single, zoom <= payLocationTownLabelMaxZoom),
        )
      else
        PayLocationMarker(
          kind: PayLocationMarkerKind.cluster,
          lat: cluster.lat,
          lon: cluster.lon,
          diameter: 34,
          strokeWidth: 2,
          color: payLocationClusterColor,
          pins: cluster.pins,
          count: cluster.pins.length,
        ),
  ];
  if (selectedPin != null) {
    markers.add(
      PayLocationMarker(
        kind: PayLocationMarkerKind.pin,
        lat: selectedPin.lat,
        lon: selectedPin.lon,
        diameter: 18,
        strokeWidth: 3,
        color: payLocationActivityColor(selectedPin.activity),
        pins: [selectedPin],
        town: _payLocationMarkerTown(selectedPin, true),
      ),
    );
  }
  return markers;
}

String? _payLocationMarkerTown(PayLocationPin pin, bool show) {
  if (!show) {
    return null;
  }
  final city = pin.city.trim();
  if (city.isNotEmpty) {
    return city;
  }
  final town = payLocationLabel(pin.name).town;
  return town.isEmpty ? null : town;
}

List<String> payLocationAddressLines(PayLocationPin pin) {
  return [
    _joinNonEmpty([pin.street, pin.houseNumber], ' '),
    _joinNonEmpty([pin.postalCode, pin.city], ' '),
    pin.country,
  ].where((line) => line.isNotEmpty).toList(growable: false);
}

final RegExp _payLocationDetailId = RegExp(r'^npub1[0-9a-z]+$');

String? payLocationDetailUrl(String? id) {
  if (id == null || !_payLocationDetailId.hasMatch(id)) {
    return null;
  }
  final parsed = Uri.https('api.opencryptopay.io', '/map/places/$id');
  if (parsed.userInfo.isNotEmpty ||
      parsed.host != 'api.opencryptopay.io' ||
      parsed.hasPort ||
      parsed.hasQuery ||
      parsed.hasFragment ||
      parsed.path != '/map/places/$id') {
    return null;
  }
  return parsed.toString();
}

List<PayLocationPhoto> payLocationPhotos(Object? body) {
  if (body is! Map) {
    return const [];
  }
  final place = body['place'];
  if (place is! Map) {
    return const [];
  }
  final photos = place['photos'];
  if (photos is! List) {
    return const [];
  }

  final result = <PayLocationPhoto>[];
  for (final photo in photos) {
    if (photo is! Map) {
      continue;
    }
    final url = payLocationPhotoUrl(photo['url']);
    if (url == null) {
      continue;
    }
    result.add(
      PayLocationPhoto(
        url: url,
        caption: _nonEmptyString(photo['caption']),
        width: _positiveFiniteDouble(photo['width']),
        height: _positiveFiniteDouble(photo['height']),
      ),
    );
  }
  return result;
}

double payLocationZoomForSpan({
  required double south,
  required double north,
  required double west,
  required double east,
  required double width,
  required double height,
  required double padding,
  required double maxZoom,
}) {
  final lonSpan = math.max((east - west).abs(), 1e-9);
  double mercatorY(double lat) {
    final latRad = lat * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + latRad / 2));
  }

  final ySpan = math.max((mercatorY(north) - mercatorY(south)).abs(), 1e-9);
  final usableW = math.max(width - 2 * padding, 1);
  final usableH = math.max(height - 2 * padding, 1);
  final zLon = math.log(usableW / _payLocationTileSize * 360 / lonSpan) / math.log(2);
  final zLat = math.log(usableH / _payLocationTileSize / (ySpan / (2 * math.pi))) / math.log(2);
  return math.min(zLon, zLat).clamp(5, maxZoom).toDouble();
}

enum PayLocationCameraKind { point, span }

class PayLocationZoomStep {
  const PayLocationZoomStep.point(this.lat, this.lon, this.zoom) : spanZoomDelta = null;

  const PayLocationZoomStep.span(this.spanZoomDelta) : lat = null, lon = null, zoom = null;

  final double? lat;
  final double? lon;
  final double? zoom;
  final double? spanZoomDelta;
}

/// Closest sample of one camera command. The commanded ride gets closer, so it
/// does not count as a move. A pan or pinch does, once the centre or the zoom
/// is worse than that closest sample by more than the tolerance.
class PayLocationCommandDrift {
  const PayLocationCommandDrift({
    this.bestCenterDistance,
    this.bestZoomError,
    this.left = false,
  });

  final double? bestCenterDistance;
  final double? bestZoomError;
  final bool left;

  PayLocationCommandDrift observe({
    required double centerDistance,
    required double zoomError,
  }) {
    if (left) {
      return this;
    }
    final centerLeft =
        bestCenterDistance != null &&
        centerDistance > bestCenterDistance! + payLocationCameraCenterTolerance;
    final zoomLeft =
        bestZoomError != null &&
        zoomError > bestZoomError! + payLocationCameraZoomTolerance;
    if (centerLeft || zoomLeft) {
      return PayLocationCommandDrift(
        bestCenterDistance: bestCenterDistance,
        bestZoomError: bestZoomError,
        left: true,
      );
    }
    return PayLocationCommandDrift(
      bestCenterDistance: bestCenterDistance == null
          ? centerDistance
          : math.min(bestCenterDistance!, centerDistance),
      bestZoomError: bestZoomError == null
          ? zoomError
          : math.min(bestZoomError!, zoomError),
    );
  }
}

const double payLocationCameraCenterTolerance = 1e-4;
const double payLocationCameraZoomTolerance = 0.05;

/// Unselected town labels are drawn only at this zoom and closer to the country.
const double payLocationTownLabelMaxZoom = 7.5;

/// [previousZoom] is the zoom the markers were last drawn at. A step inside
/// the noise band does not redraw. Several such steps do, once they add up.
/// Crossing the town-label cutoff always redraws.
bool payLocationZoomNeedsRedraw({
  required double previousZoom,
  required double reportedZoom,
}) {
  final crossedTownLabel =
      (previousZoom <= payLocationTownLabelMaxZoom) !=
      (reportedZoom <= payLocationTownLabelMaxZoom);
  final zoomStep = (reportedZoom - previousZoom).abs();
  return crossedTownLabel || zoomStep > payLocationCameraZoomTolerance;
}

/// Newest reported zoom, and the zoom the markers were last drawn at.
class PayLocationZoomTrack {
  const PayLocationZoomTrack({required this.reported, required this.drawn});

  final double reported;
  final double drawn;

  PayLocationZoomTrack observe(double reportedZoom) {
    final redraw = payLocationZoomNeedsRedraw(
      previousZoom: drawn,
      reportedZoom: reportedZoom,
    );
    return PayLocationZoomTrack(
      reported: reportedZoom,
      drawn: redraw ? reportedZoom : drawn,
    );
  }
}

double payLocationCenterDistance({
  required double fromLat,
  required double fromLon,
  required double toLat,
  required double toLon,
}) {
  final dLat = fromLat - toLat;
  final dLon = fromLon - toLon;
  return math.sqrt(dLat * dLat + dLon * dLon);
}

/// The span delta stored after the shown zoom is clamped to 5–16.
double payLocationStoredSpanZoomDelta({
  required double fitted,
  required double zoomDelta,
}) {
  final unclamped = fitted + zoomDelta;
  final shown = unclamped.clamp(5, 16).toDouble();
  if (shown == unclamped) {
    return zoomDelta;
  }
  return shown - fitted;
}

/// Zoom buttons keep a search, tap, or country fit until the camera moves.
PayLocationZoomStep payLocationZoomStep({
  required PayLocationCameraKind? pendingKind,
  required double? pendingLat,
  required double? pendingLon,
  required double? pendingZoom,
  required double pendingSpanZoomDelta,
  required bool cameraMovedSinceCommand,
  required double centerLat,
  required double centerLon,
  required double currentZoom,
  required double delta,
}) {
  final keepsPendingPoint =
      pendingKind == PayLocationCameraKind.point &&
      pendingLat != null &&
      pendingLon != null &&
      !cameraMovedSinceCommand &&
      (pendingLat != centerLat || pendingLon != centerLon);
  if (keepsPendingPoint) {
    final basis = pendingZoom ?? currentZoom;
    return PayLocationZoomStep.point(
      pendingLat,
      pendingLon,
      _clampPayLocationZoom(basis + delta),
    );
  }
  if (pendingKind == PayLocationCameraKind.span && !cameraMovedSinceCommand) {
    return PayLocationZoomStep.span(pendingSpanZoomDelta + delta);
  }
  var basis = currentZoom;
  if (!cameraMovedSinceCommand &&
      pendingKind == PayLocationCameraKind.point &&
      pendingLat == centerLat &&
      pendingLon == centerLon &&
      pendingZoom != null) {
    basis = pendingZoom;
  }
  return PayLocationZoomStep.point(
    centerLat,
    centerLon,
    _clampPayLocationZoom(basis + delta),
  );
}

double _clampPayLocationZoom(double zoom) => zoom.clamp(5, 16).toDouble();

List<PayLocationPin> filterPayLocationPins(List<PayLocationPin> pins, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return pins;
  }
  return [
    for (final pin in pins)
      if (pin.name.toLowerCase().contains(needle)) pin,
  ];
}

class PayLocationLabel {
  final String place;
  final String? street;

  const PayLocationLabel(this.place, this.street);

  /// Town without a leading Swiss or Liechtenstein postal code.
  String get town {
    final match = _postalTown.firstMatch(place);
    final town = match?.group(1);
    if (town == null || town.isEmpty) {
      return place;
    }
    return town;
  }
}

final RegExp _postalTown = RegExp(r'^\d{4}\s+(.+)$');

PayLocationLabel payLocationLabel(String name) {
  final trimmed = name.trim();
  final comma = trimmed.lastIndexOf(',');
  if (comma <= 0 || comma >= trimmed.length - 1) {
    return PayLocationLabel(trimmed, null);
  }

  final street = trimmed.substring(0, comma).trim();
  final place = trimmed.substring(comma + 1).trim();
  if (street.isEmpty || place.isEmpty) {
    return PayLocationLabel(trimmed, null);
  }
  return PayLocationLabel(place, street);
}

List<PayLocationPin> sortPayLocationPins(List<PayLocationPin> pins) {
  final sorted = [...pins]
    ..sort((a, b) {
      final left = payLocationLabel(a.name);
      final right = payLocationLabel(b.name);
      final byTown = left.town.compareTo(right.town);
      if (byTown != 0) {
        return byTown;
      }
      final byPlace = left.place.compareTo(right.place);
      if (byPlace != 0) {
        return byPlace;
      }
      return (left.street ?? '').compareTo(right.street ?? '');
    });
  return sorted;
}

bool samePayLocationPin(PayLocationPin a, PayLocationPin b) {
  return a.name == b.name && a.lat == b.lat && a.lon == b.lon;
}

double? _finiteDouble(Object? value) {
  if (value is! num) {
    return null;
  }

  final number = value.toDouble();
  return number.isFinite ? number : null;
}

double? _positiveFiniteDouble(Object? value) {
  final number = _finiteDouble(value);
  return number != null && number > 0 ? number : null;
}

String _trimmedString(Object? value) {
  return value is String ? value.trim() : '';
}

String? _nonEmptyString(Object? value) {
  final text = _trimmedString(value);
  return text.isEmpty ? null : text;
}

String _payLocationActivity(Object? value) {
  return switch (value) {
    'daily' => 'daily',
    'within7Days' => 'within7Days',
    'within30Days' => 'within30Days',
    'olderThan30Days' => 'olderThan30Days',
    'none' => 'none',
    _ => 'none',
  };
}

final RegExp _payLocationPhotoPath = RegExp(
  r'^/map/photos/[0-9a-f]{64}\.(jpg|png|webp)$',
);

/// Only `https://api.opencryptopay.io/map/photos/{64 lowercase hex}.{jpg|png|webp}`.
String? payLocationPhotoUrl(Object? value) {
  final url = _nonEmptyString(value);
  if (url == null) {
    return null;
  }
  final parsed = Uri.tryParse(url);
  if (parsed == null ||
      parsed.scheme != 'https' ||
      parsed.userInfo.isNotEmpty ||
      parsed.host != 'api.opencryptopay.io' ||
      parsed.hasPort ||
      parsed.hasQuery ||
      parsed.hasFragment ||
      !_payLocationPhotoPath.hasMatch(parsed.path)) {
    return null;
  }
  final canonical = 'https://api.opencryptopay.io${parsed.path}';
  return url == canonical ? url : null;
}

String _joinNonEmpty(List<String> parts, String separator) {
  return parts.where((part) => part.isNotEmpty).join(separator);
}
