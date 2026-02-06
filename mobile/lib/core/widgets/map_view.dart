import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class MapView extends StatefulWidget {
  final LatLng initialPosition;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final bool isSelecting;
  final Function(LatLng)? onLocationSelected;

  const MapView({
    super.key,
    this.initialPosition = const LatLng(41.0082, 28.9784), // Istanbul
    this.markers = const [],
    this.polylines = const [],
    this.isSelecting = false,
    this.onLocationSelected,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialPosition,
        initialZoom: 13.0,
        onTap: widget.isSelecting && widget.onLocationSelected != null
            ? (_, latLng) => widget.onLocationSelected!(latLng)
            : null,
        backgroundColor: AppColors.background, // Match app background until tiles load
      ),
      children: [
        // 1. Tile Layer - CartoDB Dark Matter (No API Key required)
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.ridesharing_app',
          maxNativeZoom: 19,
          maxZoom: 19,
          // Error handling for failed tile loads
          errorImage: const AssetImage('assets/images/tile_error.png'),
          // Fallback behavior - tiles will show background color if they fail
          fallbackUrl: null, // No fallback URL, will use background color
        ),

        // 2. Route Layer
        PolylineLayer(
          polylines: widget.polylines.map((p) {
             // Convert generic Polyline to flutter_map Polyline if needed
             // But we are passing flutter_map Polylines directly in Home
             return p;
          }).toList(),
        ),

        // 3. Markers Layer
        MarkerLayer(
          markers: widget.markers,
        ),
      ],
    );
  }
}
