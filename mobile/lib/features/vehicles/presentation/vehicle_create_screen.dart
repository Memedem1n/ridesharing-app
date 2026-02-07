import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/animated_buttons.dart';

class VehicleCreateScreen extends ConsumerStatefulWidget {
  const VehicleCreateScreen({super.key});

  @override
  ConsumerState<VehicleCreateScreen> createState() => _VehicleCreateScreenState();
}

class _VehicleCreateScreenState extends ConsumerState<VehicleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  int _seats = 4;
  bool _hasAc = true;
  bool _allowsPets = false;
  bool _allowsSmoking = false;
  bool _saving = false;

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await ref.read(authTokenProvider.future);
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum bulunamadı. Lütfen tekrar giriş yapın.'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
      final service = ref.read(vehicleServiceProvider);

      final year = int.tryParse(_yearController.text.trim());
      if (year == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model yılı geçerli değil'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      await service.createVehicle({
        'licensePlate': _plateController.text.trim(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': year,
        'color': _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        'seats': _seats,
        'hasAc': _hasAc,
        'allowsPets': _allowsPets,
        'allowsSmoking': _allowsSmoking,
      }, token);

      ref.invalidate(myVehiclesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç eklendi'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      final apiError = ApiException.fromDioError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiError.message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                        _buildField(_plateController, 'Plaka', hint: '34ABC123'),
                        const SizedBox(height: 12),
                        _buildField(_brandController, 'Marka', hint: 'Toyota'),
                        const SizedBox(height: 12),
                        _buildField(_modelController, 'Model', hint: 'Corolla'),
                        const SizedBox(height: 12),
                        _buildField(_yearController, 'Model Yılı', hint: '2022', keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        _buildField(_colorController, 'Renk (opsiyonel)', hint: 'Beyaz'),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Koltuk Sayısı', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                            ),
                            Text('$_seats', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: _seats < 8 ? () => setState(() => _seats++) : null,
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _hasAc,
                          onChanged: (val) => setState(() => _hasAc = val),
                          title: const Text('Klima var', style: TextStyle(color: AppColors.textPrimary)),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                        SwitchListTile(
                          value: _allowsPets,
                          onChanged: (val) => setState(() => _allowsPets = val),
                          title: const Text('Evcil hayvan kabul', style: TextStyle(color: AppColors.textPrimary)),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                        SwitchListTile(
                          value: _allowsSmoking,
                          onChanged: (val) => setState(() => _allowsSmoking = val),
                          title: const Text('Sigara kabul', style: TextStyle(color: AppColors.textPrimary)),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      validator: (value) {
        if (label.contains('opsiyonel')) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Zorunlu alan';
        }
        return null;
      },
    );
  }
}
