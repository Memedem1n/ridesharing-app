import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/booking_models.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.read(dioProvider));
});

class BookingRepository {
  final Dio _dio;

  BookingRepository(this._dio);

  Future<List<Booking>> getMyBookings({String? status}) async {
    try {
      final params = status != null ? {'status': status} : null;
      final response = await _dio.get('/bookings/my', queryParameters: params);
      return (response.data as List).map((json) => Booking.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<Booking>> getDriverBookings({String? status}) async {
    try {
      final params = status != null ? {'status': status} : null;
      final response = await _dio.get('/bookings/driver', queryParameters: params);
      return (response.data as List).map((json) => Booking.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> getBookingById(String id) async {
    try {
      final response = await _dio.get('/bookings/$id');
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> createBooking(CreateBookingRequest request) async {
    try {
      final response = await _dio.post('/bookings', data: request.toJson());
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> confirmBooking(String id) async {
    try {
      final response = await _dio.post('/bookings/$id/confirm');
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> rejectBooking(String id, {String? reason}) async {
    try {
      final response = await _dio.post('/bookings/$id/reject', data: {'reason': reason});
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> checkIn(String id, String qrCode) async {
    try {
      final response = await _dio.post('/bookings/$id/check-in', data: {'qrCode': qrCode});
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Booking> cancelBooking(String id) async {
    try {
      final response = await _dio.post('/bookings/$id/cancel');
      return Booking.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
