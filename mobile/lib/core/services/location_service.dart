import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';

class LocationSuggestion {
  final String displayName;
  final String city;
  final double lat;
  final double lon;

  const LocationSuggestion({
    required this.displayName,
    required this.city,
    required this.lat,
    required this.lon,
  });
}

class LocationService {
  LocationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<LocationSuggestion>> search(String query) async {
    if (query.trim().length < 2) return [];

    final uri = kIsWeb
        ? Uri.parse('$baseUrl/locations/search')
            .replace(queryParameters: {'q': query})
        : Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'jsonv2',
            'q': query,
            'addressdetails': '1',
            'limit': '6',
            'countrycodes': 'tr',
            'accept-language': 'tr',
          });

    final headers = <String, String>{
      'Accept': 'application/json',
    };
    // Browsers do not allow custom User-Agent headers.
    if (!kIsWeb) {
      headers['User-Agent'] = 'yoliva-ridesharing/1.0 (local-dev)';
    }

    late final http.Response response;
    try {
      response = await _client.get(uri, headers: headers);
    } catch (_) {
      return [];
    }

    if (response.statusCode != 200) {
      return [];
    }

    dynamic data;
    try {
      data = json.decode(response.body);
    } catch (_) {
      return [];
    }
    if (data is! List) return [];

    return data
        .map<LocationSuggestion>((raw) {
          final map = raw as Map<String, dynamic>;
          if (kIsWeb) {
            // Backend proxy already filters to TR and returns normalized fields.
            final city = map['city']?.toString() ?? '';
            final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0;
            final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0;
            return LocationSuggestion(
              displayName: map['displayName']?.toString() ?? '',
              city: city,
              lat: lat,
              lon: lon,
            );
          }

          final address =
              (map['address'] as Map?)?.cast<String, dynamic>() ?? {};
          final countryCode =
              (address['country_code'] ?? '').toString().toLowerCase();
          if (countryCode != 'tr') {
            return const LocationSuggestion(
                displayName: '', city: '', lat: 0, lon: 0);
          }
          final city = (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['state'] ??
                  address['county'] ??
                  address['suburb'] ??
                  address['neighbourhood'] ??
                  address['neighborhood'] ??
                  '')
              .toString();

          final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0;
          final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0;

          return LocationSuggestion(
            displayName: map['display_name']?.toString() ?? '',
            city: city,
            lat: lat,
            lon: lon,
          );
        })
        .where((s) => s.displayName.isNotEmpty && (s.lat != 0 || s.lon != 0))
        .toList();
  }
}
