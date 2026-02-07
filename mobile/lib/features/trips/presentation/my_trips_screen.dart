import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yolculuklarım'),
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
        label: 'İlan Ver',
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassStroke),
                      ),
                      child: Icon(Icons.route, size: 64, color: AppColors.textTertiary),
                    ).animate().scale(),
                    const SizedBox(height: 24),
                    const Text('Henüz ilan yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('İlan verdiğiniz yolculuklar burada görünür', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/create-trip'),
                      icon: const Icon(Icons.add),
                      label: const Text('İlan Oluştur'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(myTripsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                itemBuilder: (context, index) => _TripCard(trip: trips[index])
                    .animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.1),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final status = _statusLabel(trip.status);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadge(label: status.$1, color: status.$2),
              Text(dateFormat.format(trip.departureTime), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.trip_origin, size: 14, color: AppColors.primary),
                  Container(
                    width: 2,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Icon(Icons.location_on, size: 14, color: AppColors.accent),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.departureCity, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(trip.arrivalCity, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text(
                '₺${trip.pricePerSeat.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(icon: Icons.event_seat, label: '${trip.availableSeats} koltuk'),
              const SizedBox(width: 8),
              if (trip.instantBooking) _InfoChip(icon: Icons.flash_on, label: 'Anında'),
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
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/driver-reservations'),
                  icon: const Icon(Icons.inbox),
                  label: const Text('Talepler'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusLabel(String status) {
    switch (status) {
      case 'published':
        return ('Yayında', AppColors.success);
      case 'full':
        return ('Dolu', AppColors.warning);
      case 'in_progress':
        return ('Devam Ediyor', AppColors.info);
      case 'completed':
        return ('Tamamlandı', AppColors.secondary);
      case 'cancelled':
        return ('İptal', AppColors.error);
      default:
        return ('Taslak', AppColors.textTertiary);
    }
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
