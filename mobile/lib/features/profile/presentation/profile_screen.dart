import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../auth/domain/auth_models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final user = ref.watch(currentUserProvider);
    final isVerified = user?.isVerified ?? false;
    if (kIsWeb) {
      return _buildWebProfile(context, ref, strings, user, isVerified);
    }

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
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user?.profilePhotoUrl != null &&
                                user!.profilePhotoUrl!.isNotEmpty
                            ? NetworkImage(user.profilePhotoUrl!)
                            : null,
                        child: user?.profilePhotoUrl == null ||
                                user!.profilePhotoUrl!.isEmpty
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                            onPressed: () => context.push('/profile-details'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'Kullanıcı',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified,
                          size: 16,
                          color: isVerified
                              ? AppColors.success
                              : AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Onaylı Profil' : 'Doğrulama Bekliyor',
                        style: TextStyle(
                            color: isVerified
                                ? AppColors.success
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                          label: 'Yolculuk', value: '${user?.totalTrips ?? 0}'),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(
                          label: 'Puan',
                          value: (user?.ratingAvg ?? 0).toStringAsFixed(1)),
                      Container(width: 1, height: 40, color: AppColors.border),
                      _StatItem(
                          label: 'Üyelik', value: user == null ? '-' : 'Yeni'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (user != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildPreferenceChips(user.preferences),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),

            // Menu Items
            _MenuItem(
                icon: Icons.person_outline,
                title: strings.profileEdit,
                onTap: () => context.push('/profile-details')),
            _MenuItem(
                icon: Icons.directions_car_outlined,
                title: strings.myVehicles,
                onTap: () => context.push('/my-vehicles')),
            _MenuItem(
                icon: Icons.history,
                title: strings.tripHistory,
                onTap: () => context.push('/trip-history')),
            _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                title: strings.wallet,
                subtitle: '₺ 0,00',
                onTap: () => context.push('/wallet')),
            _MenuItem(
                icon: Icons.credit_card_outlined,
                title: strings.paymentMethods,
                onTap: () => context.push('/payment-methods')),
            const Divider(),
            _MenuItem(
                icon: Icons.notifications_outlined,
                title: strings.notificationSettings,
                onTap: () => context.push('/settings')),
            _MenuItem(
                icon: Icons.shield_outlined,
                title: strings.security,
                onTap: () => context.push('/security')),
            _MenuItem(
                icon: Icons.help_outline,
                title: strings.helpSupport,
                onTap: () => context.push('/help')),
            _MenuItem(
                icon: Icons.info_outline,
                title: strings.about,
                onTap: () => context.push('/about')),
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

  Widget _buildWebProfile(
    BuildContext context,
    WidgetRef ref,
    dynamic strings,
    User? user,
    bool isVerified,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final summary = _buildWebProfileSummary(user, isVerified);
                  final actions =
                      _buildWebProfileActions(context, ref, strings);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            strings.profileTitle,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F3A30),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Ana Sayfa'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/reservations'),
                            icon:
                                const Icon(Icons.confirmation_number_outlined),
                            label: const Text('Rezervasyonlar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/search'),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Geri'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Ayarlar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (stacked) ...[
                        summary,
                        const SizedBox(height: 14),
                        actions,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 340, child: summary),
                            const SizedBox(width: 14),
                            Expanded(child: actions),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebProfileSummary(User? user, bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundImage: user?.profilePhotoUrl != null &&
                      user!.profilePhotoUrl!.isNotEmpty
                  ? NetworkImage(user.profilePhotoUrl!)
                  : null,
              child: user?.profilePhotoUrl == null ||
                      user!.profilePhotoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              user?.fullName ?? 'Kullanici',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F3A30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isVerified
                    ? const Color(0xFFDDF4E8)
                    : const Color(0xFFE8ECEA),
              ),
              child: Text(
                isVerified ? 'Onayli Profil' : 'Dogrulama Bekliyor',
                style: TextStyle(
                  color: isVerified
                      ? const Color(0xFF1A7D4E)
                      : const Color(0xFF5A6A62),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _StatItem(
                      label: 'Yolculuk', value: '${user?.totalTrips ?? 0}')),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                  child: _StatItem(
                      label: 'Puan',
                      value: (user?.ratingAvg ?? 0).toStringAsFixed(1))),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _StatItem(
                    label: 'Uyelik', value: user == null ? '-' : 'Yeni'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (user != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildPreferenceChips(user.preferences),
            ),
        ],
      ),
    );
  }

  Widget _buildWebProfileActions(
    BuildContext context,
    WidgetRef ref,
    dynamic strings,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hizli Islemler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F3A30),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WebActionCard(
                icon: Icons.person_outline,
                title: strings.profileEdit,
                subtitle: 'Kisisel bilgilerini duzenle',
                onTap: () => context.push('/profile-details'),
              ),
              _WebActionCard(
                icon: Icons.directions_car_outlined,
                title: strings.myVehicles,
                subtitle: 'Arac listesi ve belgeler',
                onTap: () => context.push('/my-vehicles'),
              ),
              _WebActionCard(
                icon: Icons.history,
                title: strings.tripHistory,
                subtitle: 'Gecmis yolculuklarini gor',
                onTap: () => context.push('/trip-history'),
              ),
              _WebActionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: strings.wallet,
                subtitle: 'Bakiye ve odeme kayitlari',
                onTap: () => context.push('/wallet'),
              ),
              _WebActionCard(
                icon: Icons.credit_card_outlined,
                title: strings.paymentMethods,
                subtitle: 'Kart ve odeme yontemleri',
                onTap: () => context.push('/payment-methods'),
              ),
              _WebActionCard(
                icon: Icons.security_outlined,
                title: strings.security,
                subtitle: 'Guvenlik ayarlari',
                onTap: () => context.push('/security'),
              ),
              _WebActionCard(
                icon: Icons.help_outline,
                title: strings.helpSupport,
                subtitle: 'Destek ve yardim merkezi',
                onTap: () => context.push('/help'),
              ),
              _WebActionCard(
                icon: Icons.info_outline,
                title: strings.about,
                subtitle: 'Uygulama hakkinda',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              label: Text(strings.logout),
            ),
          ),
        ],
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(strings.cancel)),
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

  List<Widget> _buildPreferenceChips(DriverPreferences preferences) {
    final chips = <Widget>[];
    chips.add(_PreferenceChip(
      icon: Icons.volume_up_outlined,
      label: preferences.music?.trim().isNotEmpty == true
          ? 'Müzik: ${preferences.music}'
          : 'Müzik: Farketmez',
    ));
    chips.add(_PreferenceChip(
      icon: Icons.smoke_free_outlined,
      label: preferences.smoking == true ? 'Sigara molası var' : 'Sigara yok',
    ));
    chips.add(_PreferenceChip(
      icon: Icons.pets_outlined,
      label:
          preferences.pets == true ? 'Evcil hayvan kabul' : 'Evcil hayvan yok',
    ));
    chips.add(_PreferenceChip(
      icon: Icons.ac_unit_outlined,
      label: preferences.ac == true ? 'Klima açık' : 'Klima kapalı',
    ));

    final chatLabel = switch (preferences.chattiness) {
      'quiet' => 'Sohbet: Sessiz',
      'chatty' => 'Sohbet: Sever',
      _ => 'Sohbet: Normal',
    };
    chips.add(
        _PreferenceChip(icon: Icons.chat_bubble_outline, label: chatLabel));
    return chips;
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
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  const _MenuItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.color,
      required this.onTap});

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

class _PreferenceChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreferenceChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WebActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9E4DE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2F6B57), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F3A30),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A7066),
                    ),
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
