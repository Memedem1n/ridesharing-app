import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';

class VehicleCreateScreen extends ConsumerStatefulWidget {
  const VehicleCreateScreen({super.key});

  @override
  ConsumerState<VehicleCreateScreen> createState() =>
      _VehicleCreateScreenState();
}

class _VehicleCreateScreenState extends ConsumerState<VehicleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _plateController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _ownerNameController = TextEditingController();

  int _seats = 4;
  bool _hasAc = true;
  bool _allowsPets = false;
  bool _allowsSmoking = false;
  bool _isOwnVehicle = true;
  bool _saving = false;

  String? _ownerRelation;
  XFile? _registrationImage;

  static const List<_OwnerRelationOption> _ownerRelations = [
    _OwnerRelationOption(value: 'father', label: 'Baba'),
    _OwnerRelationOption(value: 'mother', label: 'Anne'),
    _OwnerRelationOption(value: 'uncle', label: 'Amca / Dayı'),
    _OwnerRelationOption(value: 'aunt', label: 'Hala / Teyze'),
    _OwnerRelationOption(value: 'sibling', label: 'Kardeş'),
    _OwnerRelationOption(value: 'spouse', label: 'Eş'),
    _OwnerRelationOption(value: 'grandparent', label: 'Dede / Nine'),
  ];

  String _normalizeTrKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u0307', '') // remove Turkish dotted-i combining mark
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  String _extractSurname(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 2) return '';
    return parts.last;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _registrationNumberController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _pickRegistrationImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 88,
    );
    if (image == null) return;
    setState(() => _registrationImage = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registrationImage == null) {
      _showError('Ruhsat görseli yüklemeden devam edemezsiniz.');
      return;
    }
    if (!_isOwnVehicle) {
      final currentUser = ref.read(currentUserProvider);
      final userSurname = _extractSurname(currentUser?.fullName ?? '');
      final ownerSurname = _extractSurname(_ownerNameController.text.trim());
      if (userSurname.isEmpty) {
        _showError('Profil ad/soyad bilginiz eksik. Lütfen profilinizi güncelleyin.');
        return;
      }
      if (ownerSurname.isEmpty) {
        _showError('Araç sahibi ad soyad şeklinde girilmelidir.');
        return;
      }
      if (_normalizeTrKey(userSurname) != _normalizeTrKey(ownerSurname)) {
        _showError('Araç sahibi soyadı sizin soyadınızla eşleşmeli.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final token = await ref.read(authTokenProvider.future);
      if (token == null) {
        _showError('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }

      final year = int.tryParse(_yearController.text.trim());
      if (year == null) {
        _showError('Model yılı geçerli değil.');
        return;
      }

      final service = ref.read(vehicleServiceProvider);
      final registrationImageUrl =
          await service.uploadRegistrationXFile(_registrationImage!, token);

      if (registrationImageUrl == null || registrationImageUrl.trim().isEmpty) {
        _showError('Ruhsat görseli yüklenemedi.');
        return;
      }

      await service.createVehicle({
        'licensePlate': _plateController.text.trim(),
        'registrationNumber': _registrationNumberController.text.trim(),
        'ownershipType': _isOwnVehicle ? 'self' : 'relative',
        'ownerFullName':
            _isOwnVehicle ? null : _ownerNameController.text.trim(),
        'ownerRelation': _isOwnVehicle ? null : _ownerRelation,
        'registrationImage': registrationImageUrl,
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': year,
        'color': _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        'seats': _seats,
        'hasAc': _hasAc,
        'allowsPets': _allowsPets,
        'allowsSmoking': _allowsSmoking,
      }, token);

      ref.invalidate(myVehiclesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Araç başarıyla eklendi.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioError(e);
      _showError(apiError.message);
    } catch (e) {
      _showError('Araç kaydı sırasında hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Araç Ekle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildField(
                          _plateController,
                          'Plaka',
                          hint: '34ABC123',
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          _registrationNumberController,
                          'Ruhsat Numarası',
                          hint: '34-AB-123456',
                        ),
                        const SizedBox(height: 12),
                        _buildField(_brandController, 'Marka', hint: 'Toyota'),
                        const SizedBox(height: 12),
                        _buildField(_modelController, 'Model', hint: 'Corolla'),
                        const SizedBox(height: 12),
                        _buildField(
                          _yearController,
                          'Model Yılı',
                          hint: '2022',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          _colorController,
                          'Renk (opsiyonel)',
                          hint: 'Beyaz',
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildOwnershipSection(),
                  const SizedBox(height: 16),
                  _buildRegistrationImagePicker(),
                  const SizedBox(height: 16),
                  _buildVehiclePreferences(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: _saving ? 'Kaydediliyor...' : 'Aracı Kaydet',
                      icon: Icons.save,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnershipSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Araç sahibi benim',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _isOwnVehicle,
                onChanged: (next) {
                  setState(() {
                    _isOwnVehicle = next;
                    if (next) {
                      _ownerRelation = null;
                      _ownerNameController.clear();
                    }
                  });
                },
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (!_isOwnVehicle) ...[
            const SizedBox(height: 8),
            const Text(
              'Not: Size ait olmayan araçlarda, sadece soyadı eşleşen yakın akrabanızın aracı eklenebilir (baba/anne/kardeş/eş/dayı/amca vb.).',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _buildField(
              _ownerNameController,
              'Araç Sahibi Ad Soyad',
              hint: 'Ahmet Yılmaz',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ownerRelation,
              decoration: const InputDecoration(labelText: 'Yakınlık Derecesi'),
              items: _ownerRelations
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (next) => setState(() => _ownerRelation = next),
              validator: (value) {
                if (_isOwnVehicle) return null;
                if (value == null || value.isEmpty) {
                  return 'Yakınlık derecesi zorunludur';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08);
  }

  Widget _buildRegistrationImagePicker() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruhsat Görseli',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Araç ruhsatının net göründüğü bir fotoğraf yükleyin.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickRegistrationImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glassBgDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _registrationImage == null
                      ? AppColors.glassStroke
                      : AppColors.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _registrationImage == null
                        ? Icons.upload_file_outlined
                        : Icons.check_circle,
                    color: _registrationImage == null
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _registrationImage == null
                          ? 'Ruhsat görseli seçin'
                          : _registrationImage!.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickRegistrationImage,
                    child: const Text('Seç'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08);
  }

  Widget _buildVehiclePreferences() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Araç Özellikleri',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Koltuk Sayısı',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              IconButton(
                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_seats',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: _seats < 8 ? () => setState(() => _seats++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          SwitchListTile(
            value: _hasAc,
            onChanged: (next) => setState(() => _hasAc = next),
            title: const Text(
              'Klima var',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            value: _allowsPets,
            onChanged: (next) => setState(() => _allowsPets = next),
            title: const Text(
              'Evcil hayvan kabul',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            value: _allowsSmoking,
            onChanged: (next) => setState(() => _allowsSmoking = next),
            title: const Text(
              'Sigara kabul',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.08);
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        final text = value?.trim() ?? '';
        final optional = label.toLowerCase().contains('opsiyonel');
        if (optional) return null;
        if (text.isEmpty) return 'Zorunlu alan';
        if (label == 'Araç Sahibi Ad Soyad' && !_isOwnVehicle) {
          if (text.split(' ').length < 2) {
            return 'Ad ve soyad girin';
          }
        }
        return null;
      },
    );
  }
}

class _OwnerRelationOption {
  final String value;
  final String label;

  const _OwnerRelationOption({required this.value, required this.label});
}
