import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(currentUserProvider);
    if (user != null && _nameController.text.isEmpty) {
      _nameController.text = user.fullName;
      _bioController.text = user.bio ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final success = await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameController.text,
        bio: _bioController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Profil güncellendi' : 'Güncelleme başarısız'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Bilgileri')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassStroke),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'Kullanıcı',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'email@example.com',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Zorunlu alan';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Hakkımda',
                        hintText: 'Kısa bir açıklama',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: _saving ? 'Kaydediliyor...' : 'Kaydet',
                        icon: Icons.save,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
