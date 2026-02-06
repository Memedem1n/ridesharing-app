// Türkiye illeri ve ilçeleri için autocomplete verisi
class LocationService {
  static final List<Location> cities = [
    // İstanbul
    Location(name: 'İstanbul', type: LocationType.city),
    Location(name: 'İstanbul, Kadıköy', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Beşiktaş', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Üsküdar', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Şişli', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Bakırköy', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Fatih', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Beyoğlu', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Ataşehir', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Maltepe', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Kartal', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Pendik', type: LocationType.district, parent: 'İstanbul'),
    Location(name: 'İstanbul, Sarıyer', type: LocationType.district, parent: 'İstanbul'),
    
    // Ankara
    Location(name: 'Ankara', type: LocationType.city),
    Location(name: 'Ankara, Kızılay', type: LocationType.district, parent: 'Ankara'),
    Location(name: 'Ankara, Çankaya', type: LocationType.district, parent: 'Ankara'),
    Location(name: 'Ankara, Keçiören', type: LocationType.district, parent: 'Ankara'),
    Location(name: 'Ankara, Yenimahalle', type: LocationType.district, parent: 'Ankara'),
    Location(name: 'Ankara, Etimesgut', type: LocationType.district, parent: 'Ankara'),
    Location(name: 'Ankara, Mamak', type: LocationType.district, parent: 'Ankara'),
    
    // İzmir
    Location(name: 'İzmir', type: LocationType.city),
    Location(name: 'İzmir, Konak', type: LocationType.district, parent: 'İzmir'),
    Location(name: 'İzmir, Karşıyaka', type: LocationType.district, parent: 'İzmir'),
    Location(name: 'İzmir, Bornova', type: LocationType.district, parent: 'İzmir'),
    Location(name: 'İzmir, Buca', type: LocationType.district, parent: 'İzmir'),
    Location(name: 'İzmir, Alsancak', type: LocationType.district, parent: 'İzmir'),
    
    // Antalya
    Location(name: 'Antalya', type: LocationType.city),
    Location(name: 'Antalya, Muratpaşa', type: LocationType.district, parent: 'Antalya'),
    Location(name: 'Antalya, Konyaaltı', type: LocationType.district, parent: 'Antalya'),
    Location(name: 'Antalya, Kepez', type: LocationType.district, parent: 'Antalya'),
    Location(name: 'Antalya, Alanya', type: LocationType.district, parent: 'Antalya'),
    
    // Bursa
    Location(name: 'Bursa', type: LocationType.city),
    Location(name: 'Bursa, Osmangazi', type: LocationType.district, parent: 'Bursa'),
    Location(name: 'Bursa, Nilüfer', type: LocationType.district, parent: 'Bursa'),
    Location(name: 'Bursa, Yıldırım', type: LocationType.district, parent: 'Bursa'),
    
    // Diğer büyük şehirler
    Location(name: 'Konya', type: LocationType.city),
    Location(name: 'Adana', type: LocationType.city),
    Location(name: 'Gaziantep', type: LocationType.city),
    Location(name: 'Mersin', type: LocationType.city),
    Location(name: 'Diyarbakır', type: LocationType.city),
    Location(name: 'Kayseri', type: LocationType.city),
    Location(name: 'Eskişehir', type: LocationType.city),
    Location(name: 'Samsun', type: LocationType.city),
    Location(name: 'Trabzon', type: LocationType.city),
    Location(name: 'Denizli', type: LocationType.city),
    Location(name: 'Malatya', type: LocationType.city),
    Location(name: 'Erzurum', type: LocationType.city),
    Location(name: 'Şanlıurfa', type: LocationType.city),
    Location(name: 'Sakarya', type: LocationType.city),
    Location(name: 'Kocaeli', type: LocationType.city),
    Location(name: 'Tekirdağ', type: LocationType.city),
    Location(name: 'Muğla', type: LocationType.city),
    Location(name: 'Aydın', type: LocationType.city),
    Location(name: 'Balıkesir', type: LocationType.city),
    Location(name: 'Manisa', type: LocationType.city),
  ];

  static List<Location> search(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return cities
        .where((l) => l.name.toLowerCase().contains(lowerQuery))
        .take(8)
        .toList();
  }

  static List<Location> getPopularRoutes() {
    return [
      Location(name: 'İstanbul', type: LocationType.city),
      Location(name: 'Ankara', type: LocationType.city),
      Location(name: 'İzmir', type: LocationType.city),
      Location(name: 'Antalya', type: LocationType.city),
      Location(name: 'Bursa', type: LocationType.city),
    ];
  }
}

class Location {
  final String name;
  final LocationType type;
  final String? parent;

  Location({required this.name, required this.type, this.parent});

  String get displayName => name;
  String get typeLabel {
    switch (type) {
      case LocationType.city:
        return 'İl';
      case LocationType.district:
        return 'İlçe';
      case LocationType.neighborhood:
        return 'Mahalle';
    }
  }
}

enum LocationType { city, district, neighborhood }
