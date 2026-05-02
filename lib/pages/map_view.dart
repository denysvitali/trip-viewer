import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:url_launcher/url_launcher.dart';

class MapView extends StatefulWidget {
  final TripPlan tripPlan;

  const MapView({super.key, required this.tripPlan});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const _buildingLayerId = 'trip-viewer-3d-buildings';

  MapLibreMapController? _mapController;
  bool _mapInitialized = false;
  bool _showPoints = true;
  bool _showTripLine = true;
  bool _show3dBuildings = true;
  bool _myLocationEnabled = false;
  bool _isUpdatingRoute = false;
  bool _isLocatingUser = false;
  _OpenFreeMapStyle _selectedMapStyle = _OpenFreeMapStyle.bright;

  late final List<_MapPlace> _allPlaces;
  late final List<DateTime> _tripDays;
  DateTime? _selectedDay;

  final Map<String, String> _annotationIdToPlaceKey = {};
  final Map<String, Circle> _placeKeyToCircle = {};
  Circle? _selectedCircle;
  _MapPlace? _selectedPlace;

  LatLng _centerPoint = const LatLng(41.9028, 12.4964);

  List<_MapPlace> get _visiblePlaces {
    if (_selectedDay == null) return _allPlaces;
    return _allPlaces
        .where((place) => _isSameDay(place.date, _selectedDay))
        .toList();
  }

  List<LatLng> get _visiblePoints =>
      _visiblePlaces.map((p) => p.point).toList();

  @override
  void initState() {
    super.initState();
    _allPlaces = _extractPlaces();
    _tripDays = _extractTripDays();
    if (_tripDays.isNotEmpty) _selectedDay = null;
    _calculateCenter(_visiblePoints);
  }

  List<_MapPlace> _extractPlaces() {
    final places = <_MapPlace>[];
    var order = 0;

    for (final section in widget.tripPlan.itinerary.sections) {
      final sectionDate = _parseDate(section.date);
      for (final block in section.blocks) {
        if (block is PlaceBlock) {
          _addPlace(
            places,
            place: block.place,
            date: sectionDate,
            order: ++order,
            type:
                block.hotel == null ? _MapPlaceType.place : _MapPlaceType.hotel,
            time: block.startTime,
          );
        } else if (block is TransitBlock) {
          final departDate = _parseDate(block.depart.date) ?? sectionDate;
          final arriveDate = _parseDate(block.arrive.date) ?? sectionDate;
          _addPlace(
            places,
            place: block.depart.place,
            date: departDate,
            order: ++order,
            type: _MapPlaceType.transit,
            time: block.depart.time,
          );
          _addPlace(
            places,
            place: block.arrive.place,
            date: arriveDate,
            order: ++order,
            type: _MapPlaceType.transit,
            time: block.arrive.time,
          );
        } else if (block is FlightBlock) {
          final departPlace = block.depart.airport.googlePlace;
          final arrivePlace = block.arrive.airport.googlePlace;
          if (departPlace != null) {
            _addPlace(
              places,
              place: departPlace,
              date: _parseDate(block.depart.date) ?? sectionDate,
              order: ++order,
              type: _MapPlaceType.flight,
              time: block.depart.time,
            );
          }
          if (arrivePlace != null) {
            _addPlace(
              places,
              place: arrivePlace,
              date: _parseDate(block.arrive.date) ?? sectionDate,
              order: ++order,
              type: _MapPlaceType.flight,
              time: block.arrive.time,
            );
          }
        }
      }
    }

    return places;
  }

  void _addPlace(
    List<_MapPlace> places, {
    required GooglePlace place,
    required DateTime? date,
    required int order,
    required _MapPlaceType type,
    String? time,
  }) {
    final geometry = place.geometry;
    if (geometry == null) return;

    places.add(
      _MapPlace(
        key: '$order-${place.placeId}',
        place: place,
        point: LatLng(geometry.location.lat, geometry.location.lng),
        date: date,
        order: order,
        type: type,
        time: time,
      ),
    );
  }

  List<DateTime> _extractTripDays() {
    final days = <DateTime>{};
    for (final place in _allPlaces) {
      final date = place.date;
      if (date != null) days.add(DateTime(date.year, date.month, date.day));
    }
    return days.toList()..sort();
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _selectDay(DateTime? day) {
    setState(() {
      _selectedDay = day;
      _selectedPlace = null;
      _selectedCircle = null;
      _calculateCenter(_visiblePoints);
    });
    _refreshMapContent(fitCamera: true);
  }

  void _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return;
    final sum = points.fold<(double, double)>(
      (0, 0),
      (acc, point) => (acc.$1 + point.latitude, acc.$2 + point.longitude),
    );
    _centerPoint = LatLng(sum.$1 / points.length, sum.$2 / points.length);
  }

  Future<void> _refreshMapContent({bool fitCamera = false}) async {
    await _addPlaceMarkers();
    await _updateRouteLine();
    if (fitCamera) _fitVisiblePlaces();
  }

  Future<void> _add3dBuildings() async {
    if (!_show3dBuildings || _mapController == null) return;

    try {
      await _mapController!.addFillExtrusionLayer(
        'openmaptiles',
        _buildingLayerId,
        const FillExtrusionLayerProperties(
          fillExtrusionColor: [
            'interpolate',
            ['linear'],
            ['get', 'render_height'],
            0,
            '#d1d5db',
            200,
            '#60a5fa',
            400,
            '#bfdbfe',
          ],
          fillExtrusionHeight: [
            'interpolate',
            ['linear'],
            ['zoom'],
            15,
            0,
            16,
            ['get', 'render_height'],
          ],
          fillExtrusionBase: [
            'case',
            [
              '>=',
              ['get', 'zoom'],
              16,
            ],
            ['get', 'render_min_height'],
            0,
          ],
          fillExtrusionOpacity: 0.82,
          fillExtrusionVerticalGradient: true,
        ),
        sourceLayer: 'building',
        minzoom: 15,
        filter: [
          '!=',
          ['get', 'hide_3d'],
          true,
        ],
      );
    } catch (e) {
      log('Error adding 3D buildings: $e');
    }
  }

  Future<void> _addPlaceMarkers() async {
    if (!_mapInitialized || _mapController == null) {
      return;
    }

    try {
      await _mapController!.clearSymbols();
      await _mapController!.clearCircles();
      _annotationIdToPlaceKey.clear();
      _placeKeyToCircle.clear();

      if (!_showPoints) return;

      final visiblePlaces = _visiblePlaces;
      final circles = await _mapController!.addCircles(
        visiblePlaces
            .map(
              (place) => CircleOptions(
                geometry: place.point,
                circleRadius: _selectedPlace?.key == place.key ? 14 : 10,
                circleColor: place.markerColor,
                circleOpacity: 0.96,
                circleStrokeColor: '#ffffff',
                circleStrokeWidth: 3,
                circleStrokeOpacity: 1,
              ),
            )
            .toList(),
      );

      await _mapController!.addSymbols(
        visiblePlaces
            .map(
              (place) => SymbolOptions(
                geometry: place.point,
                textField: place.displayOrder,
                textColor: '#ffffff',
                textHaloColor: place.markerColor,
                textHaloWidth: 1,
                textSize: 11,
              ),
            )
            .toList(),
      );

      for (var i = 0; i < circles.length; i++) {
        final circle = circles[i];
        final place = visiblePlaces[i];
        _annotationIdToPlaceKey[circle.id] = place.key;
        _placeKeyToCircle[place.key] = circle;
      }
    } catch (e) {
      log('Error adding place markers: $e');
      _showErrorSnackbar('Could not display place markers.');
    }
  }

  Future<void> _updateRouteLine() async {
    if (_mapController == null || _isUpdatingRoute) return;

    setState(() => _isUpdatingRoute = true);
    try {
      await _mapController!.clearLines();
      final points = _visiblePoints;
      if (!_showTripLine || points.length < 2) return;

      await _mapController!.addLine(
        LineOptions(
          geometry: points,
          lineWidth: 4,
          lineColor: '#2563EB',
          lineOpacity: 0.78,
        ),
      );
    } catch (e) {
      log('Error updating route: $e');
      _showErrorSnackbar('Could not update the route line.');
    } finally {
      if (mounted) setState(() => _isUpdatingRoute = false);
    }
  }

  void _toggleTripLine() {
    setState(() => _showTripLine = !_showTripLine);
    _updateRouteLine();
  }

  void _togglePoints() {
    setState(() {
      _showPoints = !_showPoints;
      _selectedPlace = null;
      _selectedCircle = null;
    });
    _addPlaceMarkers();
  }

  void _setMapStyle(_OpenFreeMapStyle style) {
    if (_selectedMapStyle == style) return;
    setState(() {
      _selectedMapStyle = style;
      _mapInitialized = false;
      _selectedPlace = null;
      _selectedCircle = null;
    });
  }

  void _toggle3dBuildings() {
    setState(() {
      _show3dBuildings = !_show3dBuildings;
      _mapInitialized = false;
      _selectedPlace = null;
      _selectedCircle = null;
    });
  }

  Future<void> _showMyLocation() async {
    if (_isLocatingUser) return;

    setState(() => _isLocatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackbar('Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showErrorSnackbar('Location permission is required.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);

      if (mounted) setState(() => _myLocationEnabled = true);
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: point, zoom: 16, tilt: 45),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (e) {
      log('Error locating user: $e');
      _showErrorSnackbar('Could not show your location.');
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  void _handleCircleClick(Circle circle) {
    final placeKey = _annotationIdToPlaceKey[circle.id];
    if (placeKey == null) return;

    _MapPlace? place;
    for (final visiblePlace in _visiblePlaces) {
      if (visiblePlace.key == placeKey) {
        place = visiblePlace;
        break;
      }
    }

    final selectedCircle = _placeKeyToCircle[placeKey];
    if (place != null && selectedCircle != null) {
      _updateSelectedCircle(selectedCircle, place);
    }
  }

  Future<void> _updateSelectedCircle(
    Circle? newCircle,
    _MapPlace? newPlace,
  ) async {
    if (_mapController == null) return;

    if (_selectedCircle != null && _selectedCircle != newCircle) {
      await _mapController!.updateCircle(
        _selectedCircle!,
        const CircleOptions(circleRadius: 10),
      );
    }

    if (newCircle != null) {
      await _mapController!.updateCircle(
        newCircle,
        const CircleOptions(circleRadius: 14),
      );
    }

    if (mounted) {
      setState(() {
        _selectedCircle = newCircle;
        _selectedPlace = newPlace;
      });
    }
  }

  void _zoomToPlace(_MapPlace place) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: place.point, zoom: 15, tilt: 45),
      ),
      duration: const Duration(milliseconds: 500),
    );

    final circle = _placeKeyToCircle[place.key];
    _updateSelectedCircle(circle, place);
  }

  int get _selectedVisibleIndex {
    final selected = _selectedPlace;
    if (selected == null) return -1;
    return _visiblePlaces.indexWhere((place) => place.key == selected.key);
  }

  void _selectRelativePlace(int offset) {
    final places = _visiblePlaces;
    if (places.isEmpty) return;

    final selectedIndex = _selectedVisibleIndex;
    final baseIndex =
        selectedIndex == -1 ? (offset > 0 ? -1 : 0) : selectedIndex;
    final nextIndex = (baseIndex + offset).clamp(0, places.length - 1);
    _zoomToPlace(places[nextIndex]);
  }

  void _fitVisiblePlaces() {
    if (_mapController == null || _visiblePoints.isEmpty) return;

    if (_visiblePoints.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_visiblePoints.first, 14),
        duration: const Duration(milliseconds: 500),
      );
      return;
    }

    final bounds = _boundsForPoints(_visiblePoints);
    final topPadding = _tripDays.isEmpty ? 96.0 : 148.0;
    final bottomPadding = _selectedPlace == null ? 112.0 : 188.0;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 48,
        top: topPadding,
        right: 48,
        bottom: bottomPadding,
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  LatLngBounds _boundsForPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    const minSpan = 0.01;
    if ((maxLat - minLat).abs() < minSpan) {
      minLat -= minSpan / 2;
      maxLat += minSpan / 2;
    }
    if ((maxLng - minLng).abs() < minSpan) {
      minLng -= minSpan / 2;
      maxLng += minSpan / 2;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _openInMaps(GooglePlace place) async {
    final query =
        Uri.encodeComponent('${place.name}, ${place.formattedAddress}');
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (place.url != null) {
      final placeUri = Uri.parse(place.url!);
      if (await canLaunchUrl(placeUri)) {
        await launchUrl(placeUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    _showErrorSnackbar('Could not open maps application');
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePlaces = _visiblePlaces;
    final selectedIndex = _selectedVisibleIndex;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            key: ValueKey(
              'mapWidget-${_selectedMapStyle.name}-$_show3dBuildings',
            ),
            styleString: _selectedMapStyle.styleUrl,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(
              target: _centerPoint,
              zoom: 10,
              tilt: 35,
            ),
            compassEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationEnabled: _myLocationEnabled,
            myLocationRenderMode: _myLocationEnabled
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            annotationOrder: const [
              AnnotationType.line,
              AnnotationType.circle,
              AnnotationType.symbol,
              AnnotationType.fill,
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(context, visiblePlaces),
                  const SizedBox(height: 10),
                  if (_mapInitialized) _buildDayFilter(context),
                ],
              ),
            ),
          ),
          if (_mapInitialized) _buildLayerPanel(context, visiblePlaces),
          if (_mapInitialized) _buildMapActions(context, visiblePlaces),
          if (_mapInitialized && visiblePlaces.isNotEmpty)
            _buildPlaceDock(context, visiblePlaces, selectedIndex),
          if (!_mapInitialized)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, List<_MapPlace> visiblePlaces) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _MapButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DecoratedBox(
            decoration: _overlayDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.tripPlan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    visiblePlaces.isEmpty
                        ? 'No mapped places'
                        : '${visiblePlaces.length} visible places',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: _overlayDecoration(context),
          child: PopupMenuButton<_OpenFreeMapStyle>(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map style',
            onSelected: _setMapStyle,
            itemBuilder: (context) => _OpenFreeMapStyle.values
                .map(
                  (style) => CheckedPopupMenuItem<_OpenFreeMapStyle>(
                    value: style,
                    checked: style == _selectedMapStyle,
                    child: Text(style.label),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDayFilter(BuildContext context) {
    if (_tripDays.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: _overlayDecoration(context),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: _selectedDay == null,
                onSelected: (_) => _selectDay(null),
              ),
            ),
            ..._tripDays.map(
              (day) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ChoiceChip(
                  label: Text(DateFormat('EEE d').format(day)),
                  selected: _isSameDay(_selectedDay, day),
                  onSelected: (_) => _selectDay(day),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerPanel(BuildContext context, List<_MapPlace> visiblePlaces) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: DecoratedBox(
            decoration: _overlayDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _showPoints
                        ? Icons.location_on
                        : Icons.location_off_outlined,
                  ),
                  tooltip: _showPoints ? 'Hide points' : 'Show points',
                  onPressed: visiblePlaces.isEmpty ? null : _togglePoints,
                ),
                IconButton(
                  icon:
                      Icon(_showTripLine ? Icons.route : Icons.route_outlined),
                  tooltip: _showTripLine ? 'Hide trip line' : 'Show trip line',
                  onPressed: visiblePlaces.length < 2 || _isUpdatingRoute
                      ? null
                      : _toggleTripLine,
                ),
                IconButton(
                  icon: Icon(
                    _show3dBuildings
                        ? Icons.apartment
                        : Icons.apartment_outlined,
                  ),
                  tooltip: _show3dBuildings
                      ? 'Hide 3D buildings'
                      : 'Show 3D buildings',
                  onPressed: _toggle3dBuildings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapActions(BuildContext context, List<_MapPlace> visiblePlaces) {
    final bottomOffset = _selectedPlace == null ? 20.0 : 116.0;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(right: 12, bottom: bottomOffset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: _isLocatingUser ? null : Icons.my_location,
                tooltip: 'Show my location',
                onPressed: _isLocatingUser ? null : _showMyLocation,
                child: _isLocatingUser
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              if (visiblePlaces.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MapButton(
                  icon: Icons.zoom_out_map,
                  tooltip: 'Show visible places',
                  onPressed: () {
                    _updateSelectedCircle(null, null);
                    _fitVisiblePlaces();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceDock(
    BuildContext context,
    List<_MapPlace> visiblePlaces,
    int selectedIndex,
  ) {
    final selectedPlace =
        selectedIndex == -1 ? null : visiblePlaces[selectedIndex];

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 76, 12),
          child: DecoratedBox(
            decoration: _overlayDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous place',
                    onPressed: selectedIndex <= 0
                        ? null
                        : () => _selectRelativePlace(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: selectedPlace == null
                          ? () => _zoomToPlace(visiblePlaces.first)
                          : () => _zoomToPlace(selectedPlace),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: selectedPlace == null
                            ? Text(
                                'Tap to start place navigation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${selectedPlace.displayOrder}. ${selectedPlace.place.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    [
                                      if (selectedPlace.time != null &&
                                          selectedPlace.time!.isNotEmpty)
                                        selectedPlace.time!,
                                      selectedPlace.type.label,
                                      '${selectedIndex + 1}/${visiblePlaces.length}',
                                    ].join(' - '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions),
                    tooltip: 'Get directions',
                    onPressed: selectedPlace == null
                        ? null
                        : () => _openInMaps(selectedPlace.place),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next place',
                    onPressed: selectedIndex >= visiblePlaces.length - 1 &&
                            selectedIndex != -1
                        ? null
                        : () => _selectRelativePlace(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _overlayDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onCircleTapped.add(_handleCircleClick);
  }

  void _onStyleLoaded() {
    _mapInitialized = true;
    if (mounted) setState(() {});
    _add3dBuildings();
    _refreshMapContent(fitCamera: true);
  }
}

class _MapButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? child;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 48,
        child: IconButton(
          icon: child ?? Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

enum _OpenFreeMapStyle {
  bright('Bright', 'https://tiles.openfreemap.org/styles/bright'),
  liberty('Liberty', 'https://tiles.openfreemap.org/styles/liberty'),
  positron('Positron', 'https://tiles.openfreemap.org/styles/positron'),
  dark('Dark', 'https://tiles.openfreemap.org/styles/dark'),
  fiord('Fiord', 'https://tiles.openfreemap.org/styles/fiord');

  final String label;
  final String styleUrl;

  const _OpenFreeMapStyle(this.label, this.styleUrl);
}

class _MapPlace {
  final String key;
  final GooglePlace place;
  final LatLng point;
  final DateTime? date;
  final int order;
  final _MapPlaceType type;
  final String? time;

  const _MapPlace({
    required this.key,
    required this.place,
    required this.point,
    required this.date,
    required this.order,
    required this.type,
    this.time,
  });

  String get displayOrder => order.toString();

  String get markerColor {
    switch (type) {
      case _MapPlaceType.hotel:
        return '#7C3AED';
      case _MapPlaceType.transit:
        return '#059669';
      case _MapPlaceType.flight:
        return '#EA580C';
      case _MapPlaceType.place:
        return '#2563EB';
    }
  }
}

enum _MapPlaceType {
  place('Place'),
  hotel('Hotel'),
  transit('Transit'),
  flight('Flight');

  final String label;

  const _MapPlaceType(this.label);
}
