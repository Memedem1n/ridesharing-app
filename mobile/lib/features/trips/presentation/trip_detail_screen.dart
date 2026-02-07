import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../features/bookings/domain/booking_models.dart' hide Trip;

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedSeats = 1;
  bool _isBooking = false;
  io.Socket? _locationSocket;
  bool _locationConnected = false;
  LatLng? _driverLocation;
  bool _shareLocation = false;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initLocationSocket();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _locationSocket?.emit('leave_trip', {'tripId': widget.tripId});
    _locationSocket?.disconnect();
    _locationSocket?.dispose();
    super.dispose();
  }

  String _locationSocketBaseUrl() {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '/location', query: '').toString();
  }

  Future<void> _initLocationSocket() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null) return;

    final socket = io.io(
      _locationSocketBaseUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _locationSocket = socket;

    socket.onConnect((_) {
      if (!mounted) return;
      setState(() => _locationConnected = true);
      socket.emit('join_trip', {'tripId': widget.tripId});
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _locationConnected = false);
    });

    socket.on('location_update', (data) {
      if (data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final lat = map['lat'];
      final lng = map['lng'];
      if (lat == null || lng == null) return;
      if (!mounted) return;
      setState(() => _driverLocation = LatLng(lat.toDouble(), lng.toDouble()));
    });

    socket.connect();
  }

  Future<void> _toggleShareLocation(bool value) async {
    if (value) {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni gerekli.')),
          );
        }
        return;
      }
      await _startLocationSharing();
      if (mounted) setState(() => _shareLocation = true);
    } else {
      _stopLocationSharing();
      if (mounted) setState(() => _shareLocation = false);
    }
  }

  Future<void> _startLocationSharing() async {
    try {
      final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _sendLocation(current);
    } catch (_) {
      // Ignore initial location errors
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((position) {
      _sendLocation(position);
    });
  }

  void _stopLocationSharing() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _sendLocation(Position position) {
    _locationSocket?.emit('driver_location_update', {
      'tripId': widget.tripId,
      'lat': position.latitude,
      'lng': position.longitude,
      'speed': position.speed,
      'heading': position.heading,
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _book(Trip trip) async {
    setState(() => _isBooking = true);

    try {
      final token = await ref.read(authTokenProvider.future);
      final service = ref.read(tripServiceProvider);
      final success = await service.createBooking(trip.id, _selectedSeats, token);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervasyon başarılı!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/reservations');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rezervasyon başarısız. Tekrar deneyin.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Booking? _findBookingForTrip(List<Booking> bookings, String tripId) {
    final matched = bookings.where((b) => b.tripId == tripId).toList();
    if (matched.isEmpty) return null;
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matched.first;
  }

  Widget _buildMessageButton(BuildContext context, Trip trip, AsyncValue<List<Booking>> bookingsAsync) {
    final currentUser = ref.read(currentUserProvider);
    final isDriver = currentUser?.id == trip.driverId;
    final tripInfo = '${trip.departureCity} → ${trip.arrivalCity}';

    if (isDriver) {
      return OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yolcu mesajları rezervasyonlardan açılır.')),
          );
        },
        icon: const Icon(Icons.message, size: 18),
        label: const Text('Mesaj'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      );
    }

    return bookingsAsync.when(
      loading: () => OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.message, size: 18),
        label: const Text('Mesaj'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      error: (e, _) => OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mesajlar yüklenemedi: $e')),
          );
        },
        icon: const Icon(Icons.message, size: 18),
        label: const Text('Mesaj'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      data: (bookings) {
        final booking = _findBookingForTrip(bookings, trip.id);
        return OutlinedButton.icon(
          onPressed: () {
            if (booking == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mesaj için önce rezervasyon yapın.')),
              );
              return;
            }

            if (booking.status == BookingStatus.cancelled || booking.status == BookingStatus.rejected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bu rezervasyon için mesaj gönderilemez.')),
              );
              return;
            }

            context.push(
              '/chat/${booking.id}?name=${Uri.encodeComponent(trip.driverName)}&trip=${Uri.encodeComponent(tripInfo)}',
            );
          },
          icon: const Icon(Icons.message, size: 18),
          label: const Text('Mesaj'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Yolculuk Detayı'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paylaşma yakında eklenecek.')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: tripAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          data: (trip) {
            if (trip == null) {
              return const Center(child: Text('Yolculuk bulunamadı', style: TextStyle(color: AppColors.textSecondary)));
            }
            return _buildContent(trip, bookingsAsync);
          },
        ),
      ),
    );
  }

  Widget _buildLiveTrackingSection(Trip trip) {
    final currentUser = ref.read(currentUserProvider);
    final isDriver = currentUser?.id == trip.driverId;
    final hasLocation = _driverLocation != null;
    final markers = hasLocation
        ? [
            Marker(
              point: _driverLocation!,
              width: 40,
              height: 40,
              child: const Icon(Icons.navigation, color: AppColors.accent, size: 30),
            ),
          ]
        : <Marker>[];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Canlı Konum', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_locationConnected ? AppColors.success : AppColors.textTertiary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _locationConnected ? 'Bağlı' : 'Bağlı değil',
                  style: TextStyle(
                    color: _locationConnected ? AppColors.success : AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: MapView(
                initialPosition: hasLocation ? _driverLocation! : const LatLng(41.0082, 28.9784),
                markers: markers,
              ),
            ),
          ),
          if (!hasLocation) ...[
            const SizedBox(height: 8),
            const Text('Sürücü konumu bekleniyor...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (isDriver) ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _shareLocation,
              onChanged: _locationConnected ? _toggleShareLocation : null,
              title: const Text('Canlı konum paylaş', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Yolculara konumunuzu gösterin', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(Trip trip, AsyncValue<List<Booking>> bookingsAsync) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'tr');
    final totalPrice = trip.pricePerSeat * _selectedSeats;
    final departureAddress = (trip.departureAddress ?? '').trim();
    final arrivalAddress = (trip.arrivalAddress ?? '').trim();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),

                // Driver Card
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: trip.driverPhoto != null ? NetworkImage(trip.driverPhoto!) : null,
                        child: trip.driverPhoto == null
                          ? Text(trip.driverName[0], style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold))
                          : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.driverName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: AppColors.warning, size: 16),
                                const SizedBox(width: 4),
                                Text('${trip.driverRating.toStringAsFixed(1)} puan', style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildMessageButton(context, trip, bookingsAsync),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Route Card
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(dateFormat.format(trip.departureTime),
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(width: 2, height: 50, color: AppColors.glassStroke),
                              const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(timeFormat.format(trip.departureTime),
                                  style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(trip.departureCity, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                                if (departureAddress.isNotEmpty)
                                  Text(departureAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
                                else
                                  const Text('Adres bilgisi yok', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                const SizedBox(height: 30),
                                Text(trip.arrivalCity, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                                if (arrivalAddress.isNotEmpty)
                                  Text(arrivalAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
                                else
                                  const Text('Adres bilgisi yok', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                _buildLiveTrackingSection(trip).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Vehicle Card
                if (trip.vehicleBrand != null)
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.glassBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_car, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${trip.vehicleBrand} ${trip.vehicleModel ?? ""}',
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              if (trip.vehicleColor != null)
                                Text(trip.vehicleColor!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Features
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yolculuk Özellikleri', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _FeatureItem(icon: Icons.event_seat, label: '${trip.availableSeats} boş koltuk', active: true),
                          if (trip.instantBooking) _FeatureItem(icon: Icons.flash_on, label: 'Anında onay', active: true),
                          _FeatureItem(icon: Icons.pets, label: 'Evcil hayvan', active: trip.allowsPets),
                          _FeatureItem(icon: Icons.inventory_2, label: 'Kargo', active: trip.allowsCargo),
                          if (trip.womenOnly) _FeatureItem(icon: Icons.female, label: 'Sadece kadın', active: true),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                if (trip.description != null && trip.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notlar', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(trip.description!, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // Booking Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: AppColors.glassStroke)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: AppColors.primary, size: 20),
                        onPressed: _selectedSeats > 1 ? () => setState(() => _selectedSeats--) : null,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$_selectedSeats', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.primary, size: 20),
                        onPressed: _selectedSeats < trip.availableSeats ? () => setState(() => _selectedSeats++) : null,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₺${totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('$_selectedSeats koltuk', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                GradientButton(
                  text: _isBooking ? 'İşleniyor...' : 'Rezerve Et',
                  icon: Icons.check_circle,
                  isLoading: _isBooking,
                  onPressed: _isBooking ? null : () => _book(trip),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _FeatureItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: active ? AppColors.primary : AppColors.textTertiary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w500 : FontWeight.normal,
          )),
        ],
      ),
    );
  }
}
