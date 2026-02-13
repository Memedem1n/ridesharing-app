import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart' as trip_provider;
import '../../../core/theme/app_theme.dart';
import '../../../features/bookings/domain/booking_models.dart';

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  ConsumerState<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyonlarim'),
        backgroundColor: isWeb ? Colors.white : null,
        foregroundColor: isWeb ? const Color(0xFF1F3A30) : null,
        leading: isWeb
            ? IconButton(
                tooltip: 'Geri',
                icon: const Icon(Icons.arrow_back_outlined),
                onPressed: _goBack,
              )
            : null,
        actions: isWeb
            ? [
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Ana Sayfa'),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/messages'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mesajlar'),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profil'),
                ),
                const SizedBox(width: 8),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isWeb,
          labelColor: isWeb ? const Color(0xFF1F3A30) : null,
          unselectedLabelColor: isWeb ? const Color(0xFF5A7066) : null,
          indicatorColor: isWeb ? const Color(0xFF2F6B57) : null,
          tabs: const [
            Tab(text: 'Yaklasan'),
            Tab(text: 'Gecmis'),
            Tab(text: 'Benim Yolculuklarim'),
          ],
        ),
      ),
      body: Container(
        decoration: isWeb
            ? const BoxDecoration(color: Color(0xFFF3F6F4))
            : const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isWeb ? 1080 : double.infinity),
            child: TabBarView(
              controller: _tabController,
              children: [
                _UpcomingBookings(forWeb: isWeb),
                _PastBookings(forWeb: isWeb),
                _MyTripsTab(forWeb: isWeb),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/');
  }
}

class _UpcomingBookings extends ConsumerWidget {
  final bool forWeb;

  const _UpcomingBookings({required this.forWeb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(upcomingBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return _EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'Yaklasan rezervasyon yok',
            subtitle: 'Bir yolculuk arayarak baslayin',
            forWeb: forWeb,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(upcomingBookingsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _BookingCard(
              booking: bookings[index],
              forWeb: forWeb,
            ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
          ),
        );
      },
    );
  }
}

class _PastBookings extends ConsumerWidget {
  final bool forWeb;

  const _PastBookings({required this.forWeb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pastBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return _EmptyState(
            icon: Icons.history,
            title: 'Gecmis rezervasyon yok',
            subtitle: 'Tamamlanan yolculuklariniz burada gorunecek',
            forWeb: forWeb,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(pastBookingsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => _BookingCard(
              booking: bookings[index],
              isPast: true,
              forWeb: forWeb,
            ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1),
          ),
        );
      },
    );
  }
}

class _MyTripsTab extends ConsumerWidget {
  final bool forWeb;

  const _MyTripsTab({required this.forWeb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(trip_provider.myTripsProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final titleColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textSecondary;

    return tripsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (trips) {
        if (trips.isEmpty) {
          return _EmptyState(
            icon: Icons.route,
            title: 'Henuz yolculuk yok',
            subtitle: 'Surucu olarak actiginiz ilanlar burada gorunecek.',
            forWeb: forWeb,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(trip_provider.myTripsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${trip.departureCity} -> ${trip.arrivalCity}',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(trip.departureTime),
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TripMetaPill(
                        icon: Icons.event_seat,
                        text: '${trip.availableSeats} koltuk',
                        forWeb: forWeb,
                      ),
                      _TripMetaPill(
                        icon: Icons.sell_outlined,
                        text: 'TL ${trip.pricePerSeat.toStringAsFixed(0)}',
                        forWeb: forWeb,
                      ),
                      _TripMetaPill(
                        icon: trip.bookingType == 'approval_required'
                            ? Icons.approval_outlined
                            : Icons.flash_on,
                        text: trip.bookingType == 'approval_required'
                            ? 'Onayli'
                            : 'Aninda',
                        forWeb: forWeb,
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
                          onPressed: () => context
                              .push('/driver-reservations?tripId=${trip.id}'),
                          icon: const Icon(Icons.inbox_outlined),
                          label: const Text('Talepler'),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final card = forWeb
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE6E1)),
                      ),
                      child: content,
                    )
                  : GlassContainer(
                      padding: const EdgeInsets.all(16), child: content);

              return card
                  .animate()
                  .fadeIn(delay: (index * 80).ms)
                  .slideY(begin: 0.08);
            },
          ),
        );
      },
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Booking booking;
  final bool isPast;
  final bool forWeb;

  const _BookingCard({
    required this.booking,
    this.isPast = false,
    this.forWeb = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr');
    final actionsState = ref.watch(bookingActionsProvider);
    final canCancel = booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.awaitingPayment ||
        booking.status == BookingStatus.confirmed;

    final titleColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textSecondary;
    final helperBg = forWeb ? const Color(0xFFF5F8F7) : AppColors.glassBgDark;
    final helperBorder =
        forWeb ? const Color(0xFFD5E0DB) : AppColors.glassStroke;
    final card = forWeb
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6E1)),
            ),
            child: _buildCardContent(
              context,
              ref,
              dateFormat,
              actionsState,
              canCancel,
              titleColor,
              subtitleColor,
              helperBg,
              helperBorder,
            ),
          )
        : GlassContainer(
            padding: const EdgeInsets.all(16),
            child: _buildCardContent(
              context,
              ref,
              dateFormat,
              actionsState,
              canCancel,
              titleColor,
              subtitleColor,
              helperBg,
              helperBorder,
            ),
          );

    return card;
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref,
    DateFormat dateFormat,
    dynamic actionsState,
    bool canCancel,
    Color titleColor,
    Color subtitleColor,
    Color helperBg,
    Color helperBorder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatusBadge(status: booking.status, forWeb: forWeb),
            Text(
              booking.trip != null
                  ? dateFormat.format(booking.trip!.departureTime)
                  : dateFormat.format(booking.createdAt),
              style: TextStyle(color: subtitleColor, fontSize: 12),
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
                    decoration: const BoxDecoration(
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
                    Text(
                      booking.trip!.origin,
                      style: TextStyle(
                          color: titleColor, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      booking.trip!.destination,
                      style: TextStyle(
                          color: titleColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                'TL ${booking.totalPrice.toStringAsFixed(0)}',
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
              color: helperBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: helperBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.person, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.trip!.driverName,
                        style: TextStyle(
                            color: titleColor, fontWeight: FontWeight.w600),
                      ),
                      if (booking.trip!.vehicleName != null)
                        Text(
                          '${booking.trip!.vehicleName} - ${booking.trip!.vehiclePlate}',
                          style: TextStyle(color: subtitleColor, fontSize: 12),
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
                        ? '${booking.trip!.origin} -> ${booking.trip!.destination}'
                        : 'Yolculuk';
                    final driverName = booking.trip?.driverName ?? 'Surucu';
                    context.push(
                      '/chat/${booking.id}?name=${Uri.encodeComponent(driverName)}&trip=${Uri.encodeComponent(tripInfo)}',
                    );
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
            onPressed: actionsState.isLoading
                ? null
                : () => _cancelBooking(ref, context),
            icon: const Icon(Icons.cancel),
            label: const Text('Rezervasyonu Iptal Et'),
          ),
        ],
        if (!isPast && booking.status == BookingStatus.awaitingPayment) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: actionsState.isLoading
                ? null
                : () => _processPayment(ref, context),
            icon: const Icon(Icons.payment),
            label: const Text('Odemeyi Tamamla (Mock)'),
          ),
        ],
        if (!isPast && booking.status == BookingStatus.checkedIn) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: actionsState.isLoading
                      ? null
                      : () => _completeBooking(ref, context),
                  icon: const Icon(Icons.flag),
                  label: const Text('Yolculugu Tamamla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: actionsState.isLoading
                      ? null
                      : () => _raiseDispute(ref, context),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Sorun Bildir'),
                ),
              ),
            ],
          ),
        ],
        if (isPast && booking.status == BookingStatus.completed) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              final tripInfo = booking.trip != null
                  ? '${booking.trip!.origin} -> ${booking.trip!.destination}'
                  : 'Yolculuk';
              final driverName = booking.trip?.driverName ?? 'Surucu';
              context.push(
                '/rate-driver?bookingId=${booking.id}&driver=${Uri.encodeComponent(driverName)}&trip=${Uri.encodeComponent(tripInfo)}',
              );
            },
            icon: const Icon(Icons.star_outline),
            label: const Text('Degerlendir'),
          ),
        ],
      ],
    );
  }

  void _showQrCode(BuildContext context, Booking booking) {
    final tripInfo = booking.trip != null
        ? '${booking.trip!.origin} -> ${booking.trip!.destination}'
        : 'Yolculuk';
    const name = 'Yolcu';
    final qr = Uri.encodeComponent(booking.qrCode ?? '');
    final pnr = Uri.encodeComponent(booking.pnrCode ?? '');

    context.push(
      '/boarding-qr?bookingId=${booking.id}&trip=${Uri.encodeComponent(tripInfo)}&name=${Uri.encodeComponent(name)}&seats=${booking.seatCount}&qr=$qr&pnr=$pnr',
    );
  }

  Future<void> _cancelBooking(WidgetRef ref, BuildContext context) async {
    final dialogBg = kIsWeb ? Colors.white : AppColors.surface;
    final titleColor = kIsWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final bodyColor =
        kIsWeb ? const Color(0xFF4E665C) : AppColors.textSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          'Rezervasyonu Iptal Et',
          style: TextStyle(color: titleColor),
        ),
        content: Text(
          'Rezervasyonu iptal etmek istediginize emin misiniz?',
          style: TextStyle(color: bodyColor),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Iptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(bookingActionsProvider.notifier)
          .cancelBooking(booking.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervasyon iptal edildi')),
        );
      }
    }
  }

  Future<void> _processPayment(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .processPayment(booking.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Odeme tamamlandi' : 'Odeme basarisiz'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        ref.invalidate(myBookingsProvider);
      }
    }
  }

  Future<void> _completeBooking(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .completeBooking(booking.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Yolculuk tamamlandi' : 'Tamamlama basarisiz'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        ref.invalidate(myBookingsProvider);
      }
    }
  }

  Future<void> _raiseDispute(WidgetRef ref, BuildContext context) async {
    final reasonController = TextEditingController();
    final dialogBg = kIsWeb ? Colors.white : AppColors.surface;
    final titleColor = kIsWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text('Sorun Bildir', style: TextStyle(color: titleColor)),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Sorunu kisaca yazin'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gonder')),
        ],
      ),
    );

    if (submitted != true) {
      return;
    }

    final reason = reasonController.text.trim();
    if (reason.length < 5) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En az 5 karakter aciklama gerekli')),
        );
      }
      return;
    }

    final success = await ref
        .read(bookingActionsProvider.notifier)
        .raiseDispute(booking.id, reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Sorun kaydi olusturuldu'
              : 'Sorun kaydi olusturulamadi'),
          backgroundColor: success ? AppColors.warning : AppColors.error,
        ),
      );
      if (success) {
        ref.invalidate(myBookingsProvider);
      }
    }
  }
}

class _TripMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool forWeb;

  const _TripMetaPill({
    required this.icon,
    required this.text,
    this.forWeb = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = forWeb ? const Color(0xFFF3F7F4) : AppColors.glassBg;
    final border = forWeb ? const Color(0xFFD7E3DD) : AppColors.glassStroke;
    final textColor =
        forWeb ? const Color(0xFF4E665C) : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  final bool forWeb;

  const _StatusBadge({required this.status, this.forWeb = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      BookingStatus.pending => (
          'Onay Bekliyor',
          AppColors.warning,
          AppColors.warningBg
        ),
      BookingStatus.awaitingPayment => (
          'Odeme Bekliyor',
          AppColors.warning,
          AppColors.warningBg
        ),
      BookingStatus.confirmed => (
          'Onaylandi',
          AppColors.success,
          AppColors.successBg
        ),
      BookingStatus.checkedIn => ('Check-in', AppColors.info, AppColors.infoBg),
      BookingStatus.completed => (
          'Tamamlandi',
          AppColors.secondary,
          AppColors.glassBg
        ),
      BookingStatus.disputed => (
          'Incelemede',
          AppColors.warning,
          AppColors.warningBg
        ),
      BookingStatus.cancelled => ('Iptal', AppColors.error, AppColors.errorBg),
      BookingStatus.rejected => (
          'Reddedildi',
          AppColors.error,
          AppColors.errorBg
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: forWeb ? color.withValues(alpha: 0.13) : bg,
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
  final bool forWeb;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.forWeb = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final subtitleColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: subtitleColor)),
        ],
      ),
    );
  }
}
