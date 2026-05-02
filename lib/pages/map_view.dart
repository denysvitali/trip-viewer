import 'dart:developer';
import 'dart:typed_data'; // Import for Uint8List

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for rootBundle
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_viewer/models/trip_plan.dart';

// Moved class outside _MapViewState
class OnPointAnnotationClickListenerImpl
    extends OnPointAnnotationClickListener {
  // Renamed field to avoid conflict with superclass method
  final bool Function(PointAnnotation) _onPointAnnotationClickCallback;

  OnPointAnnotationClickListenerImpl(
      {required bool Function(PointAnnotation) onPointAnnotationClick})
      : _onPointAnnotationClickCallback = onPointAnnotationClick;

  // Corrected method name and signature to match superclass
  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    // Call the callback, ignore the boolean return value as the superclass method is void
    _onPointAnnotationClickCallback(annotation);
  }
}

class MapView extends StatefulWidget {
  final TripPlan tripPlan;

  const MapView({super.key, required this.tripPlan});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapboxMap? _mapboxMap;
  bool _mapInitialized = false;
  bool _coordinatesLoaded = false;
  List<GooglePlace> _allPlaces = [];
  List<GooglePlace> _placesWithCoordinates = [];
  PointAnnotationManager? _pointAnnotationManager;
  Map<String, String> _annotationIdToPlaceId = {};
  PolylineAnnotationManager? _polylineManager;
  GooglePlace? _selectedPlace;
  PointAnnotation? _selectedAnnotation; // Added to track selected annotation
  Map<String, PointAnnotation> _placeIdToAnnotation =
      {}; // Added for placeId -> annotation mapping
  final List<Point> _placePoints = [];
  bool _isDrawingRoute = false;
  Uint8List? _pinImageBytes; // Added state for pin image bytes

  Point _centerPoint = Point(coordinates: Position(12.4964, 41.9028));

  @override
  void initState() {
    super.initState();
    _loadPinImage(); // Load the pin image
    _allPlaces = _extractAllPlaces();
    _checkLocationPermission();
    _fetchPlaceCoordinatesAndCalculateCenter();
  }

  // Method to load the pin image asset
  Future<void> _loadPinImage() async {
    try {
      final ByteData byteData =
          await rootBundle.load('assets/images/map_pin.png');
      _pinImageBytes = byteData.buffer.asUint8List();
      log("Pin image loaded successfully.");
      // If map is already initialized and coordinates loaded when image loads, refresh markers
      if (_mapInitialized && _coordinatesLoaded) {
        _addPlaceMarkers();
      }
    } catch (e) {
      log("Error loading pin image: $e");
      _showErrorSnackbar("Could not load map pin image.");
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      log('Error checking location permission: $e');
    }
  }

  List<GooglePlace> _extractAllPlaces() {
    final places = <GooglePlace>[];
    final processedPlaceIds = <String>{};

    for (final section in widget.tripPlan.itinerary.sections) {
      for (final block in section.blocks) {
        GooglePlace? placeToAdd;
        if (block is PlaceBlock) {
          placeToAdd = block.place;
        } else if (block is TransitBlock) {
          // Add depart place if not already added and has geometry
          if (!processedPlaceIds.contains(block.depart.place.placeId) &&
              block.depart.place.geometry != null) {
            places.add(block.depart.place);
            processedPlaceIds.add(block.depart.place.placeId);
          }
          // Set arrive place to be potentially added (if not already added and has geometry)
          placeToAdd = block.arrive.place;
        } else if (block is FlightBlock) {
          // Add depart airport place if not already added and has geometry
          if (!processedPlaceIds
                  .contains(block.depart.airport.googlePlace.placeId) &&
              block.depart.airport.googlePlace.geometry != null) {
            places.add(block.depart.airport.googlePlace);
            processedPlaceIds.add(block.depart.airport.googlePlace.placeId);
          }
          // Set arrive airport place to be potentially added (if not already added and has geometry)
          placeToAdd = block.arrive.airport.googlePlace;
        }

        // Add the place if it's valid, has geometry, and hasn't been added yet
        if (placeToAdd != null &&
            !processedPlaceIds.contains(placeToAdd.placeId) &&
            placeToAdd.geometry != null) {
          places.add(placeToAdd);
          processedPlaceIds.add(placeToAdd.placeId);
        }
      }
    }
    log("Extracted ${places.length} places with geometry.");
    return places;
  }

  Point? _getCoordinatesFromPlace(GooglePlace place) {
    if (place.geometry != null) {
      final location = place.geometry!.location;
      log('Using coordinates for "${place.name}": ${location.lat}, ${location.lng}');
      return Point(coordinates: Position(location.lng, location.lat));
    } else {
      log('No geometry information for place: ${place.name} (${place.placeId})');
      return null;
    }
  }

  Future<void> _fetchPlaceCoordinatesAndCalculateCenter() async {
    if (_allPlaces.isEmpty) {
      log("No places extracted, skipping coordinate fetching.");
      if (mounted) {
        setState(() {
          _coordinatesLoaded = true; // Mark as loaded even if no places
        });
      }
      return;
    }

    _placePoints.clear();
    _placesWithCoordinates.clear();

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (final place in _allPlaces) {
      final coords = _getCoordinatesFromPlace(place);
      if (coords != null) {
        _placesWithCoordinates.add(place);
        _placePoints.add(coords);
        sumLat += coords.coordinates.lat;
        sumLng += coords.coordinates.lng;
      } else {
        log('Skipping place due to missing coordinates: ${place.name}');
      }
    }

    if (_placePoints.isNotEmpty) {
      _centerPoint = Point(
          coordinates: Position(
              sumLng / _placePoints.length, sumLat / _placePoints.length));
      log("Calculated center point: ${_centerPoint.coordinates.lat}, ${_centerPoint.coordinates.lng} from ${_placePoints.length} places.");
    } else {
      log('No valid coordinates found for any place. Using default center.');
    }

    if (mounted) {
      setState(() {
        _coordinatesLoaded = true;
      });
      // Check if pin image is also loaded before adding markers
      if (_mapInitialized && _pinImageBytes != null) {
        log("Coordinates loaded, map initialized, pin image loaded. Adding markers and flying to center.");
        _addPlaceMarkers();
        if (_mapboxMap != null && _placePoints.isNotEmpty) {
          _mapboxMap!.flyTo(
            CameraOptions(center: _centerPoint, zoom: 10.0),
            MapAnimationOptions(duration: 1000),
          );
        }
      } else {
        log("Coordinates loaded, but map or pin image not ready yet.");
      }
    }
  }

  Future<void> _addPlaceMarkers() async {
    // Add check for pin image bytes
    if (!_mapInitialized ||
        !_coordinatesLoaded ||
        _mapboxMap == null ||
        _placesWithCoordinates.isEmpty ||
        _pinImageBytes == null) {
      // Check if image is loaded
      log('Skipping addPlaceMarkers: Map Initialized: $_mapInitialized, Coords Loaded: $_coordinatesLoaded, Map Ready: ${_mapboxMap != null}, Places > 0: ${_placesWithCoordinates.isNotEmpty}, Pin Image Loaded: ${_pinImageBytes != null}');
      return;
    }

    log('Adding ${_placePoints.length} place markers using image.');

    try {
      await _pointAnnotationManager?.deleteAll();
      _annotationIdToPlaceId.clear();
      _placeIdToAnnotation.clear();

      _pointAnnotationManager ??=
          await _mapboxMap!.annotations.createPointAnnotationManager();

      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        OnPointAnnotationClickListenerImpl(
          onPointAnnotationClick: (annotation) {
            _handlePointAnnotationClick(annotation);
            return true;
          },
        ),
      );

      List<PointAnnotationOptions> optionsList = [];
      for (int i = 0; i < _placesWithCoordinates.length; i++) {
        if (i < _placePoints.length) {
          final point = _placePoints[i];
          optionsList.add(PointAnnotationOptions(
            geometry: point,
            image: _pinImageBytes, // Use the loaded image bytes
            iconSize: 1.0, // Adjust default size as needed
            // Removed textField, textSize, textColor
            // iconColor might be used for tinting, keep for selection logic for now
          ));
        } else {
          log('Warning: Mismatch between placesWithCoordinates (${_placesWithCoordinates.length}) and _placePoints (${_placePoints.length}) at index $i');
        }
      }

      final annotations =
          await _pointAnnotationManager?.createMulti(optionsList);

      if (annotations != null) {
        for (int i = 0; i < annotations.length; i++) {
          if (i < _placesWithCoordinates.length) {
            final annotation = annotations[i];
            if (annotation == null) {
              log('Warning: Annotation at index $i is null.');
              continue;
            }
            final annotationId = annotation.id;
            final placeId = _placesWithCoordinates[i].placeId;
            _annotationIdToPlaceId[annotationId] = placeId;
            _placeIdToAnnotation[placeId] = annotation;
          }
        }
      }
    } catch (e) {
      log('Error adding place markers: $e');
      _showErrorSnackbar('Could not display all place markers.');
    }
  }

  void _handlePointAnnotationClick(PointAnnotation annotation) {
    final annotationId = annotation.id;

    final placeId = _annotationIdToPlaceId[annotationId];
    if (placeId != null) {
      try {
        final place = _placesWithCoordinates.firstWhere(
          (p) => p.placeId == placeId,
        );
        final clickedAnnotation = _placeIdToAnnotation[placeId];
        if (clickedAnnotation != null) {
          _updateSelectedAnnotation(clickedAnnotation, place); // Use helper
        } else {
          log('Could not find annotation object for place ID $placeId');
          // Fallback: update state without visual change
          setState(() {
            _selectedPlace = place;
          });
        }
      } catch (e) {
        log('Error finding place for annotation ID $annotationId (Place ID: $placeId): $e');
      }
    } else {
      log('Clicked annotation $annotationId has no associated placeId.');
    }
  }

  void _drawRouteBetweenPlaces() async {
    if (_mapboxMap == null || _placePoints.length < 2 || !_coordinatesLoaded)
      return;

    setState(() {
      _isDrawingRoute = true;
    });

    try {
      _polylineManager ??=
          await _mapboxMap!.annotations.createPolylineAnnotationManager();

      await _polylineManager?.deleteAll();

      final coordinates = _placePoints.map((p) => p.coordinates).toList();
      final lineOptions = PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineWidth: 3.0,
        lineColor: Colors.red.value,
        lineOpacity: 0.7,
      );

      await _polylineManager?.create(lineOptions);
    } catch (e) {
      log('Error drawing route: $e');
      _showErrorSnackbar('Could not draw the route.');
    } finally {
      if (mounted) {
        setState(() {
          _isDrawingRoute = false;
        });
      }
    }
  }

  void _zoomToPlace(GooglePlace place) {
    if (_mapboxMap == null || !_coordinatesLoaded) return;

    final placeId = place.placeId;
    int placeIndex = -1;

    for (int i = 0; i < _placesWithCoordinates.length; i++) {
      if (_placesWithCoordinates[i].placeId == placeId) {
        placeIndex = i;
        break;
      }
    }

    if (placeIndex >= 0 && placeIndex < _placePoints.length) {
      final cameraOptions = CameraOptions(
        center: _placePoints[placeIndex],
        zoom: 14.0,
      );

      _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1000));

      // Find annotation and update selection visual
      final annotationToSelect = _placeIdToAnnotation[placeId];
      if (annotationToSelect != null) {
        _updateSelectedAnnotation(annotationToSelect, place); // Use helper
      } else {
        log('Could not find annotation object for place ID $placeId during zoom');
        // Fallback: update state without visual change
        setState(() {
          _selectedPlace = place;
        });
      }
    } else {
      log('Could not find coordinates to zoom for place: ${place.name}');
      _showErrorSnackbar('Could not find coordinates for this place.');
    }
  }

  // Helper method to update annotation visuals and state
  Future<void> _updateSelectedAnnotation(
      PointAnnotation? newAnnotation, GooglePlace? newPlace) async {
    if (_pointAnnotationManager == null || _pinImageBytes == null) return;

    // Reset previous selection
    if (_selectedAnnotation != null && _selectedAnnotation != newAnnotation) {
      try {
        // Reset tint and size. Keep the image.
        _selectedAnnotation!.iconImage =
            null; // Workaround: Seems needed sometimes before updating color/size
        _selectedAnnotation!.image = _pinImageBytes;
        _selectedAnnotation!.iconColor =
            null; // Reset tint (or use default color if needed)
        _selectedAnnotation!.iconSize = 1.0; // Default size
        await _pointAnnotationManager!.update(_selectedAnnotation!);
      } catch (e) {
        log("Error resetting previous annotation: $e");
      }
    }

    // Set new selection
    if (newAnnotation != null) {
      try {
        // Apply tint and size. Keep the image.
        newAnnotation.iconImage = null; // Workaround
        newAnnotation.image = _pinImageBytes;
        newAnnotation.iconColor = Colors.red.value; // Selected tint color
        newAnnotation.iconSize = 1.5; // Make it larger
        await _pointAnnotationManager!.update(newAnnotation);
      } catch (e) {
        log("Error updating selected annotation: $e");
      }
    }

    // Update state
    if (_selectedPlace != newPlace || _selectedAnnotation != newAnnotation) {
      setState(() {
        _selectedAnnotation = newAnnotation;
        _selectedPlace = newPlace;
      });
    }
  }

  Future<void> _openInMaps(GooglePlace place) async {
    try {
      final name = Uri.encodeComponent(place.name);
      final address = Uri.encodeComponent(place.formattedAddress);

      final googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$name,$address';
      final googleUri = Uri.parse(googleMapsUrl);

      if (await canLaunchUrl(googleUri)) {
        await launchUrl(googleUri, mode: LaunchMode.externalApplication);
      } else if (place.url != null) {
        final placeUri = Uri.parse(place.url!);
        if (await canLaunchUrl(placeUri)) {
          await launchUrl(placeUri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackbar('Could not open maps application');
        }
      } else {
        _showErrorSnackbar('Could not open maps application');
      }
    } catch (e) {
      _showErrorSnackbar('Error opening maps: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placesToShow = _placesWithCoordinates;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripPlan.title} - Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.route),
            tooltip: 'Show Route',
            onPressed: (_isDrawingRoute || _placePoints.length < 2)
                ? null
                : _drawRouteBetweenPlaces,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri:
                MapboxStyles.STANDARD_EXPERIMENTAL, // Added default style URI
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: _onMapIdle,
            onRenderFrameFinishedListener: _onRenderFrameFinished,
            cameraOptions: CameraOptions(
              center: _centerPoint,
              zoom: 10.0,
            ),
          ),
          if (!_mapInitialized || !_coordinatesLoaded)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      !_mapInitialized
                          ? 'Initializing map...'
                          : 'Fetching coordinates...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (_mapInitialized && _coordinatesLoaded)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.1,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0)
                            .copyWith(top: 8),
                        child: Text(
                          'Places (${placesToShow.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (placesToShow.isEmpty && _allPlaces.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Could not find coordinates for any places in this trip.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        )
                      else if (placesToShow.isEmpty && _allPlaces.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No places found in this trip.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            itemCount: placesToShow.length,
                            itemBuilder: (context, index) {
                              final place = placesToShow[index];
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(place.name),
                                subtitle: Text(place.formattedAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => _zoomToPlace(place),
                                trailing: IconButton(
                                  icon: const Icon(Icons.directions),
                                  onPressed: () => _openInMaps(place),
                                  tooltip: 'Get directions',
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _mapInitialized && _coordinatesLoaded
          ? FloatingActionButton(
              onPressed: () {
                if (_mapboxMap != null) {
                  final cameraOptions = CameraOptions(
                    center: _centerPoint,
                    zoom: 10.0,
                  );
                  _mapboxMap!.flyTo(
                      cameraOptions, MapAnimationOptions(duration: 1000));

                  // Clear selection visual and state
                  _updateSelectedAnnotation(null, null); // Use helper
                }
              },
              tooltip: 'Show All Places',
              child: const Icon(Icons.zoom_out_map),
            )
          : null,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    log("Mapbox map created.");
    _mapInitialized = true; // Set initialized flag

    // Check if coordinates and image are ready
    if (_coordinatesLoaded && _pinImageBytes != null) {
      log("Map created after coordinates and image loaded, attempting initial setup.");
      _addPlaceMarkers(); // Add markers now if ready
      _mapboxMap?.flyTo(
        CameraOptions(center: _centerPoint, zoom: 10.0),
        MapAnimationOptions(duration: 0), // Fly immediately
      );
    } else {
      log("Map created, but coordinates or pin image are not loaded yet.");
    }
    if (mounted)
      setState(
          () {}); // Update UI state (e.g., hide loading indicator if needed)
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    log("Event: Map style loaded.");

    // Enable the location puck
    if (_mapboxMap != null) {
      try {
        await _mapboxMap!.location
            .updateSettings(LocationComponentSettings(enabled: true));
        log("Location puck enabled.");
      } catch (e) {
        log("Error enabling location puck: $e");
        // Optionally show a snackbar if enabling fails
        // _showErrorSnackbar("Could not show current location.");
      }
    }

    // Style loaded implies map is ready. Add markers if coordinates and image are ready.
    if (_coordinatesLoaded && _pinImageBytes != null) {
      log("Style loaded, coordinates and image ready. Adding markers.");
      _addPlaceMarkers();
      // Optionally flyTo center again if needed, though might have happened in onMapCreated
      // _mapboxMap?.flyTo(...)
    } else {
      log("Style loaded, but coordinates or pin image not ready yet.");
    }
  }

  void _onMapIdle(MapIdleEventData data) {
    log("Event: Map idle.");
    // Attempt to add markers if they haven't been added yet and everything is ready
    if (_pointAnnotationManager == null &&
        _coordinatesLoaded &&
        _pinImageBytes != null) {
      log("Map idle, attempting to add markers again if missed.");
      _addPlaceMarkers();
    }
  }

  void _onRenderFrameFinished(RenderFrameFinishedEventData data) {}
}
