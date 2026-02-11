import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  AppStrings(this.locale);

  static const supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
    Locale('ar', 'SA'),
  ];

  static const _strings = <String, Map<String, String>>{
    'tr': {
      'app_title': 'Yoliva',
      'nav_home': 'Ana Sayfa',
      'nav_search': 'Ara',
      'nav_bookings': 'Rezervasyonlar',
      'nav_messages': 'Mesajlar',
      'nav_profile': 'Profil',
      'action_create_trip': 'Yolculuk Paylaş',
      'login_title': 'Hoş Geldiniz',
      'login_subtitle': 'Yolculuğunuza devam edin',
      'email_or_phone': 'E-posta veya Telefon',
      'password': 'Şifre',
      'forgot_password': 'Şifremi Unuttum',
      'login': 'Giriş Yap',
      'register': 'Kayıt Ol',
      'no_account': 'Hesabın yok mu?',
      'already_have_account': 'Zaten hesabın var mı?',
      'field_required': 'Bu alan gerekli',
      'password_required': 'Şifre gerekli',
      'password_min': 'Şifre en az 6 karakter olmalı',
      'register_title': 'Hesap Oluştur',
      'register_subtitle': 'Yolculuk deneyiminizi başlatın',
      'name': 'Ad Soyad',
      'email': 'E-posta',
      'phone': 'Telefon',
      'confirm_password': 'Şifre Tekrar',
      'password_mismatch': 'Şifreler uyuşmuyor',
      'settings_title': 'Ayarlar',
      'language': 'Dil',
      'language_turkish': 'Türkçe',
      'language_english': 'İngilizce',
      'language_arabic': 'Arapça',
      'profile_title': 'Profil',
      'profile_edit': 'Profili Düzenle',
      'my_vehicles': 'Araçlarım',
      'trip_history': 'Yolculuklarım',
      'wallet': 'Cüzdan',
      'payment_methods': 'Ödeme Yöntemleri',
      'notification_settings': 'Bildirim Ayarları',
      'security': 'Güvenlik',
      'help_support': 'Yardım ve Destek',
      'about': 'Hakkında',
      'logout': 'Çıkış Yap',
      'logout_confirm_title': 'Çıkış Yap',
      'logout_confirm_message':
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
      'cancel': 'İptal',
      'confirm': 'Onayla',
    },
    'en': {
      'app_title': 'Yoliva',
      'nav_home': 'Home',
      'nav_search': 'Search',
      'nav_bookings': 'Bookings',
      'nav_messages': 'Messages',
      'nav_profile': 'Profile',
      'action_create_trip': 'Share Trip',
      'login_title': 'Welcome Back',
      'login_subtitle': 'Continue your trip',
      'email_or_phone': 'Email or Phone',
      'password': 'Password',
      'forgot_password': 'Forgot Password',
      'login': 'Log In',
      'register': 'Sign Up',
      'no_account': "Don't have an account?",
      'already_have_account': 'Already have an account?',
      'field_required': 'This field is required',
      'password_required': 'Password is required',
      'password_min': 'Password must be at least 6 characters',
      'register_title': 'Create Account',
      'register_subtitle': 'Start your next trip',
      'name': 'Full Name',
      'email': 'Email',
      'phone': 'Phone',
      'confirm_password': 'Confirm Password',
      'password_mismatch': 'Passwords do not match',
      'settings_title': 'Settings',
      'language': 'Language',
      'language_turkish': 'Turkish',
      'language_english': 'English',
      'language_arabic': 'Arabic',
      'profile_title': 'Profile',
      'profile_edit': 'Edit Profile',
      'my_vehicles': 'My Vehicles',
      'trip_history': 'My Trips',
      'wallet': 'Wallet',
      'payment_methods': 'Payment Methods',
      'notification_settings': 'Notification Settings',
      'security': 'Security',
      'help_support': 'Help & Support',
      'about': 'About',
      'logout': 'Log Out',
      'logout_confirm_title': 'Log Out',
      'logout_confirm_message': 'Are you sure you want to log out?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
    },
    'ar': {
      'app_title': 'Yoliva',
      'nav_home': 'الرئيسية',
      'nav_search': 'بحث',
      'nav_bookings': 'الحجوزات',
      'nav_messages': 'الرسائل',
      'nav_profile': 'الملف الشخصي',
      'action_create_trip': 'مشاركة رحلة',
      'login_title': 'مرحباً بعودتك',
      'login_subtitle': 'تابع رحلتك',
      'email_or_phone': 'البريد الإلكتروني أو الهاتف',
      'password': 'كلمة المرور',
      'forgot_password': 'نسيت كلمة المرور',
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'no_account': 'ليس لديك حساب؟',
      'already_have_account': 'لديك حساب بالفعل؟',
      'field_required': 'هذا الحقل مطلوب',
      'password_required': 'كلمة المرور مطلوبة',
      'password_min': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
      'register_title': 'إنشاء حساب',
      'register_subtitle': 'ابدأ رحلتك القادمة',
      'name': 'الاسم الكامل',
      'email': 'البريد الإلكتروني',
      'phone': 'الهاتف',
      'confirm_password': 'تأكيد كلمة المرور',
      'password_mismatch': 'كلمتا المرور غير متطابقتين',
      'settings_title': 'الإعدادات',
      'language': 'اللغة',
      'language_turkish': 'التركية',
      'language_english': 'الإنجليزية',
      'language_arabic': 'العربية',
      'profile_title': 'الملف الشخصي',
      'profile_edit': 'تعديل الملف الشخصي',
      'my_vehicles': 'مركباتي',
      'trip_history': 'رحلاتي',
      'wallet': 'المحفظة',
      'payment_methods': 'طرق الدفع',
      'notification_settings': 'إعدادات الإشعارات',
      'security': 'الأمان',
      'help_support': 'المساعدة والدعم',
      'about': 'حول',
      'logout': 'تسجيل الخروج',
      'logout_confirm_title': 'تسجيل الخروج',
      'logout_confirm_message': 'هل أنت متأكد من تسجيل الخروج؟',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
    },
  };

  String _t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['tr']?[key] ?? key;
  }

  String get appTitle => _t('app_title');
  String get navHome => _t('nav_home');
  String get navSearch => _t('nav_search');
  String get navBookings => _t('nav_bookings');
  String get navMessages => _t('nav_messages');
  String get navProfile => _t('nav_profile');
  String get actionCreateTrip => _t('action_create_trip');
  String get loginTitle => _t('login_title');
  String get loginSubtitle => _t('login_subtitle');
  String get emailOrPhone => _t('email_or_phone');
  String get password => _t('password');
  String get forgotPassword => _t('forgot_password');
  String get login => _t('login');
  String get register => _t('register');
  String get noAccount => _t('no_account');
  String get alreadyHaveAccount => _t('already_have_account');
  String get fieldRequired => _t('field_required');
  String get passwordRequired => _t('password_required');
  String get passwordMin => _t('password_min');
  String get registerTitle => _t('register_title');
  String get registerSubtitle => _t('register_subtitle');
  String get name => _t('name');
  String get email => _t('email');
  String get phone => _t('phone');
  String get confirmPassword => _t('confirm_password');
  String get passwordMismatch => _t('password_mismatch');
  String get settingsTitle => _t('settings_title');
  String get language => _t('language');
  String get languageTurkish => _t('language_turkish');
  String get languageEnglish => _t('language_english');
  String get languageArabic => _t('language_arabic');
  String get profileTitle => _t('profile_title');
  String get profileEdit => _t('profile_edit');
  String get myVehicles => _t('my_vehicles');
  String get tripHistory => _t('trip_history');
  String get wallet => _t('wallet');
  String get paymentMethods => _t('payment_methods');
  String get notificationSettings => _t('notification_settings');
  String get security => _t('security');
  String get helpSupport => _t('help_support');
  String get about => _t('about');
  String get logout => _t('logout');
  String get logoutConfirmTitle => _t('logout_confirm_title');
  String get logoutConfirmMessage => _t('logout_confirm_message');
  String get cancel => _t('cancel');
  String get confirm => _t('confirm');
}

