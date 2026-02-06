import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'auth_provider.dart';
import '../api/api_client.dart';

// Trip Model
class Trip {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
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
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? date;
  final int? passengers;
  final String? type;

  TripSearchParams({
    this.departureCity,
    this.arrivalCity,
    this.date,
    this.passengers,
    this.type,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (departureCity != null && departureCity!.isNotEmpty) params['departureCity'] = departureCity;
    if (arrivalCity != null && arrivalCity!.isNotEmpty) params['arrivalCity'] = arrivalCity;
    if (date != null) params['date'] = date!.toIso8601String().split('T')[0];
    if (passengers != null) params['minSeats'] = passengers;
    if (type != null) params['type'] = type;
    return params;
  }
}

// Trip Service
class TripService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<List<Trip>> searchTrips(TripSearchParams params) async {
    try {
      final response = await _dio.get('/trips', queryParameters: params.toQueryParams());
      final List<dynamic> data = response.data['trips'] ?? response.data ?? [];
      return data.map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      // Return mock data on error for development
      return _getMockTrips();
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

  Future<bool> createBooking(String tripId, int seats, String? token) async {
    try {
      await _dio.post(
        '/bookings',
        data: {'tripId': tripId, 'seatsBooked': seats},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  List<Trip> _getMockTrips() {
    final now = DateTime.now();
    return [
      Trip(
        id: '1',
        driverId: 'driver1',
        driverName: 'Ahmet Yılmaz',
        driverRating: 4.8,
        departureCity: 'İstanbul',
        arrivalCity: 'Ankara',
        departureTime: now.add(const Duration(hours: 2)),
        availableSeats: 3,
        pricePerSeat: 350,
        type: 'people',
        allowsPets: true,
        allowsCargo: false,
        womenOnly: false,
        instantBooking: true,
        vehicleBrand: 'Volkswagen',
        vehicleModel: 'Passat',
        vehicleColor: 'Siyah',
      ),
      Trip(
        id: '2',
        driverId: 'driver2',
        driverName: 'Elif Kaya',
        driverRating: 4.9,
        departureCity: 'İstanbul',
        arrivalCity: 'Bursa',
        departureTime: now.add(const Duration(hours: 4)),
        availableSeats: 2,
        pricePerSeat: 150,
        type: 'people',
        allowsPets: false,
        allowsCargo: true,
        womenOnly: true,
        instantBooking: true,
        vehicleBrand: 'Toyota',
        vehicleModel: 'Corolla',
        vehicleColor: 'Beyaz',
      ),
      Trip(
        id: '3',
        driverId: 'driver3',
        driverName: 'Mehmet Demir',
        driverRating: 4.5,
        departureCity: 'Ankara',
        arrivalCity: 'İzmir',
        departureTime: now.add(const Duration(days: 1)),
        availableSeats: 4,
        pricePerSeat: 450,
        type: 'people',
        allowsPets: true,
        allowsCargo: true,
        womenOnly: false,
        instantBooking: false,
        vehicleBrand: 'Ford',
        vehicleModel: 'Focus',
        vehicleColor: 'Gri',
      ),
    ];
  }
}

// Providers
final tripServiceProvider = Provider((ref) => TripService());

final tripSearchParamsProvider = StateProvider<TripSearchParams>((ref) => TripSearchParams());

final searchResultsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final params = ref.watch(tripSearchParamsProvider);
  return service.searchTrips(params);
});

final tripDetailProvider = FutureProvider.family<Trip?, String>((ref, tripId) async {
  final service = ref.read(tripServiceProvider);
  return service.getTripById(tripId);
});
