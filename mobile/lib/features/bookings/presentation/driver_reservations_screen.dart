import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart' as trip_provider;
import '../../../core/theme/app_theme.dart';

import '../../../features/bookings/domain/booking_models.dart';
import 'package:intl/intl.dart';

class DriverReservationsScreen extends ConsumerStatefulWidget {
  const DriverReservationsScreen({super.key});

  @override
  ConsumerState<DriverReservationsScreen> createState() => _DriverReservationsScreenState();
}

class _DriverReservationsScreenState extends ConsumerState<DriverReservationsScreen> {
  String? _selectedTripId;

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(trip_provider.myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelen Talepler'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                    ).animate().scale(),
                    const SizedBox(height: 24),
                    Text('Henüz ilan yok', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'İlan oluşturduğunuzda talepler burada görünecek',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
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

            final selectedId = _selectedTripId ?? trips.first.id;
            final bookingsAsync = ref.watch(driverBookingsProvider(selectedId));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _TripSelector(
                    trips: trips,
                    selectedTripId: selectedId,
                    onChanged: (value) => setState(() => _selectedTripId = value),
                  ),
                ),
                Expanded(
                  child: bookingsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
                    data: (bookings) {
                      if (bookings.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textTertiary),
                              const SizedBox(height: 16),
                              const Text('Talep yok', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(driverBookingsProvider(selectedId).future),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) => _RequestCard(
                            booking: bookings[index],
                            tripId: selectedId,
                            onRefresh: () => ref.invalidate(driverBookingsProvider(selectedId)),
                          ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripSelector extends StatelessWidget {
  final List<trip_provider.Trip> trips;
  final String selectedTripId;
  final ValueChanged<String?> onChanged;

  const _TripSelector({
    required this.trips,
    required this.selectedTripId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selectedTripId),
        initialValue: selectedTripId,
        decoration: const InputDecoration(
          labelText: 'İlan Seç',
          border: OutlineInputBorder(borderSide: BorderSide.none),
          filled: true,
          fillColor: AppColors.glassBgDark,
        ),
        items: trips.map((trip) {
          return DropdownMenuItem<String>(
            value: trip.id,
            child: Text('${trip.departureCity} → ${trip.arrivalCity}'),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final Booking booking;
  final String tripId;
  final VoidCallback onRefresh;

  const _RequestCard({
    required this.booking,
    required this.tripId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM HH:mm', 'tr');
    final actionsState = ref.watch(bookingActionsProvider);
    final canCancel = booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed;

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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

          const SizedBox(height: 16),
          if (booking.status == BookingStatus.pending) ...[
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Ödeme bekleniyor', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (booking.status == BookingStatus.confirmed) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/qr-scanner/$tripId'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('QR Tara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionsState.isLoading ? null : () => _cancelBooking(ref, context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('İptal'),
                  ),
                ),
              ],
            ),
          ],
          if (booking.status != BookingStatus.confirmed && canCancel) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: actionsState.isLoading ? null : () => _cancelBooking(ref, context),
              icon: const Icon(Icons.cancel),
              label: const Text('İptal'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancelBooking(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rezervasyonu İptal Et', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu rezervasyonu iptal etmek istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(bookingActionsProvider.notifier).cancelBooking(booking.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervasyon iptal edildi')),
        );
        onRefresh();
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
      BookingStatus.checkedIn => ('Check-in', AppColors.info),
      BookingStatus.completed => ('Tamamlandı', AppColors.secondary),
      BookingStatus.cancelled => ('İptal', AppColors.error),
      _ => ('', AppColors.textTertiary),
    };

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
