import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/providers/auth_provider.dart';

// Verification status provider
final verificationStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final token = await ref.read(authTokenProvider.future);
  
  try {
    final response = await dio.get(
      '/verification/status',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  } catch (e) {
    return {
      'identityStatus': 'none',
      'licenseStatus': 'none',
      'criminalRecordStatus': 'none',
      'verified': false,
    };
  }
});

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _identityImage;
  File? _licenseImage;
  File? _criminalRecordImage;
  bool _uploadingIdentity = false;
  bool _uploadingLicense = false;
  bool _uploadingCriminalRecord = false;

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        if (type == 'identity') {
          _identityImage = File(image.path);
        } else if (type == 'license') {
          _licenseImage = File(image.path);
        } else {
          _criminalRecordImage = File(image.path);
        }
      });
    }
  }

  Future<void> _uploadDocument(String type) async {
    File? file;
    if (type == 'identity') file = _identityImage;
    else if (type == 'license') file = _licenseImage;
    else file = _criminalRecordImage;

    if (file == null) return;

    setState(() {
      if (type == 'identity') _uploadingIdentity = true;
      else if (type == 'license') _uploadingLicense = true;
      else _uploadingCriminalRecord = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final token = await ref.read(authTokenProvider.future);
      
      String endpoint;
      String successMessage;
      
      if (type == 'identity') {
        endpoint = 'upload-identity';
        successMessage = 'Kimlik yüklendi!';
      } else if (type == 'license') {
        endpoint = 'upload-license';
        successMessage = 'Ehliyet yüklendi!';
      } else {
        endpoint = 'upload-criminal-record';
        successMessage = 'Adli sicil kaydı yüklendi!';
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      await dio.post(
        '/verification/$endpoint',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(verificationStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (type == 'identity') _uploadingIdentity = false;
          else if (type == 'license') _uploadingLicense = false;
          else _uploadingCriminalRecord = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(verificationStatusProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Hesap Doğrulama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Belgelerinizi Yükleyin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                Text(
                  'Güvenliğiniz için kimlik ve ehliyet belgelerinizi doğrulamamız gerekiyor.',
                  style: TextStyle(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 32),

                // Identity Card
                _DocumentCard(
                  title: 'Kimlik Kartı',
                  subtitle: 'TC Kimlik kartınızın ön yüzü',
                  icon: Icons.credit_card,
                  status: statusAsync.value?['identityStatus'] ?? 'none',
                  selectedImage: _identityImage,
                  isUploading: _uploadingIdentity,
                  onPickImage: () => _pickImage('identity'),
                  onUpload: () => _uploadDocument('identity'),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                const SizedBox(height: 20),

                // License Card
                _DocumentCard(
                  title: 'Sürücü Belgesi',
                  subtitle: 'Ehliyetinizin ön yüzü',
                  icon: Icons.drive_eta,
                  status: statusAsync.value?['licenseStatus'] ?? 'none',
                  selectedImage: _licenseImage,
                  isUploading: _uploadingLicense,
                  onPickImage: () => _pickImage('license'),
                  onUpload: () => _uploadDocument('license'),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                const SizedBox(height: 20),

                // Criminal Record Card
                _DocumentCard(
                  title: 'Adli Sicil Kaydı',
                  subtitle: 'E-Devletten alınan adli sicil kaydı',
                  icon: Icons.gavel,
                  status: statusAsync.value?['criminalRecordStatus'] ?? 'none',
                  selectedImage: _criminalRecordImage,
                  isUploading: _uploadingCriminalRecord,
                  onPickImage: () => _pickImage('criminalRecord'),
                  onUpload: () => _uploadDocument('criminalRecord'),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 32),

                // Status Info
                if (statusAsync.value?['verified'] == true)
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: AppColors.success),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hesabınız Doğrulandı!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                'Tüm belgeleriniz onaylandı.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String status;
  final File? selectedImage;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onUpload;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.selectedImage,
    required this.isUploading,
    required this.onPickImage,
    required this.onUpload,
  });

  Color get statusColor {
    switch (status) {
      case 'verified':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String get statusText {
    switch (status) {
      case 'verified':
        return 'Onaylandı';
      case 'pending':
        return 'İnceleniyor';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Yüklenmedi';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'verified':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.upload_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (selectedImage != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                selectedImage!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          const SizedBox(height: 16),

          if (status != 'verified') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(selectedImage == null ? 'Seç' : 'Değiştir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    text: isUploading ? 'Yükleniyor...' : 'Yükle',
                    icon: isUploading ? Icons.hourglass_empty : Icons.cloud_upload,
                    onPressed: selectedImage != null && !isUploading ? onUpload : () {},
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
