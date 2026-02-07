import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../vehicles/domain/vehicle_models.dart';

class VehicleVerificationScreen extends ConsumerStatefulWidget {
  const VehicleVerificationScreen({super.key});

  @override
  ConsumerState<VehicleVerificationScreen> createState() => _VehicleVerificationScreenState();
}

class _VehicleVerificationScreenState extends ConsumerState<VehicleVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _registrationImage;
  bool _isUploading = false;
  String? _selectedVehicleId;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _registrationImage = File(image.path);
      });
    }
  }

  Future<void> _uploadDocument(Vehicle vehicle) async {
    if (_registrationImage == null) return;

    setState(() => _isUploading = true);

    try {
      final token = await ref.read(authTokenProvider.future);
      if (token == null) return;
      
      final service = ref.read(vehicleServiceProvider);
      
      // 1. Upload Document
      final imageUrl = await service.uploadRegistration(_registrationImage!, token);
      
      if (imageUrl != null) {
        // 2. Update Vehicle
        await service.updateVehicle(
          vehicle.id, 
          {'registrationImage': imageUrl}, 
          token,
        );
        
        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yükleme başarısız oldu. Lütfen tekrar deneyin.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            ).animate().scale(),
            const SizedBox(height: 16),
            const Text(
              'Ruhsat Yüklendi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ruhsatınız inceleme için gönderildi. Onaylandığında bilgilendirileceksiniz.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Tamam',
                icon: Icons.check,
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  context.pop(); // Go back
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Araç Ruhsat Doğrulama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: vehiclesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.white))),
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Kayıtlı aracınız yok.\nLütfen önce bir araç ekleyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/vehicle-create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Araç Ekle'),
                      ),
                    ],
                  ),
                );
              }
              
              // Select first vehicle by default
              _selectedVehicleId ??= vehicles.first.id;
              final selectedVehicle = vehicles.firstWhere((v) => v.id == _selectedVehicleId);
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Selector (if multiple)
                    if (vehicles.length > 1) ...[
                      const Text(
                        'Araç Seçin',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.glassBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassStroke),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedVehicleId,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary),
                            isExpanded: true,
                            items: vehicles.map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text('${v.brand} ${v.model} (${v.licensePlate})'),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedVehicleId = value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Selected Vehicle Card
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.directions_car, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedVehicle.brand} ${selectedVehicle.model}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                selectedVehicle.licensePlate,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (selectedVehicle.registrationImage != null)
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.warning),
                              ),
                              child: const Text('İnceleniyor', style: TextStyle(color: AppColors.warning, fontSize: 11)),
                             ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(),

                    const SizedBox(height: 32),
                    
                    const Text(
                      'Ruhsat Fotoğrafı',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lütfen araç ruhsatının net ve okunabilir bir fotoğrafını yükleyin.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    
                    const SizedBox(height: 24),

                    // Image Upload Area
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.glassBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _registrationImage != null ? AppColors.primary : AppColors.glassStroke,
                            width: 2,
                          ),
                        ),
                        child: _registrationImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(_registrationImage!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 48, color: AppColors.textTertiary),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Fotoğraf Seçmek İçin Dokunun',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: _isUploading ? 'Yükleniyor...' : 'Kaydet ve Gönder',
                        icon: Icons.upload_file,
                        onPressed: _registrationImage != null && !_isUploading
                            ? () => _uploadDocument(selectedVehicle)
                            : () {},
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
