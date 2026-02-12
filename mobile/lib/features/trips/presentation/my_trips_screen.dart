import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';

class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  final Set<String> _deletingIds = <String>{};

  Future<void> _deleteTrip(Trip trip) async {
    final isActive = _isActiveTrip(trip.status);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Ilani Sil',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          isActive
              ? 'Bu aktif ilani silerseniz yeni rezervasyon alinmaz. Gecmis kayitlar korunur. Devam etmek istiyor musunuz?'
              : 'Bu ilan arsivlenecek ve listelerden kaldirilacak. Devam etmek istiyor musunuz?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(trip.id));
    try {
      await ref.read(tripServiceProvider).deleteTrip(trip.id);
      if (!mounted) return;
      ref.invalidate(myTripsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ilan kaldirildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ilan silinirken hata olustu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(trip.id));
      }
    }
  }

  bool _isActiveTrip(String status) {
    switch (status) {
      case 'published':
      case 'full':
      case 'in_progress':
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    if (kIsWeb) {
      return _buildWeb(tripsAsync);
    }
    return _buildMobile(tripsAsync);
  }

  Widget _buildMobile(AsyncValue<List<Trip>> tripsAsync) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yolculuklarim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: 'Gelen Talepler',
            onPressed: () => context.push('/driver-reservations'),
          ),
        ],
      ),
      floatingActionButton: PulseFloatingButton(
        onPressed: () => context.push('/create-trip'),
        icon: Icons.add,
        label: 'Ilan Ver',
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _buildTripsBody(tripsAsync, webMode: false),
      ),
    );
  }

  Widget _buildWeb(AsyncValue<List<Trip>> tripsAsync) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        title: const Text('Yolculuklarim'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
            label: const Text('Profil'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/driver-reservations'),
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('Gelen Talepler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.push('/create-trip'),
            icon: const Icon(Icons.add),
            label: const Text('Ilan Olustur'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Ana Sayfa'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTripsBody(tripsAsync, webMode: true),
          ),
        ),
      ),
    );
  }

  Widget _buildTripsBody(AsyncValue<List<Trip>> tripsAsync,
      {required bool webMode}) {
    return tripsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Hata: $e',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.route,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Henuz ilan yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ilan verdiginiz yolculuklar burada gorunur',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/create-trip'),
                  icon: const Icon(Icons.add),
                  label: const Text('Ilan Olustur'),
                ),
              ],
            ),
          );
        }

        final activeTrips =
            trips.where((trip) => _isActiveTrip(trip.status)).toList();
        final archivedTrips =
            trips.where((trip) => !_isActiveTrip(trip.status)).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(myTripsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeTrips.isNotEmpty) ...[
                const _SectionHeader(
                  icon: Icons.bolt_outlined,
                  title: 'Aktif Ilanlar',
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < activeTrips.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripCard(
                      trip: activeTrips[i],
                      deleting: _deletingIds.contains(activeTrips[i].id),
                      onDelete: () => _deleteTrip(activeTrips[i]),
                      webMode: webMode,
                    ).animate().fadeIn(delay: (i * 70).ms).slideY(begin: 0.08),
                  ),
              ],
              if (archivedTrips.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeader(
                  icon: Icons.archive_outlined,
                  title: 'Eski Ilanlar',
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < archivedTrips.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripCard(
                      trip: archivedTrips[i],
                      deleting: _deletingIds.contains(archivedTrips[i].id),
                      onDelete: () => _deleteTrip(archivedTrips[i]),
                      webMode: webMode,
                    ).animate().fadeIn(delay: (i * 70).ms).slideY(begin: 0.08),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final bool deleting;
  final bool webMode;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.deleting,
    required this.onDelete,
    required this.webMode,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final status = _statusLabel(trip.status);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusBadge(label: status.$1, color: status.$2),
            const Spacer(),
            Text(
              dateFormat.format(trip.departureTime),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: deleting ? null : onDelete,
              icon: deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Ilani Sil',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${trip.departureCity} -> ${trip.arrivalCity}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
                icon: Icons.event_seat, label: '${trip.availableSeats} koltuk'),
            _InfoChip(
              icon: Icons.sell_outlined,
              label: 'TL ${trip.pricePerSeat.toStringAsFixed(0)}',
            ),
            _InfoChip(
              icon: trip.bookingType == 'approval_required'
                  ? Icons.approval_outlined
                  : Icons.flash_on,
              label:
                  trip.bookingType == 'approval_required' ? 'Onayli' : 'Aninda',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/trip/${trip.id}'),
                icon: const Icon(Icons.visibility),
                label: const Text('Detay'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/driver-reservations?tripId=${trip.id}'),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Talepler'),
              ),
            ),
          ],
        ),
      ],
    );

    if (webMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: content,
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  (String, Color) _statusLabel(String status) {
    switch (status) {
      case 'published':
        return ('Yayinda', AppColors.success);
      case 'full':
        return ('Dolu', AppColors.warning);
      case 'in_progress':
        return ('Devam Ediyor', AppColors.info);
      case 'completed':
        return ('Tamamlandi', AppColors.secondary);
      case 'cancelled':
        return ('Iptal', AppColors.error);
      default:
        return ('Taslak', AppColors.textTertiary);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
