import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';

class RouteService {
  // Using public OSRM server for development. 
  // For production, we should host our own OSRM instance.
  final String _baseUrl = 'https://router.project-osrm.org/route/v1';

  Future<RouteInfo?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final route = routes.first;
          final durationSeconds = route['duration'] as double;
          final distanceMeters = route['distance'] as double;
          
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          final points = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          return RouteInfo(
            points: points,
            distanceKm: distanceMeters / 1000,
            durationMin: durationSeconds / 60,
            estimatedPrice: _calculatePrice(distanceMeters),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
    return null;
  }

  // BlaBlaCar style estimation
  // Base fare + km rate
  double _calculatePrice(double distanceMeters) {
    const baseFare = 20.0;
    const perKmRate = 8.0; // Fuel sharing logic
    
    final distanceKm = distanceMeters / 1000;
    return baseFare + (distanceKm * perKmRate);
  }
}

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;
  final double estimatedPrice;

  RouteInfo({
    required this.points, 
    required this.distanceKm, 
    required this.durationMin,
    required this.estimatedPrice,
  });

  Polyline get polyline => Polyline(
    points: points,
    color: const Color(0xFF2F6B57),
    strokeWidth: 4.0,
  );
}
