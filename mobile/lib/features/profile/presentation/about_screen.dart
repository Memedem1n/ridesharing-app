import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWeb(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hakkinda')),
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
                        'Hakkinda',
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
                      FilledButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(children: _buildSections(glassMode: false)),
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
      const SizedBox(height: 12),
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Misyon',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Bos koltuklari verimli kullanarak seyahat maliyetini dusurmek ve guvenilir eslesme saglamak.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 14),
            Text(
              'Guvenlik Yaklasimi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kimlik dogrulama, rezervasyon odeme dogrulamasi, canli konum kilidi ve puanlama sistemi birlikte calisir.',
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
              'Yasal Bilgilendirme',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Bu ekran bilgilendirme amaclidir. KVKK, kullanim kosullari ve acik riza metinleri yayin oncesi son haline cekilecektir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ];
  }
}
