import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_page.dart';

import '../../helper/pump_golden_app.dart';

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQ'
  'AAAABJRU5ErkJggg==',
);

void main() {
  test('requests only ZCHF on Ethereum', () {
    expect(
      payLocationsPlacesUrl,
      'https://api.opencryptopay.io/map/places?blockchain=Ethereum&asset=ZCHF',
    );
    expect(payLocationsBlockchain, 'Ethereum');
    expect(payLocationsAsset, 'ZCHF');
  });

  test('uses the OpenFreeMap Liberty style and country bounds', () {
    expect(payLocationsStyleUrl, 'https://tiles.openfreemap.org/styles/liberty');
    expect(payLocationCountrySouth, 45.83003);
    expect(payLocationCountryNorth, 47.77564);
    expect(payLocationCountryWest, 5.97002);
    expect(payLocationCountryEast, 10.45459);
  });

  test('a places body must be a map whose places field is a list', () {
    expect(payLocationsPlacesBodyIsList({'places': []}), isTrue);
    expect(
      payLocationsPlacesBodyIsList({
        'places': <Object?>[{}],
      }),
      isTrue,
    );
    expect(payLocationsPlacesBodyIsList([]), isFalse);
    expect(payLocationsPlacesBodyIsList(null), isFalse);
    expect(payLocationsPlacesBodyIsList(1), isFalse);
    expect(payLocationsPlacesBodyIsList({'places': <String, Object>{}}), isFalse);
    expect(payLocationsPlacesBodyIsList(<String, Object>{}), isFalse);
  });

  test('drops a place without ZCHF on Ethereum', () {
    final pins = keepPayLocationPins({
      'places': [
        {
          'name': 'Shop',
          'lat': 47,
          'lon': 8,
          'supports': [
            {'blockchain': 'Ethereum', 'asset': 'USDT'},
            {'blockchain': 'Polygon', 'asset': 'ZCHF'},
            {'blockchain': 'Ethereum', 'asset': 'dEURO'},
          ],
        },
      ],
    });

    expect(pins, isEmpty);
  });

  test('drops a place with a non-finite coordinate', () {
    final pins = keepPayLocationPins({
      'places': [
        {
          'name': 'Shop',
          'lat': double.nan,
          'lon': 8,
          'supports': [
            {'blockchain': 'Ethereum', 'asset': 'ZCHF'},
          ],
        },
      ],
    });

    expect(pins, isEmpty);
  });

  test('drops a place without a usable name', () {
    final pins = keepPayLocationPins({
      'places': [
        {'lat': 47, 'lon': 8},
        {'name': '', 'lat': 47.1, 'lon': 8.1},
        {'name': '   ', 'lat': 47.2, 'lon': 8.2},
        {'name': 12, 'lat': 47.3, 'lon': 8.3},
        {'name': ' SPAR ', 'lat': 47.4, 'lon': 8.4},
      ],
    });

    expect(pins, hasLength(1));
    expect(pins.single.name, 'SPAR');
  });

  test('keeps a published place that omits supports', () {
    final pins = keepPayLocationPins({
      'places': [
        {'name': 'SPAR', 'category': 'shopping', 'lat': 47.1, 'lon': 8.2},
        {'name': 'Null', 'lat': 47.2, 'lon': 8.3, 'supports': null},
        {
          'name': 'Empty',
          'lat': 47.3,
          'lon': 8.4,
          'supports': <Object?>[],
        },
      ],
    });

    expect(pins.map((pin) => pin.name), ['SPAR', 'Null']);
  });

  test('keeps the published dev place list', () {
    final pins = keepPayLocationPins(
      jsonDecode(
        File(
          'test/goldens/screens/pay/fixtures/dev_places_ethereum_zchf.json',
        ).readAsStringSync(),
      ),
    );

    expect(pins, hasLength(170));
    expect(
      pins.every((pin) => pin.lat >= 46 && pin.lat <= 48 && pin.lon >= 7 && pin.lon <= 10),
      isTrue,
    );
  });

  testWidgets('shows the empty card when no place is published', (tester) async {
    await tester.pumpWidget(
      wrapForGolden(
        PayLocationsPage(
          httpClient: MockClient(
            (request) async => http.Response.bytes(
              utf8.encode('{"places":[]}'),
              200,
              headers: const {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          mapBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Standorte veröffentlicht.'), findsOneWidget);
  });

  testWidgets('loads a pinned place photo through the injected client', (tester) async {
    final jpg = 'https://api.opencryptopay.io/map/photos/${'d' * 64}.jpg';
    const detail = 'https://api.opencryptopay.io/map/places/npub1shop';
    final seen = <String>[];
    final redirects = <bool>[];
    final client = MockClient((request) async {
      final url = request.url.toString();
      seen.add(url);
      redirects.add(request.followRedirects);
      if (url == payLocationsPlacesUrl) {
        return http.Response.bytes(
          utf8.encode(
            '{"places":[{"id":"npub1shop","name":"SPAR Zürich","lat":47.37,"lon":8.54,'
            '"activity":"daily","category":"Lebensmittel",'
            '"description":"Ein Geschäft mit ZCHF.","techProvider":"DFX.swiss",'
            '"shopType":"SPAR","street":"Bahnhofstrasse","houseNumber":"1",'
            '"postalCode":"8001","city":"Zürich","country":"Schweiz",'
            '"supports":[{"blockchain":"Ethereum","asset":"ZCHF"}]}]}',
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (url == detail) {
        return http.Response.bytes(
          utf8.encode(
            '{"place":{"photos":[{"url":"$jpg","caption":"Front"},'
            '{"url":"https://example.com/shop.jpg"}]}}',
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (url == jpg) {
        return http.Response.bytes(
          _onePixelPng,
          200,
          headers: const {'content-type': 'image/png'},
        );
      }
      return http.Response('unexpected', 500);
    });

    await tester.pumpWidget(
      wrapForGolden(
        PayLocationsPage(httpClient: client, mapBuilder: (_) => const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPAR Zürich'));
    await tester.pumpAndSettle();

    expect(
      find.text('An mindestens 5 Tagen eine Zahlung in den letzten 7 Tagen.'),
      findsOneWidget,
    );
    expect(find.text('Zahlung: Ethereum / ZCHF'), findsOneWidget);
    expect(seen, contains(detail));
    expect(seen, contains(jpg));
    expect(seen.where((url) => url.contains('example.com')), isEmpty);
    expect(redirects, isNotEmpty);
    expect(redirects, everyElement(isFalse));
  });

  test('keeps a decoded place that accepts ZCHF on Ethereum', () {
    final pins = keepPayLocationPins(
      jsonDecode(
        '{"places":[{"name":"Shop","category":"store","lat":47.1,"lon":8.2,'
        '"supports":[{"blockchain":"Ethereum","asset":"ZCHF"}]}]}',
      ),
    );

    expect(pins, hasLength(1));
    expect(pins.single.name, 'Shop');
    expect(pins.single.category, 'store');
  });

  test('keeps activity and all published shop details', () {
    final pins = keepPayLocationPins({
      'places': [
        {
          'id': ' npub1shop ',
          'name': ' SPAR Goldach ',
          'category': ' shopping ',
          'lat': 47.47,
          'lon': 9.48,
          'description': ' Local shop ',
          'techProvider': ' DFX.swiss ',
          'shopType': ' SPAR ',
          'street': ' Bahnhofstrasse ',
          'houseNumber': ' 1 ',
          'postalCode': ' 9403 ',
          'city': ' Goldach ',
          'country': ' Switzerland ',
          'activity': 'daily',
          'coverPhoto': {
            'url': ' https://api.opencryptopay.io/map/photos/${'a' * 64}.jpg ',
          },
        },
      ],
    });

    expect(pins, hasLength(1));
    final pin = pins.single;
    expect(pin.id, 'npub1shop');
    expect(pin.name, 'SPAR Goldach');
    expect(pin.category, 'shopping');
    expect(pin.description, 'Local shop');
    expect(pin.techProvider, 'DFX.swiss');
    expect(pin.shopType, 'SPAR');
    expect(pin.street, 'Bahnhofstrasse');
    expect(pin.houseNumber, '1');
    expect(pin.postalCode, '9403');
    expect(pin.city, 'Goldach');
    expect(pin.country, 'Switzerland');
    expect(pin.activity, 'daily');
    expect(pin.coverUrl, 'https://api.opencryptopay.io/map/photos/${'a' * 64}.jpg');
    expect(payLocationActivityColor(pin.activity), '#FF4D00');
    expect(
      payLocationMarkers(visible: [pin], selected: null, zoom: 10).single.color,
      '#FF4D00',
    );
  });

  test('normalizes missing and unknown activity to none', () {
    final pins = keepPayLocationPins({
      'places': [
        {'name': 'Missing', 'lat': 47, 'lon': 8},
        {'name': 'Unknown', 'lat': 47.1, 'lon': 8.1, 'activity': 'sometimes'},
        {'name': 'Empty', 'lat': 47.2, 'lon': 8.2, 'activity': ''},
        {'name': 'Wrong type', 'lat': 47.3, 'lon': 8.3, 'activity': 1},
      ],
    });

    expect(pins.map((pin) => pin.activity), ['none', 'none', 'none', 'none']);
    expect(pins.map((pin) => payLocationActivityColor(pin.activity)), [
      '#FFE3CC',
      '#FFE3CC',
      '#FFE3CC',
      '#FFE3CC',
    ]);
  });

  test('groups nearby shops and keeps distant shops apart', () {
    const near = PayLocationPin(name: 'A', category: null, lat: 47.37, lon: 8.54);
    const close = PayLocationPin(name: 'B', category: null, lat: 47.4, lon: 8.56);
    const far = PayLocationPin(name: 'C', category: null, lat: 46.2, lon: 6.14);
    final clusters = clusterPayLocationPins(
      const [near, close, far],
      cellDegrees: 0.5,
    );

    expect(clusters, hasLength(2));
    expect(clusters.map((cluster) => cluster.pins.length).toSet(), {2, 1});
    expect(
      payLocationClusterCellDegrees(8),
      lessThan(payLocationClusterCellDegrees(6)),
    );
  });

  test('creates an unselected pin marker without a town at zoom 10', () {
    const pin = PayLocationPin(
      name: 'SPAR Bahnhofstrasse 1, 9403 Goldach',
      category: null,
      lat: 47.37,
      lon: 8.54,
    );

    final markers = payLocationMarkers(visible: const [pin], selected: null, zoom: 10);

    expect(markers, hasLength(1));
    expect(markers.single.kind, PayLocationMarkerKind.pin);
    expect(markers.single.diameter, 16);
    expect(markers.single.strokeWidth, 2);
    expect(markers.single.color, '#FFE3CC');
    expect(markers.single.count, isNull);
    expect(markers.single.town, isNull);
    expect(markers.single.pins, [pin]);
  });

  test('creates a larger selected pin marker with its town', () {
    const pin = PayLocationPin(
      name: 'SPAR Bahnhofstrasse 1, 9403 Goldach',
      category: null,
      lat: 47.37,
      lon: 8.54,
    );

    final markers = payLocationMarkers(visible: const [pin], selected: pin, zoom: 10);

    expect(markers, hasLength(1));
    expect(markers.single.kind, PayLocationMarkerKind.pin);
    expect(markers.single.diameter, 18);
    expect(markers.single.strokeWidth, 3);
    expect(markers.single.color, '#FFE3CC');
    expect(markers.single.count, isNull);
    expect(markers.single.town, 'Goldach');
    expect(markers.single.pins, [pin]);
  });

  test('uses a structured city on the selected marker', () {
    const pin = PayLocationPin(
      name: 'SPAR Zürich',
      category: null,
      lat: 47.37,
      lon: 8.54,
      city: 'Zürich',
    );

    final markers = payLocationMarkers(visible: const [pin], selected: pin, zoom: 10);

    expect(markers.single.town, 'Zürich');
  });

  test('creates a cluster and a single marker at country zoom', () {
    const near = PayLocationPin(name: 'A', category: null, lat: 47.37, lon: 8.54);
    const close = PayLocationPin(name: 'B', category: null, lat: 47.4, lon: 8.56);
    const far = PayLocationPin(name: 'C', category: null, lat: 46.2, lon: 6.14);

    final markers = payLocationMarkers(
      visible: const [near, close, far],
      selected: null,
      zoom: 6,
    );
    final cluster = markers.singleWhere((marker) => marker.kind == PayLocationMarkerKind.cluster);
    final pin = markers.singleWhere((marker) => marker.kind == PayLocationMarkerKind.pin);

    expect(markers, hasLength(2));
    expect(cluster.count, 2);
    expect(cluster.diameter, 34);
    expect(cluster.strokeWidth, 2);
    expect(cluster.color, '#034C81');
    expect(cluster.town, isNull);
    expect(cluster.pins, [near, close]);
    expect(pin.pins, [far]);
  });

  test('does not include a selected pin in a cluster', () {
    const selected = PayLocationPin(name: 'A', category: null, lat: 47.37, lon: 8.54);
    const close = PayLocationPin(name: 'B', category: null, lat: 47.4, lon: 8.56);
    const far = PayLocationPin(name: 'C', category: null, lat: 46.2, lon: 6.14);

    final markers = payLocationMarkers(
      visible: const [selected, close, far],
      selected: selected,
      zoom: 6,
    );
    final selectedMarker = markers.singleWhere((marker) => marker.pins.contains(selected));

    expect(selectedMarker.kind, PayLocationMarkerKind.pin);
    expect(selectedMarker.diameter, 18);
    expect(
      markers
          .where((marker) => !identical(marker, selectedMarker))
          .expand((marker) => marker.pins)
          .contains(selected),
      isFalse,
    );
  });

  test('shows an unselected pin town through zoom 7.5', () {
    const pin = PayLocationPin(
      name: 'SPAR Bahnhofstrasse 1, 9403 Goldach',
      category: null,
      lat: 47.37,
      lon: 8.54,
    );

    final zoomSeven = payLocationMarkers(visible: const [pin], selected: null, zoom: 7);
    final zoomEight = payLocationMarkers(visible: const [pin], selected: null, zoom: 8);

    expect(zoomSeven.single.town, 'Goldach');
    expect(zoomEight.single.town, isNull);
  });

  test('calculates Web Mercator zoom for country and pin spans', () {
    final countryZoom = payLocationZoomForSpan(
      south: payLocationCountrySouth,
      north: payLocationCountryNorth,
      west: payLocationCountryWest,
      east: payLocationCountryEast,
      width: 400,
      height: 300,
      padding: 28,
      maxZoom: 16,
    );
    final pinZoom = payLocationZoomForSpan(
      south: 47.37,
      north: 47.37001,
      west: 8.54,
      east: 8.54001,
      width: 400,
      height: 300,
      padding: 36,
      maxZoom: 12,
    );

    expect(countryZoom, greaterThan(5));
    expect(countryZoom, lessThan(8));
    expect(pinZoom, 12);
    expect(countryZoom, lessThan(12));
  });

  test('keeps an unapplied search target when zooming', () {
    final step = payLocationZoomStep(
      pendingKind: PayLocationCameraKind.point,
      pendingLat: 47.37,
      pendingLon: 8.54,
      pendingZoom: 12,
      pendingSpanZoomDelta: 0,
      cameraMovedSinceCommand: false,
      centerLat: 46.8,
      centerLon: 8.23,
      currentZoom: 7,
      delta: 1,
    );

    expect(step.lat, 47.37);
    expect(step.lon, 8.54);
    expect(step.zoom, 13);
    expect(step.spanZoomDelta, isNull);
  });

  test('stores a zoom delta on a country fit the camera has not reached', () {
    final step = payLocationZoomStep(
      pendingKind: PayLocationCameraKind.span,
      pendingLat: null,
      pendingLon: null,
      pendingZoom: null,
      pendingSpanZoomDelta: 1,
      cameraMovedSinceCommand: false,
      centerLat: 46.8,
      centerLon: 8.23,
      currentZoom: 7,
      delta: 1,
    );

    expect(step.spanZoomDelta, 2);
    expect(step.lat, isNull);
  });

  test('zooms the current centre after the camera has moved', () {
    final step = payLocationZoomStep(
      pendingKind: PayLocationCameraKind.point,
      pendingLat: 47.37,
      pendingLon: 8.54,
      pendingZoom: 12,
      pendingSpanZoomDelta: 0,
      cameraMovedSinceCommand: true,
      centerLat: 46.9,
      centerLon: 8.3,
      currentZoom: 11,
      delta: -1,
    );

    expect(step.lat, 46.9);
    expect(step.lon, 8.3);
    expect(step.zoom, 10);
  });

  test('stacks a zoom that is still waiting at the current centre', () {
    final step = payLocationZoomStep(
      pendingKind: PayLocationCameraKind.point,
      pendingLat: 46.8,
      pendingLon: 8.23,
      pendingZoom: 12,
      pendingSpanZoomDelta: 0,
      cameraMovedSinceCommand: false,
      centerLat: 46.8,
      centerLon: 8.23,
      currentZoom: 7,
      delta: 1,
    );

    expect(step.lat, 46.8);
    expect(step.lon, 8.23);
    expect(step.zoom, 13);
  });

  test('keeps a camera command while its ride gets closer', () {
    var drift = const PayLocationCommandDrift();
    drift = drift.observe(centerDistance: 0.5, zoomError: 4);
    drift = drift.observe(centerDistance: 0.2, zoomError: 1);
    drift = drift.observe(centerDistance: 0.01, zoomError: 0.02);

    expect(drift.left, isFalse);
  });

  test('marks a pan that leaves the commanded centre', () {
    final approached = const PayLocationCommandDrift().observe(
      centerDistance: 0.01,
      zoomError: 0,
    );
    final stayed = approached.observe(
      centerDistance: 0.01 + payLocationCameraCenterTolerance,
      zoomError: 0,
    );
    final left = approached.observe(
      centerDistance: 0.01 + payLocationCameraCenterTolerance + 0.0001,
      zoomError: 0,
    );

    expect(stayed.left, isFalse);
    expect(left.left, isTrue);
    expect(left.observe(centerDistance: 0, zoomError: 0).left, isTrue);
  });

  test('marks a pinch that leaves the commanded zoom', () {
    final approached = const PayLocationCommandDrift().observe(
      centerDistance: 0,
      zoomError: 0.01,
    );
    final stayed = approached.observe(
      centerDistance: 0,
      zoomError: 0.01 + payLocationCameraZoomTolerance,
    );
    final left = approached.observe(
      centerDistance: 0,
      zoomError: 0.01 + payLocationCameraZoomTolerance + 0.01,
    );

    expect(stayed.left, isFalse);
    expect(left.left, isTrue);
  });

  test('keeps a small zoom change and redraws when a town label crosses the cutoff', () {
    expect(payLocationZoomNeedsRedraw(previousZoom: 10, reportedZoom: 10.04), isFalse);
    expect(payLocationZoomNeedsRedraw(previousZoom: 10, reportedZoom: 10.06), isTrue);
    expect(payLocationZoomNeedsRedraw(previousZoom: 7.49, reportedZoom: 7.5), isFalse);
    expect(payLocationZoomNeedsRedraw(previousZoom: 7.49, reportedZoom: 7.51), isTrue);
  });

  test('small zoom steps add up against the last drawn zoom', () {
    const start = PayLocationZoomTrack(reported: 10, drawn: 10);
    final first = start.observe(10.04);
    expect(first.reported, 10.04);
    expect(first.drawn, 10);
    final second = first.observe(10.08);
    expect(second.reported, 10.08);
    expect(second.drawn, 10.08);

    const labels = PayLocationZoomTrack(reported: 7.49, drawn: 7.49);
    final still = labels.observe(7.5);
    expect(still.reported, 7.5);
    expect(still.drawn, 7.49);
    final crossed = still.observe(7.51);
    expect(crossed.reported, 7.51);
    expect(crossed.drawn, 7.51);
  });

  test('stores a span zoom delta inside the zoom limits', () {
    expect(payLocationStoredSpanZoomDelta(fitted: 15, zoomDelta: 3), 1);
    expect(payLocationStoredSpanZoomDelta(fitted: 7, zoomDelta: -10), -2);
    expect(payLocationStoredSpanZoomDelta(fitted: 10, zoomDelta: 1), 1);
    expect(payLocationStoredSpanZoomDelta(fitted: 16, zoomDelta: 2), 0);
    expect(payLocationStoredSpanZoomDelta(fitted: 5, zoomDelta: -3), 0);
  });

  test('zooms from the current level after a pinch that kept the centre', () {
    final step = payLocationZoomStep(
      pendingKind: PayLocationCameraKind.point,
      pendingLat: 46.8,
      pendingLon: 8.23,
      pendingZoom: 12,
      pendingSpanZoomDelta: 0,
      cameraMovedSinceCommand: true,
      centerLat: 46.8,
      centerLon: 8.23,
      currentZoom: 14,
      delta: 1,
    );

    expect(step.lat, 46.8);
    expect(step.lon, 8.23);
    expect(step.zoom, 15);
  });

  test('filters and sorts shop names', () {
    const zurich = PayLocationPin(name: 'SPAR Zürich', category: null, lat: 47, lon: 8);
    const bern = PayLocationPin(name: 'SPAR Bern', category: null, lat: 46.9, lon: 7.4);
    final filtered = filterPayLocationPins(const [zurich, bern], 'bern');

    expect(filtered, [bern]);
    expect(sortPayLocationPins(const [zurich, bern]).map((pin) => pin.name), [
      'SPAR Bern',
      'SPAR Zürich',
    ]);
    expect(samePayLocationPin(bern, bern), isTrue);
    expect(samePayLocationPin(bern, zurich), isFalse);
  });

  test('splits a published address into place and street', () {
    final label = payLocationLabel('SPAR Bahnhofstrasse 1, 9403 Goldach');

    expect(label.place, '9403 Goldach');
    expect(label.street, 'SPAR Bahnhofstrasse 1');
    expect(label.town, 'Goldach');

    final plain = payLocationLabel('SPAR Zürich');
    expect(plain.place, 'SPAR Zürich');
    expect(plain.street, isNull);
    expect(plain.town, 'SPAR Zürich');

    final dashed = payLocationLabel('SPAR Seestrasse 1–3, 8640 Rapperswil');
    expect(dashed.street, 'SPAR Seestrasse 1–3');
    expect(dashed.town, 'Rapperswil');
  });

  test('builds structured address lines without empty values', () {
    const pin = PayLocationPin(
      name: 'SPAR Goldach',
      category: null,
      lat: 47.47,
      lon: 9.48,
      street: 'Bahnhofstrasse',
      houseNumber: '1',
      postalCode: '9403',
      city: 'Goldach',
      country: 'Switzerland',
    );

    expect(payLocationAddressLines(pin), [
      'Bahnhofstrasse 1',
      '9403 Goldach',
      'Switzerland',
    ]);
  });

  test('builds detail URLs only for npub identifiers', () {
    expect(payLocationDetailUrl(null), isNull);
    expect(payLocationDetailUrl('4b42348f-8a02-4fbb-8ab7-252b1182c25c'), isNull);
    expect(
      payLocationDetailUrl('npub1shop'),
      'https://api.opencryptopay.io/map/places/npub1shop',
    );
    expect(payLocationDetailUrl('npub1a/b'), isNull);
    expect(payLocationDetailUrl('npub1a?x=1'), isNull);
    expect(payLocationDetailUrl('npub1a#frag'), isNull);
    expect(payLocationDetailUrl('npub1shop/'), isNull);
    expect(
      payLocationDetailUrl('npub1/../../places?blockchain=Bitcoin&asset=BTC'),
      isNull,
    );
  });

  test('reads only pinned place photo URLs', () {
    final jpg = 'https://api.opencryptopay.io/map/photos/${'a' * 64}.jpg';
    final png = 'https://api.opencryptopay.io/map/photos/${'b' * 64}.png';
    final webp = 'https://api.opencryptopay.io/map/photos/${'c' * 64}.webp';
    final photos = payLocationPhotos({
      'place': {
        'photos': [
          {'url': ' $jpg ', 'caption': ' Front ', 'width': 1200, 'height': 800.5},
          {'url': png},
          {'url': webp, 'width': 0, 'height': double.nan},
          {'url': 'https://example.com/shop.jpg'},
          {'url': 'http://api.opencryptopay.io/map/photos/${'a' * 64}.jpg'},
          {'url': '$jpg?size=1'},
          {'url': '$jpg#cover'},
          {'url': 'https://user@api.opencryptopay.io/map/photos/${'a' * 64}.jpg'},
          {'url': 'https://api.opencryptopay.io/map/photos/${'A' * 64}.jpg'},
          {'url': 'https://api.opencryptopay.io/map/photos/${'a' * 63}.jpg'},
          {'url': 'https://api.opencryptopay.io/map/photos/${'a' * 64}.gif'},
          {'url': 'https://api.opencryptopay.io:443/map/photos/${'a' * 64}.jpg'},
        ],
      },
    });

    expect(photos.map((photo) => photo.url), [jpg, png, webp]);
    expect(photos.first.caption, 'Front');
    expect(photos.first.width, 1200);
    expect(photos.first.height, 800.5);
    expect(photos.last.caption, isNull);
    expect(photos.last.width, isNull);
    expect(photos.last.height, isNull);
    expect(payLocationPhotos(null), isEmpty);
    expect(payLocationPhotos(<String, Object>{}), isEmpty);
    expect(payLocationPhotos({'place': {}}), isEmpty);
    expect(payLocationPhotoUrl('https://example.com/cover.jpg'), isNull);
  });

  test('sorts published addresses by town', () {
    const zurich = PayLocationPin(
      name: 'SPAR Bahnhofstrasse 1, 8001 Zürich',
      category: null,
      lat: 47.37,
      lon: 8.54,
    );
    const bern = PayLocationPin(
      name: 'SPAR Marktgasse 1, 3011 Bern',
      category: null,
      lat: 46.95,
      lon: 7.45,
    );

    expect(sortPayLocationPins(const [zurich, bern]).map((pin) => pin.name), [
      bern.name,
      zurich.name,
    ]);
  });

  test('spreads the published shops across the country view', () {
    final pins = keepPayLocationPins(
      jsonDecode(
        File(
          'test/goldens/screens/pay/fixtures/dev_places_ethereum_zchf.json',
        ).readAsStringSync(),
      ),
    );
    final country = payLocationCountryView(width: 358, height: 400);
    final overview = clusterPayLocationPins(
      pins,
      cellDegrees: payLocationClusterCellDegrees(country.zoom),
    );
    final close = clusterPayLocationPins(
      pins,
      cellDegrees: payLocationClusterCellDegrees(14),
    );

    expect(overview.length, greaterThan(4));
    expect(overview.length, lessThan(15));
    expect(overview.every((cluster) => cluster.pins.length < pins.length), isTrue);
    expect(close.every((cluster) => cluster.isSingle), isTrue);
  });

  test('projects the country centre to the middle of the test map', () {
    const width = 358.0;
    const height = 400.0;
    final view = payLocationCountryView(width: width, height: height);
    final centre = payLocationMapPoint(
      lat: view.centerLat,
      lon: view.centerLon,
      zoom: view.zoom,
      centerLat: view.centerLat,
      centerLon: view.centerLon,
      width: width,
      height: height,
    );
    final north = payLocationMapPoint(
      lat: payLocationCountryNorth,
      lon: view.centerLon,
      zoom: view.zoom,
      centerLat: view.centerLat,
      centerLon: view.centerLon,
      width: width,
      height: height,
    );
    final lugano = payLocationMapPoint(
      lat: 46.003,
      lon: 8.951,
      zoom: view.zoom,
      centerLat: view.centerLat,
      centerLon: view.centerLon,
      width: width,
      height: height,
    );

    expect(view.zoom, greaterThan(5));
    expect(view.zoom, lessThan(8));
    expect(centre.x, closeTo(width / 2, 0.001));
    expect(centre.y, closeTo(height / 2, 0.001));
    expect(north.y, lessThan(centre.y));
    expect(lugano.y, greaterThan(centre.y));
    expect(lugano.x, inInclusiveRange(0, width));
    expect(lugano.y, inInclusiveRange(0, height));
  });

  test('frames the Liberty snapshot around the country view', () {
    expect(payLocationLibertyWest, 4.21875);
    expect(payLocationLibertyEast, 12.65625);
    expect(payLocationLibertyNorth, closeTo(51.179342979289686, 1e-12));
    expect(payLocationLibertySouth, closeTo(44.59046718130912, 1e-12));
    expect(payLocationLibertyWest, lessThan(payLocationCountryWest));
    expect(payLocationLibertyEast, greaterThan(payLocationCountryEast));
    expect(payLocationLibertyNorth, greaterThan(payLocationCountryNorth));
    expect(payLocationLibertySouth, lessThan(payLocationCountrySouth));
  });
}
