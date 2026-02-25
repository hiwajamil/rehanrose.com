import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../../../firebase_options.dart';

/// Default center (e.g. Iraq) when location is unavailable.
const double _defaultLat = 33.3152;
const double _defaultLng = 44.3661;
const double _defaultZoom = 14.0;

/// Firebase Functions region for Places proxy (must match functions/index.js).
const String _placesProxyRegion = 'europe-west1';

/// Base URL for Places proxy (used on web to avoid CORS). Null when not using proxy.
String? get _placesProxyBaseUrl {
  if (!kIsWeb) return null;
  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
  return 'https://$_placesProxyRegion-$projectId.cloudfunctions.net';
}

/// Google Places API key (used on mobile; on web we use the proxy).
const String _placesApiKey = 'AIzaSyA56HwxP_2za24pqTKG9wfZ8MdeGt2GOqY';

/// Debounce delay (ms) before calling Places Autocomplete.
const int _autocompleteDebounceMs = 400;

/// Max height of the predictions list.
const double _predictionsListMaxHeight = 220;

/// Single prediction from Places Autocomplete.
class _PlacePrediction {
  const _PlacePrediction({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

/// Full-screen map picker: user moves the map; a fixed pin stays in the center.
/// Returns the [LatLng] of the center when "Confirm Location" is tapped.
Future<LatLng?> showDeliveryMapPicker(BuildContext context) async {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute<LatLng>(
      builder: (context) => const DeliveryMapPickerPage(),
      fullscreenDialog: true,
    ),
  );
}

class DeliveryMapPickerPage extends StatefulWidget {
  const DeliveryMapPickerPage({super.key});

  @override
  State<DeliveryMapPickerPage> createState() => _DeliveryMapPickerPageState();
}

class _DeliveryMapPickerPageState extends State<DeliveryMapPickerPage> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(_defaultLat, _defaultLng);
  double _zoom = _defaultZoom;
  bool _isLoadingLocation = true;
  String? _locationError;

  // Places search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<_PlacePrediction> _predictions = [];
  Timer? _debounceTimer;
  bool _placesLoading = false;
  String? _placesError;

  @override
  void initState() {
    super.initState();
    _requestAndMoveToCurrentLocation();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _placesError = null;
    if (value.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _placesLoading = false;
      });
      return;
    }
    setState(() => _placesLoading = true);
    _debounceTimer = Timer(
      const Duration(milliseconds: _autocompleteDebounceMs),
      () => _fetchAutocomplete(value.trim()),
    );
  }

  Future<void> _fetchAutocomplete(String input) async {
    if (input.isEmpty) {
      if (mounted) {
        setState(() {
          _predictions = [];
          _placesLoading = false;
        });
      }
      return;
    }
    try {
      final lat = _center.latitude;
      final lng = _center.longitude;
      final Uri uri;
      final base = _placesProxyBaseUrl;
      if (base != null) {
        uri = Uri.parse('$base/placesAutocomplete').replace(
          queryParameters: {
            'input': input,
            'lat': lat.toString(),
            'lng': lng.toString(),
          },
        );
      } else {
        uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(input)}'
          '&key=$_placesApiKey'
          '&location=$lat,$lng'
          '&radius=50000',
        );
      }
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        String message = 'Could not load suggestions.';
        if (response.statusCode == 502 && base != null) {
          message = 'Search service temporarily unavailable. Try again.';
        }
        setState(() {
          _predictions = [];
          _placesLoading = false;
          _placesError = message;
        });
        return;
      }
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>?;
      } on FormatException {
        if (mounted) {
          setState(() {
            _predictions = [];
            _placesLoading = false;
            _placesError = 'Invalid response from search. Please try again.';
          });
        }
        return;
      }
      if (json == null) {
        setState(() {
          _predictions = [];
          _placesLoading = false;
        });
        return;
      }
      final status = json['status'] as String?;
      if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _predictions = [];
          _placesLoading = false;
          _placesError = 'Search unavailable. Please try again.';
        });
        return;
      }
      final list = json['predictions'] as List<dynamic>? ?? [];
      final predictions = list
          .map((e) {
            final map = e is Map<String, dynamic> ? e : null;
            if (map == null) return null;
            final placeId = map['place_id'] as String?;
            final description = map['description'] as String?;
            if (placeId == null || description == null) return null;
            return _PlacePrediction(placeId: placeId, description: description);
          })
          .whereType<_PlacePrediction>()
          .toList();
      setState(() {
        _predictions = predictions;
        _placesLoading = false;
        _placesError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictions = [];
          _placesLoading = false;
          _placesError = kIsWeb && _placesProxyBaseUrl != null
              ? 'Search unavailable. Check connection or try again later.'
              : 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<void> _onPredictionSelected(_PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = [];
      _searchController.text = prediction.description;
      _placesError = null;
    });
    try {
      final Uri uri;
      final base = _placesProxyBaseUrl;
      if (base != null) {
        uri = Uri.parse('$base/placeDetails').replace(
          queryParameters: {'place_id': prediction.placeId},
        );
      } else {
        uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${Uri.encodeComponent(prediction.placeId)}'
          '&fields=geometry,name'
          '&key=$_placesApiKey',
        );
      }
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() => _placesError = 'Could not get place details.');
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      if (status != null && status != 'OK') {
        setState(() => _placesError = 'Could not load place.');
        return;
      }
      final result = data?['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        setState(() => _placesError = 'Invalid place location.');
        return;
      }
      final newCenter = LatLng(lat, lng);
      if (mounted) {
        setState(() {
          _center = newCenter;
          _zoom = 16.0;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newCenter, 16.0),
        );
      }
    } on FormatException {
      if (mounted) setState(() => _placesError = 'Could not load place.');
    } catch (e) {
      if (mounted) {
        setState(() => _placesError = 'Could not load place.');
      }
    }
  }

  Future<void> _requestAndMoveToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location services are disabled.';
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location permission denied.';
        });
      }
      return;
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location permission denied.';
        });
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        final newCenter = LatLng(position.latitude, position.longitude);
        setState(() {
          _center = newCenter;
          _zoom = 16.0;
          _isLoadingLocation = false;
          _locationError = null;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newCenter, 16.0),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Could not get location.';
        });
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
    _zoom = position.zoom;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_center, _zoom),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _confirmLocation() {
    Navigator.of(context).pop(_center);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _predictions = [];
      _placesError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final topPadding = padding.top;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Select Delivery Location'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: _zoom,
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            // Fixed center pin (map moves under it)
            Center(
              child: IgnorePointer(
                child: Icon(
                  Icons.location_on,
                  size: 56,
                  color: AppColors.rosePrimary,
                ),
              ),
            ),
            // Floating search bar and predictions at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16 + padding.left,
                  topPadding + 8,
                  16 + padding.right,
                  8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      elevation: 4,
                      shadowColor: AppColors.shadow,
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surface,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search for an address or place…',
                          hintStyle: TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.inkMuted,
                            size: 22,
                          ),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (_, value, __) {
                                if (value.text.isEmpty) return const SizedBox.shrink();
                                return IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: AppColors.inkMuted,
                                    size: 20,
                                  ),
                                  onPressed: _clearSearch,
                                );
                              },
                            ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_placesError != null) ...[
                      const SizedBox(height: 6),
                      Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _placesError!,
                                  style: TextStyle(
                                    color: AppColors.inkMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_predictions.isNotEmpty || _placesLoading) ...[
                      const SizedBox(height: 8),
                      Material(
                        elevation: 4,
                        shadowColor: AppColors.shadow,
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: _predictionsListMaxHeight,
                          ),
                          child: _placesLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: _predictions.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    indent: 48,
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final p = _predictions[index];
                                    return ListTile(
                                      leading: Icon(
                                        Icons.place_outlined,
                                        size: 22,
                                        color: AppColors.rosePrimary,
                                      ),
                                      title: Text(
                                        p.description,
                                        style: TextStyle(
                                          color: AppColors.ink,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _onPredictionSelected(p),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoadingLocation)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Getting your location…',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_locationError != null && !_isLoadingLocation)
              Positioned(
                top: topPadding + 80,
                left: 16,
                right: 16,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _locationError!,
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: AppColors.ink,
                      elevation: 4,
                      shadowColor: AppColors.shadow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
