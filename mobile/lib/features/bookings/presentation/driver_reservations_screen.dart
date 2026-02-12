import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart' as trip_provider;
import '../../../core/theme/app_theme.dart';
import '../../../features/bookings/data/booking_repository.dart';
import '../../../features/bookings/domain/booking_models.dart';

class DriverReservationsScreen extends ConsumerStatefulWidget {
  final String? initialTripId;

  const DriverReservationsScreen({
    super.key,
    this.initialTripId,
  });

  @override
  ConsumerState<DriverReservationsScreen> createState() =>
      _DriverReservationsScreenState();
}

class _DriverReservationsScreenState
    extends ConsumerState<DriverReservationsScreen> {
  String? _selectedTripId;
  bool _selectionInitialized = false;
  bool _loadingTripCounts = false;
  _RequestFilter _requestFilter = _RequestFilter.all;
  final Map<String, int> _tripRequestCounts = <String, int>{};

  Future<void> _ensureTripSelection(List<trip_provider.Trip> trips) async {
    if (trips.isEmpty) return;

    final selectedStillExists = _selectedTripId != null &&
        trips.any((trip) => trip.id == _selectedTripId);
    if (_selectionInitialized && selectedStillExists) {
      return;
    }

    await _loadTripRequestCounts(trips);
    if (!mounted) return;

    final requestedTripId = (widget.initialTripId ?? '').trim();
    final requestedExists = requestedTripId.isNotEmpty &&
        trips.any((trip) => trip.id == requestedTripId);
    final preferredTripId = _pickPreferredTripId(trips);
    setState(() {
      _selectedTripId = requestedExists
          ? requestedTripId
          : (preferredTripId ?? trips.first.id);
      _selectionInitialized = true;
    });
  }

  String? _pickPreferredTripId(List<trip_provider.Trip> trips) {
    String? bestId;
    int bestCount = -1;
    for (final trip in trips) {
      final count = _tripRequestCounts[trip.id] ?? 0;
      if (count > bestCount) {
        bestCount = count;
        bestId = trip.id;
      }
    }
    if (bestCount <= 0) return trips.first.id;
    return bestId;
  }

  Future<void> _loadTripRequestCounts(List<trip_provider.Trip> trips) async {
    if (_loadingTripCounts) return;

    setState(() => _loadingTripCounts = true);
    try {
      final repository = ref.read(bookingRepositoryProvider);
      final counts = <String, int>{};
      for (final trip in trips) {
        try {
          final bookings = await repository.getDriverBookings(trip.id);
          counts[trip.id] = bookings.length;
        } catch (_) {
          counts[trip.id] = 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _tripRequestCounts
          ..clear()
          ..addAll(counts);
      });
    } finally {
      if (mounted) {
        setState(() => _loadingTripCounts = false);
      }
    }
  }

  List<Booking> _filterBookings(List<Booking> bookings) {
    switch (_requestFilter) {
      case _RequestFilter.pending:
        return bookings
            .where((b) => b.status == BookingStatus.pending)
            .toList();
      case _RequestFilter.awaitingPayment:
        return bookings
            .where((b) => b.status == BookingStatus.awaitingPayment)
            .toList();
      case _RequestFilter.confirmed:
        return bookings
            .where((b) => b.status == BookingStatus.confirmed)
            .toList();
      case _RequestFilter.all:
        return bookings;
    }
  }

  String _emptyMessageForFilter() {
    switch (_requestFilter) {
      case _RequestFilter.pending:
        return 'Bekleyen talep yok';
      case _RequestFilter.awaitingPayment:
        return 'Odeme bekleyen talep yok';
      case _RequestFilter.confirmed:
        return 'Onayli talep yok';
      case _RequestFilter.all:
        return 'Bu ilan icin henuz talep yok';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(trip_provider.myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelen Talepler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _selectionInitialized = false;
              ref.invalidate(trip_provider.myTripsProvider);
              if (_selectedTripId != null) {
                ref.invalidate(driverBookingsProvider(_selectedTripId!));
              }
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF3F6F4),
        child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Hata: $e',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (trips) {
            if (trips.isNotEmpty && !_selectionInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _ensureTripSelection(trips);
              });
            }

            if (trips.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Henuz ilan yok',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F3A30),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ilan olusturdugunuzda talepler burada gorunecek',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.push('/create-trip'),
                      icon: const Icon(Icons.add),
                      label: const Text('Ilan Olustur'),
                    ),
                  ],
                ),
              );
            }

            final selectedId = trips.any((trip) => trip.id == _selectedTripId)
                ? _selectedTripId!
                : trips.first.id;
            final bookingsAsync = ref.watch(driverBookingsProvider(selectedId));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E1DC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TripSelector(
                          trips: trips,
                          selectedTripId: selectedId,
                          tripRequestCounts: _tripRequestCounts,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedTripId = value);
                          },
                        ),
                        if (_loadingTripCounts) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Tum',
                              selected: _requestFilter == _RequestFilter.all,
                              onTap: () => setState(
                                  () => _requestFilter = _RequestFilter.all),
                            ),
                            _FilterChip(
                              label: 'Bekleyen',
                              selected:
                                  _requestFilter == _RequestFilter.pending,
                              onTap: () => setState(() =>
                                  _requestFilter = _RequestFilter.pending),
                            ),
                            _FilterChip(
                              label: 'Odeme Bekleyen',
                              selected: _requestFilter ==
                                  _RequestFilter.awaitingPayment,
                              onTap: () => setState(() => _requestFilter =
                                  _RequestFilter.awaitingPayment),
                            ),
                            _FilterChip(
                              label: 'Onayli',
                              selected:
                                  _requestFilter == _RequestFilter.confirmed,
                              onTap: () => setState(() =>
                                  _requestFilter = _RequestFilter.confirmed),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: bookingsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'Hata: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    data: (bookings) {
                      final filtered = _filterBookings(bookings);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                size: 56,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _emptyMessageForFilter(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => ref
                            .refresh(driverBookingsProvider(selectedId).future),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _RequestCard(
                            booking: filtered[index],
                            tripId: selectedId,
                            onRefresh: () => ref
                                .invalidate(driverBookingsProvider(selectedId)),
                          ),
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
  const _TripSelector({
    required this.trips,
    required this.selectedTripId,
    required this.tripRequestCounts,
    required this.onChanged,
  });

  final List<trip_provider.Trip> trips;
  final String selectedTripId;
  final Map<String, int> tripRequestCounts;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedTripId),
      initialValue: selectedTripId,
      decoration: const InputDecoration(labelText: 'Ilan Sec'),
      items: trips.map((trip) {
        final count = tripRequestCounts[trip.id] ?? 0;
        return DropdownMenuItem<String>(
          value: trip.id,
          child: Row(
            children: [
              Expanded(
                  child: Text('${trip.departureCity} -> ${trip.arrivalCity}')),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3ED),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFB7D3C4)),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F5A45),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F6B57) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2F6B57) : const Color(0xFFD5DED9),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF365D4E),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
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
    final canCancel = booking.status == BookingStatus.awaitingPayment ||
        booking.status == BookingStatus.confirmed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E2DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  image: booking.passengerAvatar != null
                      ? DecorationImage(
                          image: NetworkImage(booking.passengerAvatar!),
                        )
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '4.9 • 12 yolculuk',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD5E0DB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking.trip != null) ...[
                        Text(
                          '${booking.trip!.origin} -> ${booking.trip!.destination}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(booking.trip!.departureTime),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
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
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionsState.isLoading
                        ? null
                        : () => _acceptBooking(ref, context),
                    icon: const Icon(Icons.check),
                    label: const Text('Onayla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionsState.isLoading
                        ? null
                        : () => _rejectBooking(ref, context),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                  ),
                ),
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
                    onPressed: actionsState.isLoading
                        ? null
                        : () => _cancelBooking(ref, context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Iptal'),
                  ),
                ),
              ],
            ),
          ],
          if (booking.status != BookingStatus.confirmed && canCancel) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: actionsState.isLoading
                  ? null
                  : () => _cancelBooking(ref, context),
              icon: const Icon(Icons.cancel),
              label: const Text('Iptal'),
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
        title: const Text(
          'Rezervasyonu Iptal Et',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bu rezervasyonu iptal etmek istediginize emin misiniz?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
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
        onRefresh();
      }
    }
  }

  Future<void> _acceptBooking(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .acceptBooking(booking.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon onaylandi')),
      );
      onRefresh();
    }
  }

  Future<void> _rejectBooking(WidgetRef ref, BuildContext context) async {
    final success = await ref
        .read(bookingActionsProvider.notifier)
        .rejectBooking(booking.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon reddedildi')),
      );
      onRefresh();
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.pending => ('Bekliyor', AppColors.warning),
      BookingStatus.awaitingPayment => ('Odeme Bekliyor', AppColors.warning),
      BookingStatus.confirmed => ('Onaylandi', AppColors.success),
      BookingStatus.checkedIn => ('Check-in', AppColors.info),
      BookingStatus.completed => ('Tamamlandi', AppColors.secondary),
      BookingStatus.disputed => ('Incelemede', AppColors.warning),
      BookingStatus.cancelled => ('Iptal', AppColors.error),
      _ => ('', AppColors.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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

enum _RequestFilter {
  all,
  pending,
  awaitingPayment,
  confirmed,
}
