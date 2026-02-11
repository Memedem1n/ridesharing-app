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
  final bool autoFit;
  final EdgeInsets fitPadding;

  const MapView({
    super.key,
    this.initialPosition = const LatLng(41.0082, 28.9784), // Istanbul
    this.markers = const [],
    this.polylines = const [],
    this.isSelecting = false,
    this.onLocationSelected,
    this.autoFit = true,
    this.fitPadding = const EdgeInsets.all(24),
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapController _mapController;
  String? _lastFitSignature;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _scheduleAutoFit();
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.autoFit || widget.isSelecting) return;
    if (widget.markers.isEmpty && widget.polylines.isEmpty) return;
    _scheduleAutoFit();
  }

  List<LatLng> _collectFitPoints() {
    final points = <LatLng>[];
    points.addAll(widget.markers.map((m) => m.point));
    for (final polyline in widget.polylines) {
      points.addAll(polyline.points);
    }
    return points;
  }

  CameraFit? _buildInitialCameraFit() {
    if (!widget.autoFit || widget.isSelecting) return null;
    final points = _collectFitPoints();
    if (points.length < 2) return null;
    final bounds = LatLngBounds.fromPoints(points);
    return CameraFit.bounds(
      bounds: bounds,
      padding: widget.fitPadding,
    );
  }

  void _scheduleAutoFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.autoFit || widget.isSelecting) return;

      final points = _collectFitPoints();
      if (points.length < 2) return;

      final bounds = LatLngBounds.fromPoints(points);
      final signature =
          '${bounds.southWest.latitude.toStringAsFixed(5)}|${bounds.southWest.longitude.toStringAsFixed(5)}|${bounds.northEast.latitude.toStringAsFixed(5)}|${bounds.northEast.longitude.toStringAsFixed(5)}|${points.length}';
      if (_lastFitSignature == signature) return;
      _lastFitSignature = signature;

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: widget.fitPadding,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialPosition,
        initialZoom: 13.0,
        initialCameraFit: _buildInitialCameraFit(),
        onTap: widget.isSelecting && widget.onLocationSelected != null
            ? (_, latLng) => widget.onLocationSelected!(latLng)
            : null,
        backgroundColor:
            AppColors.background, // Match app background until tiles load
      ),
      children: [
        // 1. Tile Layer - OpenStreetMap standard tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yoliva.app',
          maxNativeZoom: 19,
          maxZoom: 19,
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
