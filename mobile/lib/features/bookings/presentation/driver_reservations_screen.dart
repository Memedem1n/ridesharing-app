import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/theme/app_theme.dart';

import '../../../features/bookings/domain/booking_models.dart';
import 'package:intl/intl.dart';

class DriverReservationsScreen extends ConsumerWidget {
  const DriverReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelen Talepler'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          data: (bookings) {
            if (bookings.isEmpty) {
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
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                    ).animate().scale(),
                    const SizedBox(height: 24),
                    Text('Bekleyen talep yok', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'Yeni rezervasyon talepleri burada görünecek',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(pendingRequestsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) => _RequestCard(booking: bookings[index])
                    .animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final Booking booking;

  const _RequestCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM HH:mm', 'tr');
    final actionsState = ref.watch(bookingActionsProvider);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  image: booking.passengerAvatar != null 
                    ? DecorationImage(image: NetworkImage(booking.passengerAvatar!))
                    : null,
                ),
                child: booking.passengerAvatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.passengerName ?? 'Yolcu',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '4.9 • 12 yolculuk',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 16),

          // Trip info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassBgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassStroke),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking.trip != null) ...[
                        Text(
                          '${booking.trip!.origin} → ${booking.trip!.destination}',
                          style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(booking.trip!.departureTime),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${booking.seatCount} koltuk',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (booking.status == BookingStatus.pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionsState.isLoading
                      ? null
                      : () => _confirmBooking(ref, context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Onayla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionsState.isLoading
                      ? null
                      : () => _rejectBooking(ref, context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  booking.status == BookingStatus.confirmed ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: booking.status == BookingStatus.confirmed ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  booking.status == BookingStatus.confirmed ? 'Onaylandı' : 'Reddedildi',
                  style: TextStyle(
                    color: booking.status == BookingStatus.confirmed ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmBooking(WidgetRef ref, BuildContext context) async {
    final success = await ref.read(bookingActionsProvider.notifier).confirmBooking(booking.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon onaylandı'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _rejectBooking(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rezervasyonu Reddet', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu rezervasyon talebini reddetmek istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(bookingActionsProvider.notifier).rejectBooking(booking.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervasyon reddedildi')),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.pending => ('Bekliyor', AppColors.warning),
      BookingStatus.confirmed => ('Onaylandı', AppColors.success),
      BookingStatus.rejected => ('Reddedildi', AppColors.error),
      _ => ('', AppColors.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
