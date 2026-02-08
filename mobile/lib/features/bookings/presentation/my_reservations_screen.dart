import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/bookings/domain/booking_models.dart';
import 'package:intl/intl.dart';

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  ConsumerState<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyonlarım'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Yaklaşan'),
            Tab(text: 'Geçmiş'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _UpcomingBookings(),
            _PastBookings(),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBookings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(upcomingBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'Yaklaşan rezervasyon yok',
            subtitle: 'Bir yolculuk arayarak başlayın',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(upcomingBookingsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _BookingCard(booking: bookings[index])
                .animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
          ),
        );
      },
    );
  }
}

class _PastBookings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pastBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: 'Geçmiş rezervasyon yok',
            subtitle: 'Tamamlanan yolculuklarınız burada görünecek',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(pastBookingsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _BookingCard(booking: bookings[index], isPast: true)
                .animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
          ),
        );
      },
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Booking booking;
  final bool isPast;

  const _BookingCard({required this.booking, this.isPast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final actionsState = ref.watch(bookingActionsProvider);
    final canCancel = booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadge(status: booking.status),
              Text(
                booking.trip != null
                  ? dateFormat.format(booking.trip!.departureTime)
                  : dateFormat.format(booking.createdAt),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (booking.trip != null) ...[
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
                      Text(booking.trip!.origin, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(booking.trip!.destination, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(
                  '${booking.totalPrice.toStringAsFixed(0)} ₺',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glassBgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassStroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.trip!.driverName,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        if (booking.trip!.vehicleName != null)
                          Text(
                            '${booking.trip!.vehicleName} • ${booking.trip!.vehiclePlate}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!isPast && booking.status == BookingStatus.confirmed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQrCode(context, booking),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('QR Kod'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final tripInfo = booking.trip != null
                        ? '${booking.trip!.origin} → ${booking.trip!.destination}'
                        : 'Yolculuk';
                      final driverName = booking.trip?.driverName ?? 'Sürücü';
                      context.push('/chat/${booking.id}?name=${Uri.encodeComponent(driverName)}&trip=${Uri.encodeComponent(tripInfo)}');
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Mesaj'),
                  ),
                ),
              ],
            ),
          ],

          if (!isPast && canCancel) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: actionsState.isLoading ? null : () => _cancelBooking(ref, context),
              icon: const Icon(Icons.cancel),
              label: const Text('Rezervasyonu İptal Et'),
            ),
          ],

          if (!isPast && booking.status == BookingStatus.pending) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: actionsState.isLoading ? null : () => _processPayment(ref, context),
              icon: const Icon(Icons.payment),
              label: const Text('Ödemeyi Tamamla (Mock)'),
            ),
          ],

          if (isPast && booking.status == BookingStatus.completed) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final tripInfo = booking.trip != null
                  ? '${booking.trip!.origin} → ${booking.trip!.destination}'
                  : 'Yolculuk';
                final driverName = booking.trip?.driverName ?? 'Sürücü';
                context.push('/rate-driver?bookingId=${booking.id}&driver=${Uri.encodeComponent(driverName)}&trip=${Uri.encodeComponent(tripInfo)}');
              },
              icon: const Icon(Icons.star_outline),
              label: const Text('Değerlendir'),
            ),
          ],
        ],
      ),
    );
  }

  void _showQrCode(BuildContext context, Booking booking) {
    final tripInfo = booking.trip != null
      ? '${booking.trip!.origin} → ${booking.trip!.destination}'
      : 'Yolculuk';
    final name = 'Yolcu';
    final qr = Uri.encodeComponent(booking.qrCode ?? '');
    final pnr = Uri.encodeComponent(booking.pnrCode ?? '');

    context.push('/boarding-qr?bookingId=${booking.id}&trip=${Uri.encodeComponent(tripInfo)}&name=${Uri.encodeComponent(name)}&seats=${booking.seatCount}&qr=$qr&pnr=$pnr');
  }

  Future<void> _cancelBooking(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rezervasyonu İptal Et', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Rezervasyonu iptal etmek istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
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
      }
    }
  }

  Future<void> _processPayment(WidgetRef ref, BuildContext context) async {
    final success = await ref.read(bookingActionsProvider.notifier).processPayment(booking.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Ödeme tamamlandı' : 'Ödeme başarısız'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        ref.invalidate(myBookingsProvider);
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      BookingStatus.pending => ('Onay Bekliyor', AppColors.warning, AppColors.warningBg),
      BookingStatus.confirmed => ('Onaylandı', AppColors.success, AppColors.successBg),
      BookingStatus.checkedIn => ('Check-in', AppColors.info, AppColors.infoBg),
      BookingStatus.completed => ('Tamamlandı', AppColors.secondary, AppColors.glassBg),
      BookingStatus.cancelled => ('İptal', AppColors.error, AppColors.errorBg),
      BookingStatus.rejected => ('Reddedildi', AppColors.error, AppColors.errorBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(icon, size: 48, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
