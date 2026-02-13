import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../auth/domain/auth_models.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
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
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Web profil fotograf yukleme yakinda eklenecek.'),
        ),
      );
      return;
    }

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
      if (!kIsWeb && _selectedPhoto != null) {
        photoOk = await ref
            .read(authProvider.notifier)
            .uploadProfilePhoto(_selectedPhoto!);
      }

      final preferences = DriverPreferences(
        music: _musicController.text.trim().isEmpty
            ? null
            : _musicController.text.trim(),
        smoking: _smoking,
        pets: _pets,
        ac: _ac,
        chattiness: _chattiness,
      );

      final profileOk = await ref.read(authProvider.notifier).updateProfile(
            fullName: _nameController.text.trim(),
            bio: _bioController.text.trim(),
            preferences: preferences,
          );

      if (!mounted) return;
      final success = profileOk && photoOk;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Profil guncellendi.' : 'Guncelleme basarisiz.'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        ref.invalidate(currentUserProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final networkPhoto = user?.profilePhotoUrl;

    if (kIsWeb) {
      return _buildWeb(networkPhoto: networkPhoto);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Bilgileri')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildPhotoCard(networkPhoto: networkPhoto, webMode: false),
            const SizedBox(height: 16),
            _buildFormCard(webMode: false),
          ],
        ),
      ),
    );
  }

  Widget _buildWeb({required String? networkPhoto}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Profil Bilgileri',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F3A30),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/profile'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Profile Don'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _logout,
                        icon: const Icon(Icons.logout),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Cikis Yap'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Web profil paneli. Zorunlu alanlari tamamlayip kaydedin.',
                    style: TextStyle(
                      color: Color(0xFF4E665C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPhotoCard(
                            networkPhoto: networkPhoto, webMode: true),
                        const SizedBox(height: 14),
                        _buildFormCard(webMode: true),
                      ],
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

  Widget _buildPhotoCard(
      {required String? networkPhoto, required bool webMode}) {
    final card = Column(
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
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: Colors.white, size: 42),
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
              label: Text(webMode ? 'Fotograf Yukle' : 'Fotograf Yukle'),
            ),
            if (_selectedPhoto != null)
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _selectedPhoto = null),
                icon: const Icon(Icons.close),
                label: const Text('Secimi Temizle'),
              ),
          ],
        ),
        if (webMode)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Not: Webde dogrudan fotograf yukleme destegi sinirlidir.',
              style: TextStyle(color: Color(0xFF6A7F74), fontSize: 12),
            ),
          ),
      ],
    );

    if (webMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: card,
      );
    }

    return GlassContainer(padding: const EdgeInsets.all(20), child: card);
  }

  Widget _buildFormCard({required bool webMode}) {
    final titleColor =
        webMode ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        webMode ? const Color(0xFF4E665C) : AppColors.textSecondary;

    final form = Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            style: TextStyle(color: titleColor),
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
            style: TextStyle(color: titleColor),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Hakkimda',
              hintText: 'Kisa bir aciklama',
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Surucu Tercihleri',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _smoking,
            onChanged: (next) => setState(() => _smoking = next),
            title: Text(
              'Sigara molasi olabilir',
              style: TextStyle(color: titleColor),
            ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile.adaptive(
            value: _pets,
            onChanged: (next) => setState(() => _pets = next),
            title: Text(
              'Evcil hayvan kabul ederim',
              style: TextStyle(color: titleColor),
            ),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile.adaptive(
            value: _ac,
            onChanged: (next) => setState(() => _ac = next),
            title: Text(
              'Klima acik olabilir',
              style: TextStyle(color: titleColor),
            ),
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
            decoration:
                const InputDecoration(labelText: 'Yolculukta sohbet duzeyi'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _musicController,
            style: TextStyle(color: titleColor),
            decoration: const InputDecoration(
              labelText: 'Muzik tercihi',
              hintText: 'Orn: Pop, Slow, Sessiz',
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              webMode
                  ? 'Degisiklikleri kaydettikten sonra profil kartina donerek kontrol edin.'
                  : 'Degisiklikler hemen profil sayfasina yansir.',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
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
    );

    if (webMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: form,
      );
    }

    return GlassContainer(padding: const EdgeInsets.all(20), child: form);
  }
}
