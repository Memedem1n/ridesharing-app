import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/media_url.dart';

class TripRoutePoint {
  final double lat;
  final double lng;

  const TripRoutePoint({required this.lat, required this.lng});

  factory TripRoutePoint.fromJson(Map<String, dynamic> json) {
    return TripRoutePoint(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}

class TripRouteSnapshot {
  final String provider;
  final double distanceKm;
  final double durationMin;
  final List<TripRoutePoint> points;

  const TripRouteSnapshot({
    required this.provider,
    required this.distanceKm,
    required this.durationMin,
    required this.points,
  });

  factory TripRouteSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? const [];
    return TripRouteSnapshot(
      provider: json['provider']?.toString() ?? 'osrm',
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      durationMin: (json['durationMin'] ?? 0).toDouble(),
      points: rawPoints
          .whereType<Map>()
          .map((item) =>
              TripRoutePoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class TripViaCity {
  final String city;
  final String? district;
  final List<String> pickupSuggestions;

  const TripViaCity({
    required this.city,
    this.district,
    this.pickupSuggestions = const [],
  });

  factory TripViaCity.fromJson(Map<String, dynamic> json) {
    final suggestions = (json['pickupSuggestions'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    return TripViaCity(
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      pickupSuggestions: suggestions,
    );
  }
}

class TripPickupPolicy {
  final String city;
  final String? district;
  final bool pickupAllowed;
  final String pickupType;
  final String? note;

  const TripPickupPolicy({
    required this.city,
    this.district,
    required this.pickupAllowed,
    required this.pickupType,
    this.note,
  });

  factory TripPickupPolicy.fromJson(Map<String, dynamic> json) {
    return TripPickupPolicy(
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      pickupAllowed: json['pickupAllowed'] == true,
      pickupType: json['pickupType']?.toString() ?? 'city_center',
      note: json['note']?.toString(),
    );
  }
}

class TripPassenger {
  final String id;
  final String fullName;
  final String? profilePhotoUrl;
  final double ratingAvg;
  final int seats;

  const TripPassenger({
    required this.id,
    required this.fullName,
    this.profilePhotoUrl,
    required this.ratingAvg,
    required this.seats,
  });

  factory TripPassenger.fromJson(Map<String, dynamic> json) {
    return TripPassenger(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      profilePhotoUrl: resolveMediaUrl(json['profilePhotoUrl']?.toString()),
      ratingAvg: (json['ratingAvg'] ?? 0).toDouble(),
      seats: json['seats'] ?? 1,
    );
  }
}

class Trip {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
  final String status;
  final String departureCity;
  final String arrivalCity;
  final String? departureAddress;
  final String? arrivalAddress;
  final double? departureLat;
  final double? departureLng;
  final double? arrivalLat;
  final double? arrivalLng;
  final DateTime departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final String type;
  final bool allowsPets;
  final bool allowsCargo;
  final bool womenOnly;
  final bool instantBooking;
  final String? description;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final TripRouteSnapshot? route;
  final List<TripViaCity> viaCities;
  final List<TripPickupPolicy> pickupPolicies;
  final int? occupancyConfirmedSeats;
  final int? occupancyPassengerCount;
  final List<TripPassenger> passengers;
  final bool canViewPassengerList;
  final bool canViewLiveLocation;

  Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhoto,
    required this.driverRating,
    this.status = 'published',
    required this.departureCity,
    required this.arrivalCity,
    this.departureAddress,
    this.arrivalAddress,
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.type,
    required this.allowsPets,
    required this.allowsCargo,
    required this.womenOnly,
    required this.instantBooking,
    this.description,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.route,
    this.viaCities = const [],
    this.pickupPolicies = const [],
    this.occupancyConfirmedSeats,
    this.occupancyPassengerCount,
    this.passengers = const [],
    this.canViewPassengerList = false,
    this.canViewLiveLocation = false,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final routeJson = json['route'];
    final viaCitiesJson = (json['viaCities'] as List?) ?? const [];
    final pickupPoliciesJson = (json['pickupPolicies'] as List?) ?? const [];
    final passengersJson = (json['passengers'] as List?) ?? const [];
    final occupancyJson = json['occupancy'] as Map?;

    return Trip(
      id: json['id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ??
          json['driver']?['id']?.toString() ??
          '',
      driverName: json['driver']?['fullName']?.toString() ?? 'Surucu',
      driverPhoto:
          resolveMediaUrl(json['driver']?['profilePhotoUrl']?.toString()),
      driverRating: (json['driver']?['ratingAvg'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'published',
      departureCity: json['departureCity']?.toString() ?? '',
      arrivalCity: json['arrivalCity']?.toString() ?? '',
      departureAddress: json['departureAddress']?.toString(),
      arrivalAddress: json['arrivalAddress']?.toString(),
      departureLat: json['departureLat'] != null
          ? (json['departureLat']).toDouble()
          : null,
      departureLng: json['departureLng'] != null
          ? (json['departureLng']).toDouble()
          : null,
      arrivalLat:
          json['arrivalLat'] != null ? (json['arrivalLat']).toDouble() : null,
      arrivalLng:
          json['arrivalLng'] != null ? (json['arrivalLng']).toDouble() : null,
      departureTime: DateTime.parse(
          json['departureTime'] ?? DateTime.now().toIso8601String()),
      availableSeats: json['availableSeats'] ?? 0,
      pricePerSeat: (json['pricePerSeat'] ?? 0).toDouble(),
      type: json['type']?.toString() ?? 'people',
      allowsPets: json['allowsPets'] ?? false,
      allowsCargo: json['allowsCargo'] ?? false,
      womenOnly: json['womenOnly'] ?? false,
      instantBooking: json['instantBooking'] ?? true,
      description: json['description']?.toString(),
      vehicleBrand: json['vehicle']?['brand']?.toString(),
      vehicleModel: json['vehicle']?['model']?.toString(),
      vehicleColor: json['vehicle']?['color']?.toString(),
      route: routeJson is Map
          ? TripRouteSnapshot.fromJson(Map<String, dynamic>.from(routeJson))
          : null,
      viaCities: viaCitiesJson
          .whereType<Map>()
          .map((item) => TripViaCity.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      pickupPolicies: pickupPoliciesJson
          .whereType<Map>()
          .map((item) =>
              TripPickupPolicy.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      occupancyConfirmedSeats: occupancyJson?['confirmedSeats'],
      occupancyPassengerCount: occupancyJson?['passengerCount'],
      passengers: passengersJson
          .whereType<Map>()
          .map(
              (item) => TripPassenger.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      canViewPassengerList: json['canViewPassengerList'] == true,
      canViewLiveLocation: json['canViewLiveLocation'] == true,
    );
  }
}

class TripSearchParams {
  final String? from;
  final String? to;
  final DateTime? date;
  final int? seats;
  final String? type;
  final bool? allowsPets;
  final bool? womenOnly;
  final int? page;
  final int? limit;

  TripSearchParams({
    this.from,
    this.to,
    this.date,
    this.seats,
    this.type,
    this.allowsPets,
    this.womenOnly,
    this.page,
    this.limit,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (from != null && from!.isNotEmpty) params['from'] = from;
    if (to != null && to!.isNotEmpty) params['to'] = to;
    if (date != null) params['date'] = date!.toIso8601String().split('T')[0];
    if (seats != null) params['seats'] = seats;
    if (type != null && type!.isNotEmpty) params['type'] = type;
    if (allowsPets != null) params['allowsPets'] = allowsPets;
    if (womenOnly != null) params['womenOnly'] = womenOnly;
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    return params;
  }

  TripSearchParams copyWith({
    String? from,
    String? to,
    DateTime? date,
    int? seats,
    String? type,
    bool? allowsPets,
    bool? womenOnly,
    int? page,
    int? limit,
  }) {
    return TripSearchParams(
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
      seats: seats ?? this.seats,
      type: type ?? this.type,
      allowsPets: allowsPets ?? this.allowsPets,
      womenOnly: womenOnly ?? this.womenOnly,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class PopularRouteSummary {
  final String from;
  final String to;
  final int count;
  final double minPrice;
  final double avgPrice;

  PopularRouteSummary({
    required this.from,
    required this.to,
    required this.count,
    required this.minPrice,
    required this.avgPrice,
  });
}

List<PopularRouteSummary> buildPopularRoutes(List<Trip> trips) {
  final Map<String, _RouteAgg> aggregates = {};
  for (final trip in trips) {
    final from = trip.departureCity.trim();
    final to = trip.arrivalCity.trim();
    if (from.isEmpty || to.isEmpty) continue;
    final key = '$from|$to';
    final agg =
        aggregates.putIfAbsent(key, () => _RouteAgg(from: from, to: to));
    agg.count += 1;
    agg.totalPrice += trip.pricePerSeat;
    if (trip.pricePerSeat < agg.minPrice) {
      agg.minPrice = trip.pricePerSeat;
    }
  }

  final routes = aggregates.values.map((agg) {
    final avg = agg.count > 0 ? (agg.totalPrice / agg.count) : 0.0;
    return PopularRouteSummary(
      from: agg.from,
      to: agg.to,
      count: agg.count,
      minPrice: agg.minPrice.isFinite ? agg.minPrice : 0.0,
      avgPrice: avg,
    );
  }).toList();

  routes.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.minPrice.compareTo(b.minPrice);
  });

  return routes;
}

class _RouteAgg {
  final String from;
  final String to;
  int count = 0;
  double totalPrice = 0;
  double minPrice = double.infinity;

  _RouteAgg({required this.from, required this.to});
}

class TripService {
  final Dio _dio;

  TripService(this._dio);

  Future<List<Trip>> searchTrips(TripSearchParams params) async {
    final response =
        await _dio.get('/trips', queryParameters: params.toQueryParams());
    final List<dynamic> data = response.data['trips'] ?? response.data ?? [];
    final trips = data.map((json) => Trip.fromJson(json)).toList();
    return trips.where((trip) {
      final name = trip.driverName.toLowerCase();
      return !name.startsWith('test');
    }).toList();
  }

  Future<Trip?> getTripById(String id) async {
    try {
      final response = await _dio.get('/trips/$id');
      return Trip.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Trip>> getMyTrips() async {
    final response = await _dio.get('/trips/my');
    final data = response.data;
    final list =
        data is Map ? (data['trips'] as List? ?? []) : (data as List? ?? []);
    return list.map((json) => Trip.fromJson(json)).toList();
  }
}

final tripServiceProvider =
    Provider((ref) => TripService(ref.read(dioProvider)));

final tripSearchParamsProvider =
    StateProvider<TripSearchParams>((ref) => TripSearchParams());

final searchResultsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final params = ref.watch(tripSearchParamsProvider);
  return service.searchTrips(params);
});

final myTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  return service.getMyTrips();
});

final tripDetailProvider =
    FutureProvider.family<Trip?, String>((ref, tripId) async {
  final service = ref.read(tripServiceProvider);
  return service.getTripById(tripId);
});

final popularRoutesProvider =
    FutureProvider<List<PopularRouteSummary>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final trips = await service.searchTrips(TripSearchParams(page: 1, limit: 50));
  return buildPopularRoutes(trips).take(8).toList();
});
