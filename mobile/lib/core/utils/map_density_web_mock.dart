import '../providers/trip_provider.dart';

class WebDensityPoint {
  final double lat;
  final double lng;
  final int count;

  const WebDensityPoint({
    required this.lat,
    required this.lng,
    required this.count,
  });
}

const List<WebDensityPoint> _mockStudentCityDensity = <WebDensityPoint>[
  WebDensityPoint(lat: 39.9334, lng: 32.8597, count: 99), // Ankara
  WebDensityPoint(lat: 41.0082, lng: 28.9784, count: 97), // Istanbul
  WebDensityPoint(lat: 38.4237, lng: 27.1428, count: 92), // Izmir
  WebDensityPoint(lat: 39.7667, lng: 30.5256, count: 89), // Eskisehir
  WebDensityPoint(lat: 40.1950, lng: 29.0600, count: 87), // Bursa
  WebDensityPoint(lat: 37.8746, lng: 32.4932, count: 85), // Konya
  WebDensityPoint(lat: 38.7312, lng: 35.4787, count: 83), // Kayseri
  WebDensityPoint(lat: 40.7654, lng: 29.9408, count: 81), // Kocaeli
  WebDensityPoint(lat: 40.7569, lng: 30.3781, count: 79), // Sakarya
  WebDensityPoint(lat: 36.8841, lng: 30.7056, count: 78), // Antalya
  WebDensityPoint(lat: 39.6484, lng: 27.8826, count: 76), // Balikesir
  WebDensityPoint(lat: 40.9833, lng: 27.5167, count: 75), // Tekirdag
  WebDensityPoint(lat: 38.6191, lng: 27.4289, count: 74), // Manisa
  WebDensityPoint(lat: 37.8380, lng: 27.8456, count: 73), // Aydin
  WebDensityPoint(lat: 37.7765, lng: 29.0864, count: 72), // Denizli
  WebDensityPoint(lat: 40.1467, lng: 26.4086, count: 70), // Canakkale
  WebDensityPoint(lat: 37.2154, lng: 28.3636, count: 69), // Mugla
  WebDensityPoint(lat: 38.7507, lng: 30.5567, count: 68), // Afyonkarahisar
  WebDensityPoint(lat: 39.4210, lng: 29.9870, count: 66), // Kutahya
  WebDensityPoint(lat: 38.6823, lng: 29.4082, count: 65), // Usak
  WebDensityPoint(lat: 37.7648, lng: 30.5566, count: 64), // Isparta
  WebDensityPoint(lat: 40.7395, lng: 31.6116, count: 63), // Bolu
  WebDensityPoint(lat: 40.6500, lng: 29.2667, count: 62), // Yalova
  WebDensityPoint(lat: 41.6771, lng: 26.5557, count: 61), // Edirne
];

List<WebDensityPoint> buildWebDensityPoints(List<MapDensityPoint> realPoints) {
  final merged = <String, WebDensityPoint>{};

  for (final mock in _mockStudentCityDensity) {
    merged[_geoKey(mock.lat, mock.lng)] = mock;
  }

  if (realPoints.isNotEmpty) {
    final maxIntensity = realPoints
        .map((point) => point.intensity)
        .fold<double>(0, (prev, val) => val > prev ? val : prev);
    final safeMax = maxIntensity <= 0 ? 1.0 : maxIntensity;

    final sortedReal = [...realPoints]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    for (final point in sortedReal.take(18)) {
      final ratio = (point.intensity / safeMax).clamp(0.0, 1.0);
      final count = (34 + (ratio * 61)).round().clamp(28, 95);
      final mapped = WebDensityPoint(lat: point.lat, lng: point.lng, count: count);
      _upsertDensityPoint(merged, mapped);
    }
  }

  final values = merged.values.toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return values.take(28).toList();
}

void _upsertDensityPoint(Map<String, WebDensityPoint> merged, WebDensityPoint point) {
  final nearestKey = _findNearbyKey(merged, point.lat, point.lng);
  if (nearestKey == null) {
    merged[_geoKey(point.lat, point.lng)] = point;
    return;
  }

  final current = merged[nearestKey]!;
  if (point.count > current.count) {
    merged[nearestKey] = point;
  }
}

String? _findNearbyKey(Map<String, WebDensityPoint> merged, double lat, double lng) {
  for (final entry in merged.entries) {
    final p = entry.value;
    if ((p.lat - lat).abs() <= 0.32 && (p.lng - lng).abs() <= 0.32) {
      return entry.key;
    }
  }
  return null;
}

String _geoKey(double lat, double lng) {
  final roundedLat = (lat * 100).round() / 100;
  final roundedLng = (lng * 100).round() / 100;
  return '$roundedLat|$roundedLng';
}
