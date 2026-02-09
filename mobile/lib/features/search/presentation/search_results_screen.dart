import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/trip_provider.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? from;
  final String? to;
  final String? date;

  const SearchResultsScreen({super.key, this.from, this.to, this.date});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  @override
  void initState() {
    super.initState();
    final hasParams = widget.from != null || widget.to != null || widget.date != null;
    if (!hasParams) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(tripSearchParamsProvider);
      final parsedDate = widget.date != null ? DateTime.tryParse(widget.date!) : null;
      ref.read(tripSearchParamsProvider.notifier).state = current.copyWith(
        from: widget.from ?? current.from,
        to: widget.to ?? current.to,
        date: parsedDate ?? current.date,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.from ?? "Tüm Şehirler"} → ${widget.to ?? "Tüm Şehirler"}', style: const TextStyle(fontSize: 16)),
            if (widget.date != null) Text(widget.date!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: tripsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            data: (trips) {
              if (trips.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      const Text('Yolculuk bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Farklı tarih veya güzergah deneyin', style: TextStyle(color: AppColors.textTertiary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _TripCard(trip: trip, index: index);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int index;

  const _TripCard({required this.trip, required this.index});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd MMM', 'tr');
    final isFull = trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';

    return GestureDetector(
      onTap: () => context.push('/trip/${trip.id}'),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFull)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Dolu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (isFull) const SizedBox(height: 10),
            // Driver Info Row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundImage: trip.driverPhoto != null ? NetworkImage(trip.driverPhoto!) : null,
                  child: trip.driverPhoto == null
                    ? Text(trip.driverName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.driverName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.warning, size: 14),
                          const SizedBox(width: 4),
                          Text(trip.driverRating.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (trip.vehicleBrand != null) ...[
                            const SizedBox(width: 8),
                            Text('${trip.vehicleBrand} ${trip.vehicleModel ?? ""}',
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₺${trip.pricePerSeat.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('kişi başı', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.glassStroke, height: 1),
            const SizedBox(height: 16),

            // Route Row
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                    Container(width: 2, height: 30, color: AppColors.glassStroke),
                    Icon(Icons.location_on, color: AppColors.accent, size: 16),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.departureCity, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                      Text(trip.arrivalCity, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeFormat.format(trip.departureTime),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dateFormat.format(trip.departureTime),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFull
                            ? Colors.grey.withValues(alpha: 0.25)
                            : AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isFull ? 'Dolu' : '${trip.availableSeats} koltuk',
                        style: TextStyle(
                          color: isFull ? Colors.grey.shade200 : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Features Row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (trip.instantBooking) _FeatureChip(icon: Icons.flash_on, label: 'Anında'),
                if (trip.allowsPets) _FeatureChip(icon: Icons.pets, label: 'Evcil'),
                if (trip.allowsCargo) _FeatureChip(icon: Icons.inventory_2, label: 'Kargo'),
                if (trip.womenOnly) _FeatureChip(icon: Icons.female, label: 'Kadın'),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn().slideY(begin: 0.1);
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
