import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label panoya kopyalandi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWeb(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yardim ve Destek')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _buildSections(context, glassMode: true),
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
                        'Yardim ve Destek',
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
                        onPressed: () => context.go('/security'),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Guvenlik ve Yasal'),
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
                    child: ListView(
                      children: _buildSections(context, glassMode: false),
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

  List<Widget> _buildSections(BuildContext context, {required bool glassMode}) {
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
                Icon(Icons.support_agent, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Destek Merkezi',
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
              'Canli operasyonda 09:00-23:00 saatleri arasinda ortalama ilk yanit suresi 7 dakikadir. Acil guvenlik talepleri oncelikli hatta aktarilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Iletisim Kanallari',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _SupportRow(
              icon: Icons.email_outlined,
              title: 'E-posta',
              value: 'support@yoliva.app',
              onCopy: () => _copy(context, 'support@yoliva.app', 'E-posta'),
            ),
            _SupportRow(
              icon: Icons.chat_outlined,
              title: 'WhatsApp Hatti',
              value: '+90 850 555 00 21',
              onCopy: () => _copy(context, '+908505550021', 'Telefon'),
            ),
            _SupportRow(
              icon: Icons.report_problem_outlined,
              title: 'Acil Guvenlik',
              value: '+90 312 999 88 77',
              onCopy: () => _copy(context, '+903129998877', 'Acil hat'),
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
              'Sik Sorulan Sorular',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            _FaqTile(
              q: 'Odeme yapildi ama rezervasyon gorunmuyor. Ne yapmaliyim?',
              a: 'Rezervasyonlar sayfasini yenileyin. 2 dakika icinde dusmezse odeme kimligi ile destek kaydi acin; ekip manuel eslestirme yapar.',
            ),
            _FaqTile(
              q: 'Surucu gelmedi veya rota degisti, nasil itiraz ederim?',
              a: 'Rezervasyon detayindaki "Itiraz Et" akisini kullanin. Itirazlar kayit numarasi ile takip edilir.',
            ),
            _FaqTile(
              q: 'Canli konumu neden goremedim?',
              a: 'Canli konum guvenlik geregi yalnizca onayli ve odemesi tamamlanmis rezervasyonlarda acilir.',
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
              'Yasal Basvuru ve Talepler',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'KVKK kapsamindaki veri erisim, duzeltme, silme ve itiraz taleplerinizi destek kanallarindan iletebilirsiniz. Talebiniz kayit numarasi ile takip edilir ve mevzuat sureleri icinde yanitlanir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ];
  }
}

class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onCopy;

  const _SupportRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle:
          Text(value, style: const TextStyle(color: AppColors.textSecondary)),
      trailing: IconButton(
        icon: const Icon(Icons.copy, color: AppColors.textSecondary),
        onPressed: onCopy,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;

  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.glassBgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
