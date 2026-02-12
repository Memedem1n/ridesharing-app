// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final locale = ref.watch(localeProvider);
    final code = locale.languageCode;

    if (kIsWeb) {
      return _buildWeb(context, ref, strings, code);
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: _LanguageSection(strings: strings, code: code),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeb(
      BuildContext context, WidgetRef ref, dynamic strings, String code) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        strings.settingsTitle,
                        style: const TextStyle(
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
                      FilledButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Web paneli ayarlari. Dil secimini buradan yapabilirsiniz.',
                    style: const TextStyle(
                      color: Color(0xFF4E665C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE6E1)),
                      ),
                      child: SingleChildScrollView(
                        child: _LanguageSection(strings: strings, code: code),
                      ),
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
}

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection({required this.strings, required this.code});

  final dynamic strings;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.language,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _LanguageTile(
          title: strings.languageTurkish,
          value: 'tr',
          groupValue: code,
          onChanged: () => ref
              .read(localeProvider.notifier)
              .setLocale(const Locale('tr', 'TR')),
        ),
        _LanguageTile(
          title: strings.languageEnglish,
          value: 'en',
          groupValue: code,
          onChanged: () => ref
              .read(localeProvider.notifier)
              .setLocale(const Locale('en', 'US')),
        ),
        _LanguageTile(
          title: strings.languageArabic,
          value: 'ar',
          groupValue: code,
          onChanged: () => ref
              .read(localeProvider.notifier)
              .setLocale(const Locale('ar', 'SA')),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final VoidCallback onChanged;

  const _LanguageTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (_) => onChanged(),
      activeColor: AppColors.primary,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
