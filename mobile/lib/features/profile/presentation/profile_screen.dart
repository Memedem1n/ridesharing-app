import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                      Positioned(
                        bottom: 0, right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: IconButton(icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white), onPressed: () {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Mehmet Yılmaz', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Onaylı Profil', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(label: 'Yolculuk', value: '23'),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(label: 'Puan', value: '4.8'),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(label: 'Üyelik', value: '2 yıl'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Menu Items
            _MenuItem(icon: Icons.person_outline, title: 'Profili Düzenle', onTap: () {}),
            _MenuItem(icon: Icons.directions_car_outlined, title: 'Araçlarım', onTap: () {}),
            _MenuItem(icon: Icons.history, title: 'Yolculuk Geçmişi', onTap: () {}),
            _MenuItem(icon: Icons.account_balance_wallet_outlined, title: 'Cüzdan', subtitle: '₺ 0,00', onTap: () {}),
            _MenuItem(icon: Icons.credit_card_outlined, title: 'Ödeme Yöntemleri', onTap: () {}),
            const Divider(),
            _MenuItem(icon: Icons.notifications_outlined, title: 'Bildirim Ayarları', onTap: () {}),
            _MenuItem(icon: Icons.shield_outlined, title: 'Güvenlik', onTap: () {}),
            _MenuItem(icon: Icons.help_outline, title: 'Yardım ve Destek', onTap: () {}),
            _MenuItem(icon: Icons.info_outline, title: 'Hakkında', onTap: () {}),
            const Divider(),
            _MenuItem(
              icon: Icons.logout,
              title: 'Çıkış Yap',
              color: AppColors.error,
              onTap: () => _showLogoutDialog(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, this.subtitle, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
