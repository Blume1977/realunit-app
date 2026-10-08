import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_lakes.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_outline.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_page.dart';

import '../../helper/pump_golden_app.dart';

void main() {
  test('requests only ZCHF on Ethereum', () {
    expect(
      payLocationsPlacesUrl,
      'https://api.opencryptopay.io/map/places?blockchain=Ethereum&asset=ZCHF',
    );
    expect(payLocationsBlockchain, 'Ethereum');
    expect(payLocationsAsset, 'ZCHF');
  });

  test('a places body must be a map whose places field is a list', () {
    expect(payLocationsPlacesBodyIsList({'places': []}), isTrue);
    expect(payLocationsPlacesBodyIsList({'places': <Object?>[{}]}), isTrue);
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
    final overview = clusterPayLocationPins(
      pins,
      cellDegrees: payLocationClusterCellDegrees(6.6),
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

  test('hides a city label that sits on a shop group', () {
    final pins = keepPayLocationPins(
      jsonDecode(
        File(
          'test/goldens/screens/pay/fixtures/dev_places_ethereum_zchf.json',
        ).readAsStringSync(),
      ),
    );
    final clusters = clusterPayLocationPins(
      pins,
      cellDegrees: payLocationClusterCellDegrees(6.6),
    );

    expect(
      payLocationCityCovered(
        cityName: 'Zürich',
        cityLat: 47.3769,
        cityLon: 8.5417,
        zoom: 6.6,
        clusters: clusters,
      ),
      isTrue,
    );
    expect(
      payLocationCityCovered(
        cityName: 'Genf',
        cityLat: 46.2044,
        cityLon: 6.1432,
        zoom: 6.6,
        clusters: clusters,
      ),
      isFalse,
    );
  });

  test('keeps the country and lake outlines on the map', () {
    expect(payLocationCountryRings, hasLength(2));
    expect(payLocationLakeRings.length, greaterThan(8));
    for (final ring in [...payLocationCountryRings, ...payLocationLakeRings]) {
      expect(ring.length, greaterThan(3));
      for (final point in ring) {
        expect(point.latitude, inInclusiveRange(45.5, 48.2));
        expect(point.longitude, inInclusiveRange(5.5, 10.8));
      }
    }
  });
}
