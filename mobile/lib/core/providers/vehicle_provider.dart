import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'auth_provider.dart';
import '../../features/vehicles/domain/vehicle_models.dart';

class VehicleService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/v1')); // Normal API
  final Dio _uploadDio = Dio(BaseOptions(baseUrl: 'http://localhost:3000')); // Uploads are at root usually or adjusted path

  Future<List<Vehicle>> getMyVehicles(String token) async {
    try {
      final response = await _dio.get(
        '/vehicles/my-vehicles', 
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List<dynamic> data = response.data;
      return data.map((json) => Vehicle.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> uploadRegistration(File file, String token) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await _uploadDio.post(
        '/api/verification/upload-vehicle-registration', // verification controller path
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['url'];
    } catch (e) {
      throw Exception('Belge yüklenemedi: $e');
    }
  }

  Future<bool> updateVehicle(String id, Map<String, dynamic> data, String token) async {
    try {
      await _dio.patch(
        '/vehicles/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Create vehicle
  Future<Vehicle?> createVehicle(Map<String, dynamic> data, String token) async {
    try {
      final response = await _dio.post(
        '/vehicles',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return Vehicle.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }
}

final vehicleServiceProvider = Provider((ref) => VehicleService());

final myVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final service = ref.read(vehicleServiceProvider);
  final token = await ref.read(authTokenProvider.future);
  if (token == null) return [];
  return service.getMyVehicles(token);
});
