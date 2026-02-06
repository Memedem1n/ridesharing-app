class Trip {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverAvatar;
  final double driverRating;
  final int driverTripCount;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final int availableSeats;
  final int totalSeats;
  final double pricePerSeat;
  final double? busPriceReference;
  final String? description;
  final String? vehicleName;
  final String? vehiclePlate;
  final List<String> features;
  final TripType type;
  final TripStatus status;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverAvatar,
    this.driverRating = 0,
    this.driverTripCount = 0,
    required this.origin,
    required this.destination,
    required this.departureTime,
    this.arrivalTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.pricePerSeat,
    this.busPriceReference,
    this.description,
    this.vehicleName,
    this.vehiclePlate,
    this.features = const [],
    this.type = TripType.passenger,
    this.status = TripStatus.active,
    required this.createdAt,
  });

  double get savings => (busPriceReference ?? pricePerSeat * 2) - pricePerSeat;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      driverId: json['driverId'],
      driverName: json['driver']?['name'] ?? json['driverName'] ?? '',
      driverAvatar: json['driver']?['avatar'] ?? json['driverAvatar'],
      driverRating: (json['driver']?['rating'] ?? json['driverRating'] ?? 0).toDouble(),
      driverTripCount: json['driver']?['tripCount'] ?? json['driverTripCount'] ?? 0,
      origin: json['origin'],
      destination: json['destination'],
      departureTime: DateTime.parse(json['departureTime']),
      arrivalTime: json['arrivalTime'] != null ? DateTime.parse(json['arrivalTime']) : null,
      availableSeats: json['availableSeats'],
      totalSeats: json['totalSeats'],
      pricePerSeat: (json['pricePerSeat']).toDouble(),
      busPriceReference: json['busPriceReference']?.toDouble(),
      description: json['description'],
      vehicleName: json['vehicle']?['name'] ?? json['vehicleName'],
      vehiclePlate: json['vehicle']?['plate'] ?? json['vehiclePlate'],
      features: List<String>.from(json['features'] ?? []),
      type: TripType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TripType.passenger,
      ),
      status: TripStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TripStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'destination': destination,
    'departureTime': departureTime.toIso8601String(),
    'arrivalTime': arrivalTime?.toIso8601String(),
    'availableSeats': availableSeats,
    'totalSeats': totalSeats,
    'pricePerSeat': pricePerSeat,
    'description': description,
    'features': features,
    'type': type.name,
  };
}

enum TripType { passenger, pet, cargo, food }

enum TripStatus { active, completed, cancelled }

class TripSearchParams {
  final String? origin;
  final String? destination;
  final DateTime? date;
  final int? passengers;
  final TripType? type;
  final double? maxPrice;

  TripSearchParams({
    this.origin,
    this.destination,
    this.date,
    this.passengers,
    this.type,
    this.maxPrice,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (origin != null) params['origin'] = origin;
    if (destination != null) params['destination'] = destination;
    if (date != null) params['date'] = date!.toIso8601String().split('T')[0];
    if (passengers != null) params['passengers'] = passengers;
    if (type != null) params['type'] = type!.name;
    if (maxPrice != null) params['maxPrice'] = maxPrice;
    return params;
  }
}

class CreateTripRequest {
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int totalSeats;
  final double pricePerSeat;
  final String? description;
  final String? vehicleId;
  final List<String> features;
  final TripType type;

  CreateTripRequest({
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.pricePerSeat,
    this.description,
    this.vehicleId,
    this.features = const [],
    this.type = TripType.passenger,
  });

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'destination': destination,
    'departureTime': departureTime.toIso8601String(),
    'totalSeats': totalSeats,
    'pricePerSeat': pricePerSeat,
    'description': description,
    'vehicleId': vehicleId,
    'features': features,
    'type': type.name,
  };
}
