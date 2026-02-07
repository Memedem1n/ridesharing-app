import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final user = ref.watch(currentUserProvider);
    final isVerified = user?.isVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
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
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profil fotoğrafı yakında eklenecek.')),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'Kullanıcı',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 16, color: isVerified ? AppColors.success : AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Onaylı Profil' : 'Doğrulama Bekliyor',
                        style: TextStyle(color: isVerified ? AppColors.success : AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(label: 'Yolculuk', value: '${user?.totalTrips ?? 0}'),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(label: 'Puan', value: (user?.ratingAvg ?? 0).toStringAsFixed(1)),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(label: 'Üyelik', value: user == null ? '-' : 'Yeni'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),

            // Menu Items
            _MenuItem(icon: Icons.person_outline, title: strings.profileEdit, onTap: () => context.push('/profile-details')),
            _MenuItem(icon: Icons.directions_car_outlined, title: strings.myVehicles, onTap: () => context.push('/my-vehicles')),
            _MenuItem(icon: Icons.history, title: strings.tripHistory, onTap: () => context.push('/trip-history')),
            _MenuItem(icon: Icons.account_balance_wallet_outlined, title: strings.wallet, subtitle: '₺ 0,00', onTap: () => context.push('/wallet')),
            _MenuItem(icon: Icons.credit_card_outlined, title: strings.paymentMethods, onTap: () => context.push('/payment-methods')),
            const Divider(),
            _MenuItem(icon: Icons.notifications_outlined, title: strings.notificationSettings, onTap: () => context.push('/settings')),
            _MenuItem(icon: Icons.shield_outlined, title: strings.security, onTap: () => context.push('/security')),
            _MenuItem(icon: Icons.help_outline, title: strings.helpSupport, onTap: () => context.push('/help')),
            _MenuItem(icon: Icons.info_outline, title: strings.about, onTap: () => context.push('/about')),
            const Divider(),
            _MenuItem(
              icon: Icons.logout,
              title: strings.logout,
              color: AppColors.error,
              onTap: () => _showLogoutDialog(context, ref),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final strings = ref.read(appStringsProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.logoutConfirmTitle),
        content: Text(strings.logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(strings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(strings.logout),
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
