import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/trip_models.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.read(dioProvider));
});

class TripRepository {
  final Dio _dio;

  TripRepository(this._dio);

  Future<List<Trip>> searchTrips(TripSearchParams params) async {
    try {
      final response = await _dio.get('/trips/search', queryParameters: params.toQueryParams());
      return (response.data as List).map((json) => Trip.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Trip> getTripById(String id) async {
    try {
      final response = await _dio.get('/trips/$id');
      return Trip.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<Trip>> getPopularRoutes() async {
    try {
      final response = await _dio.get('/trips/popular');
      return (response.data as List).map((json) => Trip.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<Trip>> getMyTrips() async {
    try {
      final response = await _dio.get('/trips/my');
      return (response.data as List).map((json) => Trip.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Trip> createTrip(CreateTripRequest request) async {
    try {
      final response = await _dio.post('/trips', data: request.toJson());
      return Trip.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Trip> updateTrip(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/trips/$id', data: data);
      return Trip.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> cancelTrip(String id) async {
    try {
      await _dio.delete('/trips/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<double?> getBusPriceReference(String origin, String destination) async {
    try {
      final response = await _dio.get('/trips/bus-price', queryParameters: {
        'origin': origin,
        'destination': destination,
      });
      return response.data['price']?.toDouble();
    } on DioException {
      return null;
    }
  }
}
