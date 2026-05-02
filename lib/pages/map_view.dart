import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for rootBundle
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_viewer/models/trip_plan.dart';

class MapView extends StatefulWidget {
  final TripPlan tripPlan;

  const MapView({super.key, required this.tripPlan});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const _placePinImageName = 'place-pin';

  MapLibreMapController? _mapController;
  bool _mapInitialized = false;
  bool _coordinatesLoaded = false;
  List<GooglePlace> _allPlaces = [];
  final List<GooglePlace> _placesWithCoordinates = [];
  final Map<String, String> _annotationIdToPlaceId = {};
  GooglePlace? _selectedPlace;
  Symbol? _selectedAnnotation; // Added to track selected annotation
  final Map<String, Symbol> _placeIdToAnnotation =
      {}; // Added for placeId -> annotation mapping
  final List<LatLng> _placePoints = [];
  bool _isDrawingRoute = false;
  bool _pinImageAdded = false;
  Uint8List? _pinImageBytes; // Added state for pin image bytes

  LatLng _centerPoint = const LatLng(41.9028, 12.4964);

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
          final departPlace = block.depart.airport.googlePlace;
          final arrivePlace = block.arrive.airport.googlePlace;

          // Add depart airport place if not already added and has geometry
          if (departPlace != null &&
              !processedPlaceIds.contains(departPlace.placeId) &&
              departPlace.geometry != null) {
            places.add(departPlace);
            processedPlaceIds.add(departPlace.placeId);
          }
          // Set arrive airport place to be potentially added (if not already added and has geometry)
          placeToAdd = arrivePlace;
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

  LatLng? _getCoordinatesFromPlace(GooglePlace place) {
    if (place.geometry != null) {
      final location = place.geometry!.location;
      log('Using coordinates for "${place.name}": ${location.lat}, ${location.lng}');
      return LatLng(location.lat, location.lng);
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
        sumLat += coords.latitude;
        sumLng += coords.longitude;
      } else {
        log('Skipping place due to missing coordinates: ${place.name}');
      }
    }

    if (_placePoints.isNotEmpty) {
      _centerPoint = LatLng(
        sumLat / _placePoints.length,
        sumLng / _placePoints.length,
      );
      log("Calculated center point: ${_centerPoint.latitude}, ${_centerPoint.longitude} from ${_placePoints.length} places.");
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
        if (_mapController != null && _placePoints.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _centerPoint, zoom: 10.0),
            ),
            duration: const Duration(milliseconds: 1000),
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
        _mapController == null ||
        _placesWithCoordinates.isEmpty ||
        _pinImageBytes == null) {
      // Check if image is loaded
      log('Skipping addPlaceMarkers: Map Initialized: $_mapInitialized, Coords Loaded: $_coordinatesLoaded, Map Ready: ${_mapController != null}, Places > 0: ${_placesWithCoordinates.isNotEmpty}, Pin Image Loaded: ${_pinImageBytes != null}');
      return;
    }

    log('Adding ${_placePoints.length} place markers using image.');

    try {
      await _mapController!.clearSymbols();
      _annotationIdToPlaceId.clear();
      _placeIdToAnnotation.clear();

      if (!_pinImageAdded) {
        await _mapController!.addImage(_placePinImageName, _pinImageBytes!);
        _pinImageAdded = true;
      }

      List<SymbolOptions> optionsList = [];
      for (int i = 0; i < _placesWithCoordinates.length; i++) {
        if (i < _placePoints.length) {
          final point = _placePoints[i];
          optionsList.add(SymbolOptions(
            geometry: point,
            iconImage: _placePinImageName,
            iconSize: 1.0, // Adjust default size as needed
          ));
        } else {
          log('Warning: Mismatch between placesWithCoordinates (${_placesWithCoordinates.length}) and _placePoints (${_placePoints.length}) at index $i');
        }
      }

      final annotations = await _mapController!.addSymbols(optionsList);

      for (int i = 0; i < annotations.length; i++) {
        if (i < _placesWithCoordinates.length) {
          final annotation = annotations[i];
          final annotationId = annotation.id;
          final placeId = _placesWithCoordinates[i].placeId;
          _annotationIdToPlaceId[annotationId] = placeId;
          _placeIdToAnnotation[placeId] = annotation;
        }
      }
    } catch (e) {
      log('Error adding place markers: $e');
      _showErrorSnackbar('Could not display all place markers.');
    }
  }

  void _handleSymbolClick(Symbol annotation) {
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
    if (_mapController == null ||
        _placePoints.length < 2 ||
        !_coordinatesLoaded) {
      return;
    }

    setState(() {
      _isDrawingRoute = true;
    });

    try {
      await _mapController!.clearLines();

      final lineOptions = LineOptions(
        geometry: _placePoints,
        lineWidth: 3.0,
        lineColor: '#ff0000',
        lineOpacity: 0.7,
      );

      await _mapController!.addLine(lineOptions);
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
    if (_mapController == null || !_coordinatesLoaded) return;

    final placeId = place.placeId;
    int placeIndex = -1;

    for (int i = 0; i < _placesWithCoordinates.length; i++) {
      if (_placesWithCoordinates[i].placeId == placeId) {
        placeIndex = i;
        break;
      }
    }

    if (placeIndex >= 0 && placeIndex < _placePoints.length) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _placePoints[placeIndex], zoom: 14.0),
        ),
        duration: const Duration(milliseconds: 1000),
      );

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
      Symbol? newAnnotation, GooglePlace? newPlace) async {
    if (_mapController == null || _pinImageBytes == null) return;

    // Reset previous selection
    if (_selectedAnnotation != null && _selectedAnnotation != newAnnotation) {
      try {
        await _mapController!.updateSymbol(
          _selectedAnnotation!,
          const SymbolOptions(iconSize: 1.0),
        );
      } catch (e) {
        log("Error resetting previous annotation: $e");
      }
    }

    // Set new selection
    if (newAnnotation != null) {
      try {
        await _mapController!.updateSymbol(
          newAnnotation,
          const SymbolOptions(iconSize: 1.5),
        );
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
          MapLibreMap(
            key: const ValueKey('mapWidget'),
            styleString: MapLibreStyles.demo,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapIdle: _onMapIdle,
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(
              target: _centerPoint,
              zoom: 10.0,
            ),
          ),
          if (!_mapInitialized || !_coordinatesLoaded)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                if (_mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _centerPoint, zoom: 10.0),
                    ),
                    duration: const Duration(milliseconds: 1000),
                  );

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

  void _onMapCreated(MapLibreMapController mapController) async {
    _mapController = mapController;
    _mapController!.onSymbolTapped.add(_handleSymbolClick);
    log("MapLibre map created.");

    // Check if coordinates and image are ready
    if (_coordinatesLoaded && _pinImageBytes != null) {
      log("Map created after coordinates and image loaded, attempting initial setup.");
      _addPlaceMarkers(); // Add markers now if ready
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _centerPoint, zoom: 10.0),
        ),
      );
    } else {
      log("Map created, but coordinates or pin image are not loaded yet.");
    }
    if (mounted) {
      setState(
          () {}); // Update UI state (e.g., hide loading indicator if needed)
    }
  }

  void _onStyleLoaded() async {
    log("Event: Map style loaded.");

    _mapInitialized = true;
    _pinImageAdded = false;

    // Style loaded implies map is ready. Add markers if coordinates and image are ready.
    if (_coordinatesLoaded && _pinImageBytes != null) {
      log("Style loaded, coordinates and image ready. Adding markers.");
      _addPlaceMarkers();
    } else {
      log("Style loaded, but coordinates or pin image not ready yet.");
    }

    if (mounted) setState(() {});
  }

  void _onMapIdle() {
    log("Event: Map idle.");
    // Attempt to add markers if they haven't been added yet and everything is ready
    if (_placeIdToAnnotation.isEmpty &&
        _coordinatesLoaded &&
        _pinImageBytes != null) {
      log("Map idle, attempting to add markers again if missed.");
      _addPlaceMarkers();
    }
  }
}
