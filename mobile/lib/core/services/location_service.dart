import 'dart:convert';
import 'package:http/http.dart' as http;

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

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'q': query,
      'addressdetails': '1',
      'limit': '6',
      'countrycodes': 'tr',
      'accept-language': 'tr',
    });

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'ridesharing-app/1.0 (local-dev)',
      },
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = json.decode(response.body);
    if (data is! List) return [];

    return data.map<LocationSuggestion>((raw) {
      final map = raw as Map<String, dynamic>;
      final address = (map['address'] as Map?)?.cast<String, dynamic>() ?? {};
      final countryCode = (address['country_code'] ?? '').toString().toLowerCase();
      if (countryCode != 'tr') {
        return const LocationSuggestion(displayName: '', city: '', lat: 0, lon: 0);
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

      return LocationSuggestion(
        displayName: map['display_name']?.toString() ?? '',
        city: city,
        lat: double.tryParse(map['lat']?.toString() ?? '') ?? 0,
        lon: double.tryParse(map['lon']?.toString() ?? '') ?? 0,
      );
    }).where((s) => s.displayName.isNotEmpty && s.city.isNotEmpty).toList();
  }
}
