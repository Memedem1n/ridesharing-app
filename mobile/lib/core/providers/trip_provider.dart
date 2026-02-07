import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';

// Trip Model
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
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? json['driver']?['id'] ?? '',
      driverName: json['driver']?['fullName'] ?? 'Sürücü',
      driverPhoto: json['driver']?['profilePhotoUrl'],
      driverRating: (json['driver']?['ratingAvg'] ?? 0).toDouble(),
      status: json['status'] ?? 'published',
      departureCity: json['departureCity'] ?? '',
      arrivalCity: json['arrivalCity'] ?? '',
      departureAddress: json['departureAddress'],
      arrivalAddress: json['arrivalAddress'],
      departureTime: DateTime.parse(json['departureTime'] ?? DateTime.now().toIso8601String()),
      availableSeats: json['availableSeats'] ?? 0,
      pricePerSeat: (json['pricePerSeat'] ?? 0).toDouble(),
      type: json['type'] ?? 'people',
      allowsPets: json['allowsPets'] ?? false,
      allowsCargo: json['allowsCargo'] ?? false,
      womenOnly: json['womenOnly'] ?? false,
      instantBooking: json['instantBooking'] ?? true,
      description: json['description'],
      vehicleBrand: json['vehicle']?['brand'],
      vehicleModel: json['vehicle']?['model'],
      vehicleColor: json['vehicle']?['color'],
    );
  }
}

// Search Parameters
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
    final agg = aggregates.putIfAbsent(key, () => _RouteAgg(from: from, to: to));
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

// Trip Service
class TripService {
  final Dio _dio;

  TripService(this._dio);

  Future<List<Trip>> searchTrips(TripSearchParams params) async {
    try {
      final response = await _dio.get('/trips', queryParameters: params.toQueryParams());
      final List<dynamic> data = response.data['trips'] ?? response.data ?? [];
      final trips = data.map((json) => Trip.fromJson(json)).toList();
      return trips.where((trip) {
        final name = trip.driverName.toLowerCase();
        return !name.startsWith('test');
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip?> getTripById(String id) async {
    try {
      final response = await _dio.get('/trips/$id');
      return Trip.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<List<Trip>> getMyTrips() async {
    final response = await _dio.get('/trips/my');
    final data = response.data;
    final list = data is Map ? (data['trips'] as List? ?? []) : (data as List? ?? []);
    return list.map((json) => Trip.fromJson(json)).toList();
  }

  Future<bool> createBooking(String tripId, int seats, String? token) async {
    try {
      await _dio.post(
        '/bookings',
        data: {'tripId': tripId, 'seats': seats},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

}

// Providers
final tripServiceProvider = Provider((ref) => TripService(ref.read(dioProvider)));

final tripSearchParamsProvider = StateProvider<TripSearchParams>((ref) => TripSearchParams());

final searchResultsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final params = ref.watch(tripSearchParamsProvider);
  return service.searchTrips(params);
});

final myTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  return service.getMyTrips();
});

final tripDetailProvider = FutureProvider.family<Trip?, String>((ref, tripId) async {
  final service = ref.read(tripServiceProvider);
  return service.getTripById(tripId);
});

final popularRoutesProvider = FutureProvider<List<PopularRouteSummary>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final trips = await service.searchTrips(TripSearchParams(page: 1, limit: 50));
  return buildPopularRoutes(trips).take(8).toList();
});
