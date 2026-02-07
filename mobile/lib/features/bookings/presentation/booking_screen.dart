import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String tripId;

  const BookingScreen({super.key, required this.tripId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _seats = 1;

  Future<void> _confirmBooking(Trip trip) async {
    final booking = await ref.read(bookingActionsProvider.notifier).createBooking(trip.id, _seats);
    if (booking == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervasyon başarısız'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.check_circle, color: AppColors.success, size: 64),
          title: const Text('Rezervasyon Oluşturuldu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rezervasyonunuz oluşturuldu. Ödeme tamamlandığında onaylanacak.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 120, color: AppColors.textPrimary),
                    const SizedBox(height: 8),
                    Text(booking.qrCode ?? 'BK-XXXX', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/reservations');
              },
              child: const Text('Rezervasyonlara Git'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final actionsState = ref.watch(bookingActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon')),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Yolculuk bulunamadı', style: TextStyle(color: AppColors.textSecondary)));
          }

          final price = trip.pricePerSeat * _seats;
          final commission = (price * 0.1).round();
          final total = price;
          final dateFormat = DateFormat('dd MMM yyyy', 'tr');
          final timeFormat = DateFormat('HH:mm');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yolculuk Özeti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          children: [
                            Icon(Icons.trip_origin, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(trip.departureCity),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: Container(width: 2, height: 20, color: AppColors.border),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(trip.arrivalCity),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary), const SizedBox(width: 4), Text(dateFormat.format(trip.departureTime))]),
                            Row(children: [Icon(Icons.access_time, size: 16, color: AppColors.textSecondary), const SizedBox(width: 4), Text(timeFormat.format(trip.departureTime))]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Koltuk Sayısı', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text('$_seats', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ),
                            IconButton.filled(
                              onPressed: _seats < trip.availableSeats ? () => setState(() => _seats++) : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(child: Text('Maksimum ${trip.availableSeats} koltuk', style: TextStyle(color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fiyat Detayı', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(),
                        _PriceRow(label: 'Koltuk başı', value: '${trip.pricePerSeat.toStringAsFixed(0)} ₺'),
                        _PriceRow(label: 'Koltuk sayısı', value: 'x $_seats'),
                        const Divider(),
                        _PriceRow(label: 'Ara toplam', value: '${price.toStringAsFixed(0)} ₺'),
                        _PriceRow(label: 'Platform komisyonu', value: '${commission.toStringAsFixed(0)} ₺', subtitle: '%10'),
                        const Divider(),
                        _PriceRow(label: 'Toplam', value: '${total.toStringAsFixed(0)} ₺', isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  color: AppColors.info.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Ödeme şu an devre dışı. Rezervasyon “beklemede” olarak oluşturulur.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: tripAsync.when(
          data: (trip) => ElevatedButton(
            onPressed: trip == null || actionsState.isLoading ? null : () => _confirmBooking(trip),
            child: actionsState.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Rezervasyon Yap'),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final bool isBold;

  const _PriceRow({required this.label, required this.value, this.subtitle, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null)),
              if (subtitle != null) Text(' ($subtitle)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null, color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}
