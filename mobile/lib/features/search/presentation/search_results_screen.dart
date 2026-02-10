import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/map_view.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? from;
  final String? to;
  final String? date;

  const SearchResultsScreen({super.key, this.from, this.to, this.date});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  @override
  void initState() {
    super.initState();
    final hasParams =
        widget.from != null || widget.to != null || widget.date != null;
    if (!hasParams) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(tripSearchParamsProvider);
      final parsedDate =
          widget.date != null ? DateTime.tryParse(widget.date!) : null;
      ref.read(tripSearchParamsProvider.notifier).state = current.copyWith(
        from: widget.from ?? current.from,
        to: widget.to ?? current.to,
        date: parsedDate ?? current.date,
      );
    });
  }

  List<Marker> _buildTripMarkers(List<Trip> trips) {
    final markers = <Marker>[];
    for (final trip in trips) {
      if (trip.departureLat != null && trip.departureLng != null) {
        markers.add(
          Marker(
            width: 32,
            height: 32,
            point: LatLng(trip.departureLat!, trip.departureLng!),
            child: const Icon(
              Icons.trip_origin,
              size: 22,
              color: Color(0xFF2F6B57),
            ),
          ),
        );
      }
      if (trip.arrivalLat != null && trip.arrivalLng != null) {
        markers.add(
          Marker(
            width: 32,
            height: 32,
            point: LatLng(trip.arrivalLat!, trip.arrivalLng!),
            child: const Icon(
              Icons.location_on,
              size: 22,
              color: Color(0xFF1F4B3D),
            ),
          ),
        );
      }
    }
    return markers;
  }

  LatLng _resolveMapCenter(List<Marker> markers) {
    if (markers.isNotEmpty) {
      return markers.first.point;
    }
    return const LatLng(39.0, 35.0);
  }

  Widget _buildWebMapPanel(List<Trip> trips) {
    final markers = _buildTripMarkers(trips);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4DED8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Harita',
              style: TextStyle(
                color: Color(0xFF1F3A30),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: markers.isEmpty
                    ? Container(
                        color: const Color(0xFFF1F6F3),
                        alignment: Alignment.center,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Bu aramada konum bilgisi olan rota bulunamadı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF4E665C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : MapView(
                        initialPosition: _resolveMapCenter(markers),
                        markers: markers,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(searchResultsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isWideWeb = kIsWeb;

    if (isWideWeb) {
      return _buildWebResults(context, tripsAsync, isAuthenticated);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${widget.from ?? "Tüm şehirler"} -> ${widget.to ?? "Tüm şehirler"}',
                style: const TextStyle(fontSize: 16)),
            if (widget.date != null)
              Text(widget.date!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: tripsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sonuçlar şu an yüklenemiyor.',
                    style: TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(searchResultsProvider),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
            data: (trips) {
              if (trips.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      const Text('Yolculuk bulunamadı',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Farklı tarih veya güzergah deneyin',
                          style: TextStyle(color: AppColors.textTertiary)),
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

  Widget _buildWebResults(
    BuildContext context,
    AsyncValue<List<Trip>> tripsAsync,
    bool isAuthenticated,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebTopBar(context, isAuthenticated),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4DED8)),
                    ),
                    child: Text(
                      '${widget.from ?? "Tüm şehirler"} -> ${widget.to ?? "Tüm şehirler"}'
                      '${widget.date != null ? " • ${widget.date}" : ""}',
                      style: const TextStyle(
                        color: Color(0xFF1F3A30),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: tripsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2F6B57),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sonuçlar şu an yüklenemiyor.',
                              style: TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(searchResultsProvider),
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                      data: (trips) {
                        if (trips.isEmpty) {
                          return const Center(
                            child: Text(
                              'Uygun yolculuk bulunamadı. Farklı tarih veya güzergah deneyin.',
                              style: TextStyle(color: Color(0xFF4E665C)),
                            ),
                          );
                        }
                        final listView = ListView.separated(
                          itemCount: trips.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            final isFull = trip.availableSeats <= 0 ||
                                trip.status.toLowerCase() == 'full';
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFD4DED8)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          context.push('/trip/${trip.id}'),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${trip.departureCity} -> ${trip.arrivalCity}',
                                            style: const TextStyle(
                                              color: Color(0xFF1F3A30),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${DateFormat('dd MMM yyyy HH:mm', 'tr').format(trip.departureTime)} • ${trip.driverName}',
                                            style: const TextStyle(
                                                color: Color(0xFF4E665C)),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: isFull
                                                      ? AppColors.neutralBorder
                                                      : AppColors
                                                          .secondaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  isFull
                                                      ? 'Dolu'
                                                      : '${trip.availableSeats} koltuk',
                                                  style: TextStyle(
                                                    color: isFull
                                                        ? const Color(
                                                            0xFF374151)
                                                        : const Color(
                                                            0xFF166534),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (trip.allowsPets)
                                                const _WebTag(label: 'Evcil'),
                                              if (trip.allowsCargo)
                                                const _WebTag(label: 'Kargo'),
                                              if (trip.womenOnly)
                                                const _WebTag(label: 'Kadın'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 190,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'TL ${trip.pricePerSeat.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF2F6B57),
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const Text(
                                          'kişi başı',
                                          style: TextStyle(
                                              color: Color(0xFF6A7F74),
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: isFull
                                              ? null
                                              : () {
                                                  if (!isAuthenticated) {
                                                    final next =
                                                        Uri.encodeComponent(
                                                            '/booking/${trip.id}');
                                                    context.push(
                                                        '/login?next=$next');
                                                    return;
                                                  }
                                                  context.push(
                                                      '/booking/${trip.id}');
                                                },
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2F6B57),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 44),
                                          ),
                                          child: Text(
                                            isFull
                                                ? 'Dolu'
                                                : (!isAuthenticated
                                                    ? 'Giriş yap ve rezerve et'
                                                    : 'Rezerve Et'),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 1060;
                            final mapPanel = _buildWebMapPanel(trips);
                            if (compact) {
                              return Column(
                                children: [
                                  SizedBox(height: 280, child: mapPanel),
                                  const SizedBox(height: 12),
                                  Expanded(child: listView),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: listView),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 360,
                                  child: mapPanel,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebTopBar(BuildContext context, bool isAuthenticated) {
    final createTripNext = Uri.encodeComponent('/create-trip');
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: const BrandLockup(
            iconSize: 28,
            textSize: 23,
            gap: 8,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Aramayı düzenle'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            if (isAuthenticated) {
              context.push('/create-trip');
            } else {
              context.push('/login?next=$createTripNext');
            }
          },
          child: const Text('Yolculuk Oluştur'),
        ),
        const SizedBox(width: 8),
        if (isAuthenticated)
          FilledButton(
            onPressed: () => context.go('/reservations'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B57),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Rezervasyonlarım'),
          )
        else
          OutlinedButton(
            onPressed: () => context.push('/login'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: const BorderSide(color: Color(0xFF2F6B57)),
            ),
            child: const Text('Giriş Yap'),
          ),
      ],
    );
  }
}

class _WebTag extends StatelessWidget {
  final String label;

  const _WebTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2D5D4D),
          fontWeight: FontWeight.w700,
          fontSize: 12,
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
    final isFull =
        trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  backgroundImage: trip.driverPhoto != null
                      ? NetworkImage(trip.driverPhoto!)
                      : null,
                  child: trip.driverPhoto == null
                      ? Text(trip.driverName[0],
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.driverName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.warning, size: 14),
                          const SizedBox(width: 4),
                          Text(trip.driverRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          if (trip.vehicleBrand != null) ...[
                            const SizedBox(width: 8),
                            Text(
                                '${trip.vehicleBrand} ${trip.vehicleModel ?? ""}',
                                style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TL ${trip.pricePerSeat.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const Text('kisi basi',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 10)),
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
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                    Container(
                        width: 2, height: 30, color: AppColors.glassStroke),
                    Icon(Icons.location_on, color: AppColors.accent, size: 16),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.departureCity,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                      Text(trip.arrivalCity,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeFormat.format(trip.departureTime),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dateFormat.format(trip.departureTime),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFull
                            ? Colors.grey.withValues(alpha: 0.25)
                            : AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isFull ? 'Dolu' : '${trip.availableSeats} koltuk',
                        style: TextStyle(
                          color:
                              isFull ? Colors.grey.shade200 : AppColors.success,
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
                if (trip.instantBooking)
                  _FeatureChip(icon: Icons.flash_on, label: 'Aninda'),
                if (trip.allowsPets)
                  _FeatureChip(icon: Icons.pets, label: 'Evcil'),
                if (trip.allowsCargo)
                  _FeatureChip(icon: Icons.inventory_2, label: 'Kargo'),
                if (trip.womenOnly)
                  _FeatureChip(icon: Icons.female, label: 'Kadin'),
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
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
