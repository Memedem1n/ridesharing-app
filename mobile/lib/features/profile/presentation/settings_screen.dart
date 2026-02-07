import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final locale = ref.watch(localeProvider);
    final code = locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                    onChanged: () => ref.read(localeProvider.notifier).setLocale(const Locale('tr', 'TR')),
                  ),
                  _LanguageTile(
                    title: strings.languageEnglish,
                    value: 'en',
                    groupValue: code,
                    onChanged: () => ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US')),
                  ),
                  _LanguageTile(
                    title: strings.languageArabic,
                    value: 'ar',
                    groupValue: code,
                    onChanged: () => ref.read(localeProvider.notifier).setLocale(const Locale('ar', 'SA')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
