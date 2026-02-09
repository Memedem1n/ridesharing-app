import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/message_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../features/bookings/domain/booking_models.dart' hide Trip;

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final RouteService _routeService = RouteService();

  int _selectedSeats = 1;
  bool _isBooking = false;
  io.Socket? _locationSocket;
  bool _locationConnected = false;
  bool _roomJoined = false;
  bool _shareLocation = false;
  bool _isOpeningChat = false;
  LatLng? _driverLocation;
  StreamSubscription<Position>? _positionSub;
  TripRouteSnapshot? _fallbackRoute;
  bool _loadingFallbackRoute = false;

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
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _locationConnected = false;
        _roomJoined = false;
      });
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

  void _syncRoomSubscription(bool canViewLiveLocation) {
    if (_locationSocket == null || !_locationConnected) return;

    if (canViewLiveLocation && !_roomJoined) {
      _locationSocket!.emit('join_trip', {'tripId': widget.tripId});
      _roomJoined = true;
      return;
    }

    if (!canViewLiveLocation && _roomJoined) {
      _locationSocket!.emit('leave_trip', {'tripId': widget.tripId});
      _roomJoined = false;
      if (mounted) {
        setState(() => _driverLocation = null);
      }
    }
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
      return;
    }

    _stopLocationSharing();
    if (mounted) setState(() => _shareLocation = false);
  }

  Future<void> _startLocationSharing() async {
    try {
      final current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _sendLocation(current);
    } catch (_) {
      // Ignore initial location errors.
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen(_sendLocation);
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
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _book(Trip trip) async {
    final isFull = trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';
    if (isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu yolculukta bos koltuk kalmadi.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    final booking = await ref
        .read(bookingActionsProvider.notifier)
        .createBooking(trip.id, _selectedSeats);
    if (!mounted) return;

    if (booking != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervasyon olusturuldu.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/reservations');
      setState(() => _isBooking = false);
      return;
    }

    String message = 'Rezervasyon basarisiz. Lutfen tekrar deneyin.';
    final actionState = ref.read(bookingActionsProvider);
    final actionError = actionState.asError?.error;
    if (actionError is ApiException && actionError.message.trim().isNotEmpty) {
      message = actionError.message;
    } else if (actionError != null) {
      final parsed = actionError.toString().trim();
      if (parsed.isNotEmpty) {
        message = parsed;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );

    setState(() => _isBooking = false);
  }

  Booking? _findBookingForTrip(List<Booking> bookings, String tripId) {
    final matched = bookings.where((b) => b.tripId == tripId).toList();
    if (matched.isEmpty) return null;
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matched.first;
  }

  bool _statusAllowsLiveLocation(BookingStatus status) {
    return status == BookingStatus.confirmed ||
        status == BookingStatus.checkedIn ||
        status == BookingStatus.completed ||
        status == BookingStatus.disputed;
  }

  Future<void> _openChatForTrip(Trip trip) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    try {
      final conversation =
          await ref.read(messageServiceProvider).openTripConversation(trip.id);
      if (!mounted) return;

      final tripInfo = '${trip.departureCity} -> ${trip.arrivalCity}';
      final otherName = conversation.otherName.trim().isNotEmpty
          ? conversation.otherName
          : trip.driverName;

      context.push(
        '/chat/${conversation.id}?name=${Uri.encodeComponent(otherName)}&trip=${Uri.encodeComponent(tripInfo)}',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final apiError = ApiException.fromDioError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiError.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesajlasma acilamadi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Widget _buildMessageButton(BuildContext context, Trip trip) {
    final currentUser = ref.read(currentUserProvider);
    final isDriver = currentUser?.id == trip.driverId;

    if (isDriver) {
      return OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mesajlasma rezervasyonlar uzerinden acilir.')),
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

    return OutlinedButton.icon(
      onPressed: _isOpeningChat ? null : () => _openChatForTrip(trip),
      icon: _isOpeningChat
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.message, size: 18),
      label: Text(_isOpeningChat ? 'Aciliyor...' : 'Mesaj'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Future<void> _ensureFallbackRoute(Trip trip) async {
    if (_loadingFallbackRoute || _fallbackRoute != null) return;
    if (trip.route != null) return;
    if (trip.departureLat == null ||
        trip.departureLng == null ||
        trip.arrivalLat == null ||
        trip.arrivalLng == null) {
      return;
    }

    _loadingFallbackRoute = true;
    try {
      final routeInfo = await _routeService.getRoute(
        LatLng(trip.departureLat!, trip.departureLng!),
        LatLng(trip.arrivalLat!, trip.arrivalLng!),
      );

      if (!mounted || routeInfo == null) return;
      final points = routeInfo.points
          .map((point) =>
              TripRoutePoint(lat: point.latitude, lng: point.longitude))
          .toList();
      setState(() {
        _fallbackRoute = TripRouteSnapshot(
          provider: 'osrm-mobile',
          distanceKm: routeInfo.distanceKm,
          durationMin: routeInfo.durationMin,
          points: points,
        );
      });
    } finally {
      _loadingFallbackRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Yolculuk Detayi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: tripAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error))),
          data: (trip) {
            if (trip == null) {
              return const Center(
                  child: Text('Yolculuk bulunamadi',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            _ensureFallbackRoute(trip);
            return _buildContent(trip, bookingsAsync);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Trip trip, AsyncValue<List<Booking>> bookingsAsync) {
    final currentUser = ref.read(currentUserProvider);
    final isDriver = currentUser?.id == trip.driverId;

    Booking? viewerBooking;
    final myBookings = bookingsAsync.asData?.value;
    if (myBookings != null) {
      viewerBooking = _findBookingForTrip(myBookings, trip.id);
    }

    final bookingAllowsLiveLocation = viewerBooking != null &&
        _statusAllowsLiveLocation(viewerBooking.status);
    final canViewLiveLocation =
        isDriver || trip.canViewLiveLocation || bookingAllowsLiveLocation;
    final canViewPassengerList = isDriver || trip.canViewPassengerList;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncRoomSubscription(canViewLiveLocation);
      }
    });

    final route = trip.route ?? _fallbackRoute;
    final routePolylines = _buildRoutePolylines(route, trip);
    final markers = _buildRouteMarkers(route, trip);

    final dateFormat = DateFormat('EEE, d MMM yyyy', 'tr');
    final departureAddress = (trip.departureAddress ?? '').trim();
    final arrivalAddress = (trip.arrivalAddress ?? '').trim();
    final totalPrice = trip.pricePerSeat * _selectedSeats;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 90, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: trip.driverPhoto != null
                            ? NetworkImage(trip.driverPhoto!)
                            : null,
                        child: trip.driverPhoto == null
                            ? Text(
                                trip.driverName.isNotEmpty
                                    ? trip.driverName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              )
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: AppColors.warning, size: 14),
                                const SizedBox(width: 4),
                                Text(trip.driverRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(dateFormat.format(trip.departureTime),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('₺${trip.pricePerSeat.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.08),
                const SizedBox(height: 14),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(icon: Icons.route, label: 'Rota'),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary)),
                              Container(
                                  width: 2,
                                  height: 44,
                                  color: AppColors.glassStroke),
                              const Icon(Icons.location_on,
                                  color: AppColors.accent, size: 18),
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
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  departureAddress.isEmpty
                                      ? 'Adres bilgisi yok'
                                      : departureAddress,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                                const SizedBox(height: 18),
                                Text(trip.arrivalCity,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  arrivalAddress.isEmpty
                                      ? 'Adres bilgisi yok'
                                      : arrivalAddress,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (route != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _MiniInfoChip(
                                icon: Icons.straighten,
                                label:
                                    '${route.distanceKm.toStringAsFixed(1)} km'),
                            const SizedBox(width: 8),
                            _MiniInfoChip(
                                icon: Icons.timer,
                                label:
                                    '${route.durationMin.toStringAsFixed(0)} dk'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 180,
                          child: MapView(
                            initialPosition: _initialMapPosition(route, trip),
                            markers: markers,
                            polylines: routePolylines,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08),
                const SizedBox(height: 14),
                if (trip.viaCities.isNotEmpty)
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                            icon: Icons.alt_route,
                            label: 'Ara Sehir Politikasi'),
                        const SizedBox(height: 8),
                        for (final via in trip.viaCities)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              via.district == null || via.district!.isEmpty
                                  ? via.city
                                  : '${via.city} / ${via.district}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (trip.viaCities.isNotEmpty) const SizedBox(height: 14),
                if (canViewLiveLocation)
                  _buildLiveTrackingSection(isDriver, trip)
                else
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Canli konum, rezervasyon onayi ve odeme sonrasinda acilir.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 14),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                          icon: Icons.groups, label: 'Yolcu Durumu'),
                      const SizedBox(height: 8),
                      Text(
                          '${trip.occupancyPassengerCount ?? 0} yolcu - ${trip.occupancyConfirmedSeats ?? 0} koltuk dolu',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 10),
                      if (!canViewPassengerList)
                        const Text(
                            'Yolcu listesi sadece surucu ve onayli yolcular icin gorunur.',
                            style: TextStyle(
                                color: AppColors.textTertiary, fontSize: 12))
                      else if (trip.passengers.isEmpty)
                        const Text('Henuz onayli yolcu yok.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12))
                      else
                        for (final passenger in trip.passengers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PassengerRow(passenger: passenger),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                    width: 120,
                    child: _buildMessageButton(context, trip)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _buildBookingBar(trip, totalPrice),
      ],
    );
  }

  Widget _buildLiveTrackingSection(bool isDriver, Trip trip) {
    final markers = _driverLocation != null
        ? [
            Marker(
              point: _driverLocation!,
              width: 42,
              height: 42,
              child: const Icon(Icons.navigation,
                  color: AppColors.accent, size: 30),
            ),
          ]
        : <Marker>[];

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(
                  icon: Icons.my_location, label: 'Canli Konum'),
              const Spacer(),
              Text(_locationConnected ? 'Bagli' : 'Bagli degil',
                  style: TextStyle(
                      color: _locationConnected
                          ? AppColors.success
                          : AppColors.textTertiary,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 170,
              child: MapView(
                initialPosition: _driverLocation ??
                    _initialMapPosition(trip.route ?? _fallbackRoute, trip),
                markers: markers,
              ),
            ),
          ),
          if (isDriver)
            SwitchListTile.adaptive(
              value: _shareLocation,
              onChanged: _locationConnected ? _toggleShareLocation : null,
              contentPadding: EdgeInsets.zero,
              title: const Text('Konum paylasimi',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Onayli yolcular surucu konumunu gorur.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              activeThumbColor: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildBookingBar(Trip trip, double totalPrice) {
    final isFull = trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppColors.glassStroke)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFull)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
            Row(
              children: [
                GlassContainer(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove,
                            color: AppColors.primary, size: 18),
                        onPressed: !isFull && _selectedSeats > 1
                            ? () => setState(() => _selectedSeats -= 1)
                            : null,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$_selectedSeats',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add,
                            color: AppColors.primary, size: 18),
                        onPressed: !isFull && _selectedSeats < trip.availableSeats
                            ? () => setState(() => _selectedSeats += 1)
                            : null,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₺${totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text(
                        isFull ? 'Koltuk yok' : '$_selectedSeats koltuk',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GradientButton(
                  text: isFull
                      ? 'Dolu'
                      : (_isBooking ? 'Isleniyor...' : 'Rezerve Et'),
                  icon: Icons.check_circle,
                  isLoading: _isBooking && !isFull,
                  onPressed: _isBooking || isFull ? null : () => _book(trip),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Polyline> _buildRoutePolylines(TripRouteSnapshot? route, Trip trip) {
    final points = <LatLng>[];

    if (route != null && route.points.length >= 2) {
      points.addAll(route.points.map((point) => LatLng(point.lat, point.lng)));
    } else if (trip.departureLat != null &&
        trip.departureLng != null &&
        trip.arrivalLat != null &&
        trip.arrivalLng != null) {
      points.add(LatLng(trip.departureLat!, trip.departureLng!));
      points.add(LatLng(trip.arrivalLat!, trip.arrivalLng!));
    }

    if (points.length < 2) return const [];

    return [
      Polyline(
        points: points,
        color: AppColors.primary,
        strokeWidth: 4,
      ),
    ];
  }

  List<Marker> _buildRouteMarkers(TripRouteSnapshot? route, Trip trip) {
    if (route != null && route.points.isNotEmpty) {
      final first = route.points.first;
      final last = route.points.last;
      return [
        Marker(
          point: LatLng(first.lat, first.lng),
          width: 34,
          height: 34,
          child:
              const Icon(Icons.trip_origin, color: AppColors.primary, size: 22),
        ),
        Marker(
          point: LatLng(last.lat, last.lng),
          width: 34,
          height: 34,
          child:
              const Icon(Icons.location_on, color: AppColors.accent, size: 24),
        ),
      ];
    }

    if (trip.departureLat != null &&
        trip.departureLng != null &&
        trip.arrivalLat != null &&
        trip.arrivalLng != null) {
      return [
        Marker(
          point: LatLng(trip.departureLat!, trip.departureLng!),
          width: 34,
          height: 34,
          child:
              const Icon(Icons.trip_origin, color: AppColors.primary, size: 22),
        ),
        Marker(
          point: LatLng(trip.arrivalLat!, trip.arrivalLng!),
          width: 34,
          height: 34,
          child:
              const Icon(Icons.location_on, color: AppColors.accent, size: 24),
        ),
      ];
    }

    return const [];
  }

  LatLng _initialMapPosition(TripRouteSnapshot? route, Trip trip) {
    if (route != null && route.points.isNotEmpty) {
      final middle = route.points[(route.points.length / 2).floor()];
      return LatLng(middle.lat, middle.lng);
    }

    if (trip.departureLat != null && trip.departureLng != null) {
      return LatLng(trip.departureLat!, trip.departureLng!);
    }

    return const LatLng(41.0082, 28.9784);
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PassengerRow extends StatelessWidget {
  final TripPassenger passenger;

  const _PassengerRow({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glassBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: passenger.profilePhotoUrl != null
                ? NetworkImage(passenger.profilePhotoUrl!)
                : null,
            child: passenger.profilePhotoUrl == null
                ? Text(
                    passenger.fullName.isNotEmpty
                        ? passenger.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(passenger.fullName,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(passenger.ratingAvg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 10),
          Text('${passenger.seats} koltuk',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

