import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkinda')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GlassContainer(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PaylasYol',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Guvenli ve planli sehirlerarasi paylasimli yolculuk platformu.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Surum: 0.9.0-beta',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Build tarihi: 2026-02-09',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Not (2026-02-09): Bu icerik gecici demo metnidir; hukuk ve operasyon metinleri canliya cikmadan once guncellenecek.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            GlassContainer(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Misyon', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Bos koltuklari verimli kullanarak seyahat maliyetini dusurmek ve guvenilir eslesme saglamak.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 14),
                  Text('Guvenlik Yaklasimi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Kimlik dogrulama, rezervasyon odeme dogrulamasi, canli konum kilidi ve puanlama sistemi birlikte calisir.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            GlassContainer(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yasal Bilgilendirme', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Bu ekran bilgilendirme amaclidir. KVKK, kullanim kosullari ve acik riza metinleri yayin oncesi son haline cekilecektir.',
                    style: TextStyle(color: AppColors.textSecondary),
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
