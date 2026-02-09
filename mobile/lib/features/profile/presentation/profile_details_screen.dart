import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../auth/domain/auth_models.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _musicController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _saving = false;
  bool _initialized = false;

  bool _smoking = false;
  bool _pets = false;
  bool _ac = true;
  String _chattiness = 'normal';

  File? _selectedPhoto;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _musicController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.fullName;
      _bioController.text = user.bio ?? '';
      _musicController.text = user.preferences.music ?? '';
      _smoking = user.preferences.smoking ?? false;
      _pets = user.preferences.pets ?? false;
      _ac = user.preferences.ac ?? true;
      _chattiness = user.preferences.chattiness ?? 'normal';
    }
    _initialized = true;
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (picked == null) return;
    setState(() => _selectedPhoto = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      bool photoOk = true;
      if (_selectedPhoto != null) {
        photoOk = await ref.read(authProvider.notifier).uploadProfilePhoto(_selectedPhoto!);
      }

      final preferences = DriverPreferences(
        music: _musicController.text.trim().isEmpty ? null : _musicController.text.trim(),
        smoking: _smoking,
        pets: _pets,
        ac: _ac,
        chattiness: _chattiness,
      );

      final profileOk = await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameController.text,
        bio: _bioController.text,
        preferences: preferences,
      );

      if (mounted) {
        final success = photoOk && profileOk;
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
    final networkPhoto = user?.profilePhotoUrl;

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
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassStroke),
                    ),
                    child: ClipOval(
                      child: _selectedPhoto != null
                          ? Image.file(_selectedPhoto!, fit: BoxFit.cover)
                          : (networkPhoto != null && networkPhoto.isNotEmpty
                              ? Image.network(
                                  networkPhoto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.person, color: Colors.white, size: 42),
                                )
                              : const Icon(Icons.person, color: Colors.white, size: 42)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickPhoto,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Fotoğraf Yükle'),
                      ),
                      if (_selectedPhoto != null)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => setState(() => _selectedPhoto = null),
                          icon: const Icon(Icons.close),
                          label: const Text('Seçimi Temizle'),
                        ),
                    ],
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
                      decoration: const InputDecoration(labelText: 'Ad Soyad'),
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
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sürücü Tercihleri',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: _smoking,
                      onChanged: (next) => setState(() => _smoking = next),
                      title: const Text('Sigara molası olabilir',
                          style: TextStyle(color: AppColors.textPrimary)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                    ),
                    SwitchListTile.adaptive(
                      value: _pets,
                      onChanged: (next) => setState(() => _pets = next),
                      title: const Text('Evcil hayvan kabul ederim',
                          style: TextStyle(color: AppColors.textPrimary)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                    ),
                    SwitchListTile.adaptive(
                      value: _ac,
                      onChanged: (next) => setState(() => _ac = next),
                      title: const Text('Klima açık olabilir',
                          style: TextStyle(color: AppColors.textPrimary)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _chattiness,
                      onChanged: (next) {
                        if (next != null) setState(() => _chattiness = next);
                      },
                      items: const [
                        DropdownMenuItem(value: 'quiet', child: Text('Sessiz')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'chatty', child: Text('Sohbet sever')),
                      ],
                      decoration: const InputDecoration(labelText: 'Yolculukta sohbet düzeyi'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _musicController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Müzik tercihi',
                        hintText: 'Örn: Pop, Slow, Sessiz',
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
