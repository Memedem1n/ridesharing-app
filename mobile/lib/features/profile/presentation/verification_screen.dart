import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:camera/camera.dart';
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
  File? _licenseFrontImage;
  File? _licenseBackImage;
  File? _criminalRecordFile;
  String? _criminalRecordFileName;
  bool _criminalRecordIsPdf = false;
  bool _uploadingIdentity = false;
  bool _uploadingLicense = false;
  bool _uploadingCriminalRecord = false;

  Future<ImageSource?> _selectImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
              title: const Text('Kamera', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
              title: const Text('Galeri', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _pickImageFromSource({required String title, required String hint}) async {
    final source = await _selectImageSource();
    if (!mounted) return null;
    if (source == null) return null;
    if (source == ImageSource.camera) {
      final file = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraCaptureScreen(title: title, hint: hint),
          fullscreenDialog: true,
        ),
      );
      return file;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (image == null) return null;
    return File(image.path);
  }

  Future<void> _pickIdentityImage() async {
    final file = await _pickImageFromSource(
      title: 'Kimlik Fotoğrafı',
      hint: 'Kimlik kartını çerçeveye hizalayın',
    );
    if (file == null) return;
    setState(() => _identityImage = file);
  }

  Future<void> _pickLicenseImage(String side) async {
    final file = await _pickImageFromSource(
      title: side == 'front' ? 'Ehliyet Ön Yüz' : 'Ehliyet Arka Yüz',
      hint: side == 'front'
          ? 'Ön yüzü çerçeveye hizalayın'
          : 'Arka yüzü çerçeveye hizalayın',
    );
    if (file == null) return;
    setState(() {
      if (side == 'front') {
        _licenseFrontImage = file;
      } else {
        _licenseBackImage = file;
      }
    });
  }

  Future<void> _pickCriminalRecordFile() async {
    const typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final localFile = File(file.path);
    final name = file.name;
    final isPdf = name.toLowerCase().endsWith('.pdf');

    setState(() {
      _criminalRecordFile = localFile;
      _criminalRecordFileName = name;
      _criminalRecordIsPdf = isPdf;
    });
  }

  Future<void> _uploadDocument(String type) async {
    if (type == 'identity' && _identityImage == null) return;
    if (type == 'license' && (_licenseFrontImage == null || _licenseBackImage == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ehliyetin ön ve arka yüzü zorunludur.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    if (type == 'criminalRecord' && _criminalRecordFile == null) return;

    setState(() {
      if (type == 'identity') {
        _uploadingIdentity = true;
      } else if (type == 'license') {
        _uploadingLicense = true;
      } else {
        _uploadingCriminalRecord = true;
      }
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

      FormData formData;
      if (type == 'license') {
        formData = FormData.fromMap({
          'front': await MultipartFile.fromFile(_licenseFrontImage!.path),
          'back': await MultipartFile.fromFile(_licenseBackImage!.path),
        });
      } else if (type == 'identity') {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(_identityImage!.path),
        });
      } else {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(_criminalRecordFile!.path),
        });
      }

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
          if (type == 'identity') {
            _uploadingIdentity = false;
          } else if (type == 'license') {
            _uploadingLicense = false;
          } else {
            _uploadingCriminalRecord = false;
          }
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
                const SizedBox(height: 24),

                _CaptureGuideCard(
                  title: 'Nasıl çekmeliyim?',
                  bullets: const [
                    'Belgeyi düz bir zemine koyun, tüm köşeler görünsün.',
                    'Işık yansıması olmasın, bulanıklık olmasın.',
                    'Yazılar net ve okunabilir olmalı.',
                    'Ehliyetin ön ve arka yüzü zorunludur.',
                  ],
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),

                const SizedBox(height: 28),

                // Identity Card
                _DocumentCard(
                  title: 'Kimlik Kartı',
                  subtitle: 'TC Kimlik kartınızın ön yüzü',
                  icon: Icons.credit_card,
                  status: statusAsync.value?['identityStatus'] ?? 'none',
                  selectedImage: _identityImage,
                  isUploading: _uploadingIdentity,
                  onPickImage: _pickIdentityImage,
                  onUpload: () => _uploadDocument('identity'),
                  helper: const _BulletList(items: [
                    'TC Kimlik No ve doğum tarihi görünmelidir.',
                    'Parlama/şekil bozulması olmamalı.',
                  ]),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                const SizedBox(height: 20),

                // License Card
                _LicenseDocumentCard(
                  title: 'Sürücü Belgesi',
                  subtitle: 'Ehliyetin ön ve arka yüzü zorunludur.',
                  icon: Icons.drive_eta,
                  status: statusAsync.value?['licenseStatus'] ?? 'none',
                  frontImage: _licenseFrontImage,
                  backImage: _licenseBackImage,
                  isUploading: _uploadingLicense,
                  onPickFront: () => _pickLicenseImage('front'),
                  onPickBack: () => _pickLicenseImage('back'),
                  onUpload: () => _uploadDocument('license'),
                  helper: const _BulletList(items: [
                    'Geçerlilik tarihi ve sınıf bilgisi görünmeli.',
                    'Bugünden ileri tarihli olmalı.',
                  ]),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                const SizedBox(height: 20),

                // Criminal Record Card
                _DocumentCard(
                  title: 'Adli Sicil Kaydı',
                  subtitle: 'E-Devletten alınan adli sicil kaydı',
                  icon: Icons.gavel,
                  status: statusAsync.value?['criminalRecordStatus'] ?? 'none',
                  selectedImage: _criminalRecordIsPdf ? null : _criminalRecordFile,
                  customPreview: _criminalRecordIsPdf && _criminalRecordFile != null
                      ? _FilePreview(fileName: _criminalRecordFileName ?? 'adli-sicil.pdf')
                      : null,
                  isUploading: _uploadingCriminalRecord,
                  onPickImage: _pickCriminalRecordFile,
                  onUpload: () => _uploadDocument('criminalRecord'),
                  helper: const _BulletList(items: [
                    'e-Devlet > Adli Sicil Kaydı Sorgulama',
                    'Belge oluşturup PDF indir (veya ekran görüntüsü al).',
                    'Belgede "kaydı yoktur" ibaresi olmalı.',
                  ]),
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
  final Widget? customPreview;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onUpload;
  final Widget? helper;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.selectedImage,
    this.customPreview,
    required this.isUploading,
    required this.onPickImage,
    required this.onUpload,
    this.helper,
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

          if (customPreview != null) ...[
            const SizedBox(height: 16),
            customPreview!,
          ] else if (selectedImage != null) ...[
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

          if (helper != null) ...[
            const SizedBox(height: 16),
            helper!,
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

class _CaptureGuideCard extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _CaptureGuideCard({
    required this.title,
    required this.bullets,
  });

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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/ID-Verification-1.jpg',
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Doğru örnek: belge düz, net ve tüm köşeler görünür.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _BulletList(items: bullets),
        ],
      ),
    );
  }
}

class _LicenseDocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String status;
  final File? frontImage;
  final File? backImage;
  final bool isUploading;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onUpload;
  final Widget? helper;

  const _LicenseDocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.frontImage,
    required this.backImage,
    required this.isUploading,
    required this.onPickFront,
    required this.onPickBack,
    required this.onUpload,
    this.helper,
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
    final canUpload = frontImage != null && backImage != null && !isUploading;

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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ImageSlot(
                  label: 'Ön Yüz',
                  file: frontImage,
                  onPick: onPickFront,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSlot(
                  label: 'Arka Yüz',
                  file: backImage,
                  onPick: onPickBack,
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 16),
            helper!,
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: isUploading ? 'Yükleniyor...' : 'Yükle',
                  icon: isUploading ? Icons.hourglass_empty : Icons.cloud_upload,
                  onPressed: canUpload ? onUpload : () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onPick;

  const _ImageSlot({
    required this.label,
    required this.file,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 110,
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              child: file == null
                  ? const Center(
                      child: Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                    )
                  : Image.file(
                      file!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library),
          label: Text(file == null ? 'Seç' : 'Değiştir'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;

  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('. ', style: TextStyle(color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final String fileName;

  const _FilePreview({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CameraCaptureScreen extends StatefulWidget {
  final String title;
  final String hint;

  const CameraCaptureScreen({
    super.key,
    required this.title,
    required this.hint,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Kamera bulunamadi');
        return;
      }
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeFuture = controller.initialize();
      await _initializeFuture;
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Kamera baslatilamadi');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      await _initializeFuture;
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, File(file.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf çekilemedi. Tekrar deneyin.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
      ),
      body: _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder(
                  future: _initializeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        CustomPaint(
                          painter: _IdOverlayPainter(),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 16,
                          child: Text(
                            widget.hint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 28,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _capturing ? null : _capture,
                                child: Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: _capturing ? AppColors.textTertiary : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belgeyi çerçeveye hizalayın',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _IdOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final innerPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rectWidth = size.width * 0.78;
    final rectHeight = rectWidth / 1.58;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectWidth,
      height: rectHeight,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), borderPaint);

    // Inner guides (photo box + text lines)
    final photoRect = Rect.fromLTWH(
      rect.left + rect.width * 0.06,
      rect.top + rect.height * 0.18,
      rect.width * 0.28,
      rect.height * 0.64,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(photoRect, const Radius.circular(12)), innerPaint);

    final lineStartX = rect.left + rect.width * 0.38;
    final lineEndX = rect.right - rect.width * 0.06;
    final lineY1 = rect.top + rect.height * 0.32;
    final lineY2 = rect.top + rect.height * 0.48;
    final lineY3 = rect.top + rect.height * 0.64;
    canvas.drawLine(Offset(lineStartX, lineY1), Offset(lineEndX, lineY1), innerPaint);
    canvas.drawLine(Offset(lineStartX, lineY2), Offset(lineEndX, lineY2), innerPaint);
    canvas.drawLine(Offset(lineStartX, lineY3), Offset(lineEndX, lineY3), innerPaint);

    const corner = 26.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(corner, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, corner), cornerPaint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-corner, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, corner), cornerPaint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(corner, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -corner), cornerPaint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-corner, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -corner), cornerPaint);

    final crossPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    final center = rect.center;
    canvas.drawLine(center + const Offset(-16, 0), center + const Offset(16, 0), crossPaint);
    canvas.drawLine(center + const Offset(0, -16), center + const Offset(0, 16), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
