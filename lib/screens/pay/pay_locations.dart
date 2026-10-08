import 'dart:math' as math;

const String payLocationsBlockchain = 'Ethereum';
const String payLocationsAsset = 'ZCHF';

const String payLocationsPlacesUrl =
    'https://api.opencryptopay.io/map/places?blockchain=Ethereum&asset=ZCHF';

class PayLocationPin {
  final String name;
  final String? category;
  final double lat;
  final double lon;

  const PayLocationPin({
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
  });
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
    pins.add(
      PayLocationPin(
        name: name.trim(),
        category: category is String ? category : null,
        lat: lat,
        lon: lon,
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

/// Cell size for a cluster spacing of about 64 pixels at [zoom].
double payLocationClusterCellDegrees(double zoom) {
  final worldPixels = 256 * math.pow(2, zoom);
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

List<PayLocationPin> filterPayLocationPins(List<PayLocationPin> pins, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return pins;
  }
  return [for (final pin in pins) if (pin.name.toLowerCase().contains(needle)) pin];
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
  final sorted = [...pins]..sort((a, b) {
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

/// True when a city label would run under a shop marker at [zoom].
bool payLocationCityCovered({
  required String cityName,
  required double cityLat,
  required double cityLon,
  required double zoom,
  required List<PayLocationCluster> clusters,
  PayLocationPin? selected,
}) {
  final cell = payLocationClusterCellDegrees(zoom);
  if (cell <= 0) {
    return false;
  }

  final cosLat = math.cos(cityLat * math.pi / 180);
  final textPx = math.max(28.0, cityName.length * 7.2);
  bool hits(double lat, double lon, double markerPx) {
    final dx = (cityLon - lon) / cell * 64;
    final dy = cosLat == 0 ? 0.0 : (cityLat - lat) / cell * 64 / cosLat;
    final gap = math.sqrt(dx * dx + dy * dy) - (textPx / 2 + markerPx / 2);
    return gap < 4;
  }

  for (final cluster in clusters) {
    if (hits(cluster.lat, cluster.lon, cluster.isSingle ? 18 : 34)) {
      return true;
    }
  }
  if (selected != null && hits(selected.lat, selected.lon, 168)) {
    return true;
  }
  return false;
}

double? _finiteDouble(Object? value) {
  if (value is! num) {
    return null;
  }

  final number = value.toDouble();
  return number.isFinite ? number : null;
}
