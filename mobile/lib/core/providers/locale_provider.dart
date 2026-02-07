import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';

const _localeKey = 'app_locale';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('tr', 'TR')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null) return;
    state = _fromCode(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Locale _fromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en', 'US');
      case 'ar':
        return const Locale('ar', 'SA');
      default:
        return const Locale('tr', 'TR');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return AppStrings(locale);
});
