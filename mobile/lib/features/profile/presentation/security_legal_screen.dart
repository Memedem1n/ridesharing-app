import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class SecurityLegalScreen extends StatelessWidget {
  const SecurityLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWeb(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Guvenlik ve Yasal')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _buildSections(glassMode: true),
        ),
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
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
                        'Guvenlik ve Yasal Metinler',
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
                        onPressed: () => context.go('/help'),
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Destek'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Asagidaki metinler yayin adayi iceriktir. Nihai hukuk onayi sonrasi surumlenir.',
                    style: TextStyle(
                      color: Color(0xFF4E665C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: _buildSections(glassMode: false),
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

  List<Widget> _buildSections({required bool glassMode}) {
    Widget wrap(Widget child) {
      if (glassMode) {
        return GlassContainer(padding: const EdgeInsets.all(16), child: child);
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: child,
      );
    }

    return [
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Hesap Guvenligi ve Acil Durum',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Supheli giris tespiti, cihaz token kontrolu ve oturum yenileme guvenlik politikalari aktif olarak izlenir. Acil guvenlik ihlali durumunda hesap gecici olarak kilitlenebilir ve kullaniciya destek kanallari uzerinden bilgilendirme yapilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Acil guvenlik bildirimleri 7/24 kayda alinir ve olay kaydi olusturulur.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KVKK Aydinlatma Ozeti',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kimlik, iletisim, arac ve rezervasyon verileri hizmetin sunulmasi, guvenlik dogrulamasi, yasal yukumluluklerin yerine getirilmesi ve operasyon sureclerinin yurutilmesi amaclariyla islenir. Veriler yalnizca gerekli oldugu sure boyunca saklanir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Kullanici; erisim, duzeltme, silme, islemeyi sinirlama ve basvuru haklarini destek kanallarindan kullanabilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kullanim Kosullari Ozeti',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Platformdaki tum ilan, rezervasyon ve mesajlasma sureclerinde gercek bilgi kullanimi zorunludur. Kullanici, yasal olmayan icerik paylasmamayi ve diger kullanicilarin haklarini ihlal etmemeyi kabul eder.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Kurallara aykiri davranis tespiti halinde icerik kaldirma, hesap kisitlama veya kalici engelleme uygulanabilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acik Riza ve Veri Isleme',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Acilikla gerekli olmayan isleme faaliyetleri (kampanya bildirimleri, gelistirilmis analiz vb.) icin acik riza alinmasi esastir. Kullanici acik rizasini diledigi anda geri cekebilir; geri cekme sonrasi ilgili isleme faaliyetleri durdurulur.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Yasal saklama zorunlulugu bulunan kayitlar acik riza geri cekilse dahi mevzuatin izin verdigi sinirlar icinde korunabilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yururluk ve Surum Notu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Metin surumu: 2026-02-13 draft v1. Hukuki nihai onay sonrasi surum numarasi ve degisiklik tarihi ayrica duyurulur.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ];
  }
}
