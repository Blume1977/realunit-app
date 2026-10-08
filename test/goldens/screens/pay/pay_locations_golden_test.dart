import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_page.dart';
import 'package:realunit_wallet/styles/colors.dart';

import '../../../helper/helper.dart';

const _placesBody =
    '{"places":[{"name":"SPAR Zürich","category":"grocery","lat":47.37,"lon":8.54,'
    '"supports":[{"blockchain":"Ethereum","asset":"ZCHF"}]}]}';

final String _publishedPlacesBody = File(
  'test/goldens/screens/pay/fixtures/dev_places_ethereum_zchf.json',
).readAsStringSync();

http.Client _client({
  int placesStatus = 200,
  String placesBody = '{"places":[]}',
}) {
  return MockClient((request) async {
    if (request.url.toString() != payLocationsPlacesUrl) {
      return http.Response('unexpected', 500);
    }
    return http.Response.bytes(
      utf8.encode(placesBody),
      placesStatus,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Widget _map(http.Client client) {
  return PayLocationsPage(
    httpClient: client,
    mapBuilder: (_) => const ColoredBox(color: RealUnitColors.neutral100),
  );
}

void main() {
  // The indicator animates forever, so the loading shot is the first frame.
  goldenTest(
    'locations loading',
    fileName: 'pay_locations_page_loading',
    constraints: phoneConstraints,
    pumpBeforeTest: pumpOnce,
    builder: () => wrapForGolden(const PayLocationsPage(loadOnStart: false)),
  );

  goldenTest(
    'locations error',
    fileName: 'pay_locations_page_error',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(_map(_client(placesStatus: 500, placesBody: ''))),
  );

  goldenTest(
    'published locations',
    fileName: 'pay_locations_page_empty',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      PayLocationsPage(httpClient: _client(placesBody: _publishedPlacesBody)),
    ),
  );

  goldenTest(
    'locations with nothing published',
    fileName: 'pay_locations_page_unpublished',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(PayLocationsPage(httpClient: _client())),
  );

  goldenTest(
    'locations with one place',
    fileName: 'pay_locations_page_places',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      PayLocationsPage(httpClient: _client(placesBody: _placesBody)),
    ),
  );

  goldenTest(
    'locations with no search match',
    fileName: 'pay_locations_page_no_match',
    constraints: phoneConstraints,
    builder: () => wrapForGolden(
      PayLocationsPage(
        httpClient: _client(placesBody: _publishedPlacesBody),
        initialQuery: 'zzzz',
      ),
    ),
  );
}
