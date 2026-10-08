import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/packages/service/app_store.dart';
import 'package:realunit_wallet/screens/pay/pay_locations.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_lakes.dart';
import 'package:realunit_wallet/screens/pay/pay_locations_outline.dart';
import 'package:realunit_wallet/setup/di.dart';
import 'package:realunit_wallet/styles/colors.dart';

class _CityLabel {
  final String name;
  final double lat;
  final double lon;

  const _CityLabel(this.name, this.lat, this.lon);
}

const List<_CityLabel> _cities = [
  _CityLabel('Genf', 46.2044, 6.1432),
  _CityLabel('Basel', 47.5596, 7.5886),
  _CityLabel('Bern', 46.948, 7.4474),
  _CityLabel('Luzern', 47.0502, 8.3093),
  _CityLabel('Zürich', 47.3769, 8.5417),
  _CityLabel('St. Gallen', 47.4245, 9.3767),
  _CityLabel('Chur', 46.8499, 9.5329),
  _CityLabel('Lugano', 46.0037, 8.9511),
  _CityLabel('Liechtenstein', 47.141, 9.5209),
];

class PayLocationsPage extends StatefulWidget {
  const PayLocationsPage({
    super.key,
    this.mapBuilder,
    this.httpClient,
    this.loadOnStart = true,
    this.initialQuery = '',
  });

  final Widget Function(List<PayLocationPin> pins)? mapBuilder;
  final http.Client? httpClient;

  /// False keeps the initial loading frame and does not start a request.
  final bool loadOnStart;

  /// Pre-fills the shop search. Tests use it to show the no-match state.
  final String initialQuery;

  @override
  State<PayLocationsPage> createState() => _PayLocationsPageState();
}

class _PayLocationsPageState extends State<PayLocationsPage> {
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  final LatLngBounds _countryBounds = LatLngBounds(
    const LatLng(payLocationCountrySouth, payLocationCountryWest),
    const LatLng(payLocationCountryNorth, payLocationCountryEast),
  );

  List<PayLocationPin> _pins = const [];
  PayLocationPin? _selectedPin;
  late String _query;
  bool _loading = true;
  bool _error = false;
  bool _mapReady = false;
  double _zoom = 7;
  LatLng _center = const LatLng(46.8, 8.23);
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.loadOnStart) {
      _loadPlaces();
    }
  }

  Future<http.Response> _get(Uri url) {
    final client = widget.httpClient;
    if (client != null) {
      return client.get(url);
    }
    return getIt<AppStore>().httpClient.get(url);
  }

  Future<void> _loadPlaces() async {
    final generation = ++_generation;
    try {
      final response = await _get(
        Uri.parse(payLocationsPlacesUrl),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        _showError(generation);
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (!payLocationsPlacesBodyIsList(decoded)) {
        _showError(generation);
        return;
      }

      final pins = keepPayLocationPins(decoded);
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _pins = pins;
        _selectedPin = pins.length == 1 ? pins.single : null;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      _showError(generation);
    }
  }

  void _showError(int generation) {
    if (!mounted || generation != _generation) {
      return;
    }

    setState(() {
      _loading = false;
      _error = true;
    });
  }

  @override
  void dispose() {
    _generation++;
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (!mounted) {
      return;
    }
    _center = event.camera.center;
    _mapReady = true;
    final zoom = event.camera.zoom;
    if ((zoom - _zoom).abs() <= 0.05) {
      return;
    }
    setState(() => _zoom = zoom);
  }

  void _zoomBy(double delta) {
    if (!_mapReady) {
      return;
    }
    _mapController.move(_center, (_zoom + delta).clamp(5, 16).toDouble());
  }

  void _selectPin(PayLocationPin pin) {
    setState(() => _selectedPin = pin);
    if (!_mapReady) {
      return;
    }
    _mapController.move(LatLng(pin.lat, pin.lon), 13);
  }

  void _onQuery(String value) {
    final visible = filterPayLocationPins(_pins, value);
    setState(() {
      _query = value;
      if (visible.length == 1) {
        _selectedPin = visible.single;
        return;
      }
      final selected = _selectedPin;
      if (selected == null) {
        return;
      }
      final stillVisible = visible.any((pin) => samePayLocationPin(pin, selected));
      if (!stillVisible) {
        _selectedPin = null;
      }
    });
    _frameQuery(visible, value);
  }

  void _frameQuery(List<PayLocationPin> visible, String value) {
    if (!_mapReady) {
      return;
    }
    if (value.trim().isEmpty || visible.isEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: _countryBounds, padding: const .all(28)),
      );
      return;
    }
    if (visible.length == 1) {
      final pin = visible.single;
      _mapController.move(LatLng(pin.lat, pin.lon), 12);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final pin in visible) LatLng(pin.lat, pin.lon),
        ]),
        padding: const .all(36),
        maxZoom: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).payLocationsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 12),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error) {
      return Center(
        child: Text(
          S.of(context).payLocationsError,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: RealUnitColors.neutral500),
        ),
      );
    }
    if (_pins.isEmpty) {
      return _emptyCard(context);
    }

    final visible = sortPayLocationPins(filterPayLocationPins(_pins, _query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildMapFrame(visible)),
        Padding(
          padding: const .only(top: 12, bottom: 8),
          child: _searchField(context),
        ),
        Padding(
          padding: const .only(bottom: 4),
          child: Text(
            _countLabel(context, visible.length),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(flex: 2, child: _shopList(context, visible)),
      ],
    );
  }

  Widget _emptyCard(BuildContext context) {
    final map = widget.mapBuilder?.call(const []) ?? _buildMap(const []);
    return Stack(
      children: [
        Positioned.fill(child: map),
        Center(
          child: Card(
            child: Padding(
              padding: const .all(12),
              child: Text(
                S.of(context).payLocationsEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _countLabel(BuildContext context, int count) {
    if (count == 1) {
      return S.of(context).payLocationsCountOne;
    }
    return S.of(context).payLocationsCountMany('$count');
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: _onQuery,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: S.of(context).payLocationsSearch,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: RealUnitColors.neutral50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _shopList(BuildContext context, List<PayLocationPin> visible) {
    if (visible.isEmpty) {
      return Center(
        child: Text(
          S.of(context).payLocationsNoMatch,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: RealUnitColors.neutral500),
        ),
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: RealUnitColors.neutral200),
      itemBuilder: (context, index) {
        final pin = visible[index];
        final label = payLocationLabel(pin.name);
        final selected = _selectedPin != null && samePayLocationPin(pin, _selectedPin!);
        return Material(
          color: selected ? RealUnitColors.brand200 : RealUnitColors.basic.white,
          child: InkWell(
            onTap: () => _selectPin(pin),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (label.street != null)
                    Text(
                      label.street!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RealUnitColors.neutral500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapFrame(List<PayLocationPin> visible) {
    final map = widget.mapBuilder?.call(visible) ?? _buildMap(visible);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(child: map),
          Positioned(top: 8, right: 8, child: _zoomControls()),
        ],
      ),
    );
  }

  Widget _zoomControls() {
    return Material(
      color: RealUnitColors.basic.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(Icons.add, S.of(context).payLocationsZoomIn, 1),
          _zoomButton(Icons.remove, S.of(context).payLocationsZoomOut, -1),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, String tooltip, double delta) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () => _zoomBy(delta),
      icon: Icon(icon, size: 20),
    );
  }

  Widget _buildMap(List<PayLocationPin> visible) {
    final selected = _selectedPin;
    final clustered = [
      for (final pin in visible)
        if (selected == null || !samePayLocationPin(pin, selected)) pin,
    ];
    final cell = payLocationClusterCellDegrees(_zoom);
    final clusters = clusterPayLocationPins(clustered, cellDegrees: cell);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(46.8, 8.23),
        initialZoom: 7,
        minZoom: 5,
        maxZoom: 16,
        initialCameraFit: CameraFit.bounds(bounds: _countryBounds, padding: const .all(28)),
        backgroundColor: RealUnitColors.brand200,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.pinchMove |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
        onMapEvent: _onMapEvent,
      ),
      children: [
        PolygonLayer(
          polygons: [
            for (final ring in payLocationCountryRings)
              Polygon(
                points: ring,
                color: RealUnitColors.basic.white,
                borderColor: RealUnitColors.neutral600,
                borderStrokeWidth: 1.2,
              ),
          ],
        ),
        PolygonLayer(
          polygons: [
            for (final ring in payLocationLakeRings)
              Polygon(
                points: ring,
                color: RealUnitColors.brand200,
                borderColor: RealUnitColors.realUnitBlue,
                borderStrokeWidth: 0.8,
              ),
          ],
        ),
        if (_zoom <= 9)
          MarkerLayer(
            markers: [
              for (final city in _cities)
                if (!payLocationCityCovered(
                  cityName: city.name,
                  cityLat: city.lat,
                  cityLon: city.lon,
                  zoom: _zoom,
                  clusters: clusters,
                  selected: selected,
                ))
                  _cityMarker(city),
            ],
          ),
        MarkerLayer(markers: [for (final cluster in clusters) ..._clusterMarkers(cluster)]),
        if (selected != null && visible.any((pin) => samePayLocationPin(pin, selected)))
          MarkerLayer(markers: _selectedMarkers(selected)),
      ],
    );
  }

  Marker _cityMarker(_CityLabel city) {
    return Marker(
      point: LatLng(city.lat, city.lon),
      width: 110,
      height: 16,
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            city.name,
            softWrap: false,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: RealUnitColors.neutral600,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _selectedMarkers(PayLocationPin pin) {
    final town = payLocationLabel(pin.name).town;
    return [
      Marker(
        point: LatLng(pin.lat, pin.lon),
        width: 18,
        height: 18,
        child: Semantics(
          button: true,
          selected: true,
          label: pin.name,
          child: GestureDetector(
            onTap: () => _selectPin(pin),
            child: Container(
              decoration: BoxDecoration(
                color: RealUnitColors.status.red600,
                shape: BoxShape.circle,
                border: Border.all(color: RealUnitColors.basic.white, width: 3),
              ),
            ),
          ),
        ),
      ),
      if (town.isNotEmpty) _townMarker(pin, town),
    ];
  }

  Widget _townPlate(String town) {
    return Material(
      color: RealUnitColors.basic.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 3),
        child: Text(
          town,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: RealUnitColors.neutral900,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<Marker> _clusterMarkers(PayLocationCluster cluster) {
    if (cluster.isSingle) {
      final pin = cluster.pins.single;
      final selected = _selectedPin != null && samePayLocationPin(pin, _selectedPin!);
      final size = selected ? 22.0 : 16.0;
      final town = payLocationLabel(pin.name).town;
      return [
        Marker(
          point: LatLng(pin.lat, pin.lon),
          width: size,
          height: size,
          child: Semantics(
            button: true,
            selected: selected,
            label: pin.name,
            child: GestureDetector(
              onTap: () => _selectPin(pin),
              child: Container(
                decoration: BoxDecoration(
                  color: RealUnitColors.status.red600,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: RealUnitColors.basic.white,
                    width: selected ? 3 : 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_zoom <= 7.5 && town.isNotEmpty) _townMarker(pin, town),
      ];
    }

    final count = cluster.pins.length;
    return [
      Marker(
        point: LatLng(cluster.lat, cluster.lon),
        width: 34,
        height: 34,
        child: Semantics(
          button: true,
          label: _countLabel(context, count),
          child: GestureDetector(
            onTap: () => _openCluster(cluster),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RealUnitColors.darkBlue,
                shape: BoxShape.circle,
                border: Border.all(color: RealUnitColors.basic.white, width: 2),
              ),
              child: Padding(
                padding: const .all(4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RealUnitColors.basic.white,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Marker _townMarker(PayLocationPin pin, String town) {
    return Marker(
      point: LatLng(pin.lat, pin.lon),
      width: 168,
      height: 36,
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: Padding(
          padding: const .only(bottom: 14),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _townPlate(town),
          ),
        ),
      ),
    );
  }

  void _openCluster(PayLocationCluster cluster) {
    if (!_mapReady) {
      return;
    }
    final bounds = LatLngBounds.fromPoints([
      for (final pin in cluster.pins) LatLng(pin.lat, pin.lon),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const .all(48), maxZoom: 14),
    );
  }
}
