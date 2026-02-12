import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../features/bookings/domain/booking_models.dart' hide Trip;

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? requestedFrom;
  final String? requestedTo;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.requestedFrom,
    this.requestedTo,
  });

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
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      final nextRoute = Uri(
        path: '/booking/${trip.id}',
        queryParameters: {
          if ((widget.requestedFrom ?? '').trim().isNotEmpty)
            'from': widget.requestedFrom!.trim(),
          if ((widget.requestedTo ?? '').trim().isNotEmpty)
            'to': widget.requestedTo!.trim(),
          if (trip.segmentPricePerSeat != null)
            'sp': trip.segmentPricePerSeat!.toStringAsFixed(2),
        },
      ).toString();
      final next = Uri.encodeComponent(nextRoute);
      context.push('/login?next=$next');
      return;
    }

    final isFull =
        trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';
    if (isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu yolculukta boş koltuk kalmadı.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    final booking =
        await ref.read(bookingActionsProvider.notifier).createBooking(
              trip.id,
              _selectedSeats,
              requestedFrom: widget.requestedFrom,
              requestedTo: widget.requestedTo,
            );
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

    String message = 'Rezervasyon başarısız. Lütfen tekrar deneyin.';
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
        SnackBar(content: Text('Mesajlaşma açılamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Widget _buildMessageButton(BuildContext context, Trip trip) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      final next = Uri.encodeComponent('/trip/${trip.id}');
      return OutlinedButton.icon(
        onPressed: () => context.push('/login?next=$next'),
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Giriş Yap'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      );
    }

    final isDriver = currentUser.id == trip.driverId;

    if (isDriver) {
      return OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mesajlaşma rezervasyonlar üzerinden açılır.')),
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
    final tripAsync = ref.watch(
      tripDetailWithContextProvider(
        TripDetailQuery(
          tripId: widget.tripId,
          from: widget.requestedFrom,
          to: widget.requestedTo,
        ),
      ),
    );
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: !kIsWeb,
      appBar: AppBar(
        title: const Text('Yolculuk Detayı'),
        backgroundColor: kIsWeb ? Colors.white : Colors.transparent,
        foregroundColor: kIsWeb ? const Color(0xFF1F3A30) : null,
        elevation: kIsWeb ? 1 : 0,
      ),
      body: Container(
        decoration: kIsWeb
            ? const BoxDecoration(color: Color(0xFFF3F6F4))
            : const BoxDecoration(gradient: AppColors.darkGradient),
        child: tripAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text('Hata: $e',
                  style: const TextStyle(color: AppColors.error))),
          data: (trip) {
            if (trip == null) {
              return const Center(
                  child: Text('Yolculuk bulunamadı',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            _ensureFallbackRoute(trip);
            if (kIsWeb) {
              return _buildWebContent(trip, bookingsAsync);
            }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final contentConstraints = screenWidth >= 1100
        ? const BoxConstraints(maxWidth: 920)
        : const BoxConstraints();
    final passengerCount =
        trip.occupancyPassengerCount ?? trip.passengers.length;
    final occupiedSeats = trip.occupancyConfirmedSeats ??
        trip.passengers.fold<int>(0, (sum, passenger) => sum + passenger.seats);
    final viaCitiesUnique = _uniqueViaCities(trip);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 90, 16, 120),
            child: Center(
              child: ConstrainedBox(
                constraints: contentConstraints,
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
                          Text('TL ${trip.pricePerSeat.toStringAsFixed(0)}',
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
                                        formatDurationMin(route.durationMin)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 240,
                              child: MapView(
                                initialPosition:
                                    _initialMapPosition(route, trip),
                                markers: markers,
                                polylines: routePolylines,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.08),
                    const SizedBox(height: 14),
                    if (viaCitiesUnique.isNotEmpty)
                      _buildViaStopsCard(viaCitiesUnique),
                    if (viaCitiesUnique.isNotEmpty) const SizedBox(height: 14),
                    if (canViewLiveLocation)
                      _buildLiveTrackingSection(isDriver, trip)
                    else
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          'Canlı konum, rezervasyon onayı ve ödeme sonrasında açılır.',
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
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MiniInfoChip(
                                icon: Icons.person_outline,
                                label: '$passengerCount yolcu',
                              ),
                              _MiniInfoChip(
                                icon: Icons.event_seat,
                                label: '$occupiedSeats koltuk dolu',
                              ),
                              _MiniInfoChip(
                                icon: Icons.airline_seat_recline_normal,
                                label: '${trip.availableSeats} boş koltuk',
                              ),
                              _PassengerVisibilityPill(
                                canViewPassengerList: canViewPassengerList,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!canViewPassengerList)
                            const Text(
                                'Yolcu listesi sadece sürücü ve onaylı yolcular için görünür.',
                                style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12))
                          else if (trip.passengers.isEmpty)
                            const Text('Henüz onaylı yolcu yok.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12))
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
                        width: 120, child: _buildMessageButton(context, trip)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildBookingBar(trip, totalPrice),
      ],
    );
  }

  List<TripViaCity> _uniqueViaCities(Trip trip) {
    final seen = <String>{};
    final list = <TripViaCity>[];
    for (final via in trip.viaCities) {
      final name = via.city.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      list.add(via);
    }
    return list;
  }

  Widget _buildViaStopsCard(
    List<TripViaCity> viaCities, {
    bool lightTheme = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.alt_route, label: 'Ara Duraklar'),
        const SizedBox(height: 10),
        for (int i = 0; i < viaCities.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i != viaCities.length - 1)
                    Container(
                      width: 2,
                      height: 26,
                      color: AppColors.glassStroke,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaCities[i].city,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((viaCities[i].district ?? '').trim().isNotEmpty)
                        Text(
                          viaCities[i].district!.trim(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (i != viaCities.length - 1) const SizedBox(height: 6),
        ],
      ],
    );

    if (!lightTheme) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4DED8)),
      ),
      child: content,
    );
  }

  Widget _buildWebContent(Trip trip, AsyncValue<List<Booking>> bookingsAsync) {
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
    final viaCitiesUnique = _uniqueViaCities(trip);
    final isFull =
        trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';
    final dateLabel =
        DateFormat('dd MMM yyyy, HH:mm', 'tr').format(trip.departureTime);
    final departureAddress = (trip.departureAddress ?? '').trim();
    final arrivalAddress = (trip.arrivalAddress ?? '').trim();
    final totalPrice = trip.pricePerSeat * _selectedSeats;
    final passengerCount =
        trip.occupancyPassengerCount ?? trip.passengers.length;
    final occupiedSeats = trip.occupancyConfirmedSeats ??
        trip.passengers.fold<int>(0, (sum, passenger) => sum + passenger.seats);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 38),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4DED8)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.18),
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
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.driverName,
                            style: const TextStyle(
                              color: Color(0xFF1F3A30),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$dateLabel • ${trip.departureCity} → ${trip.arrivalCity}',
                            style: const TextStyle(
                              color: Color(0xFF4E665C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Dolu',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1020;
                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD4DED8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rota detayları',
                              style: TextStyle(
                                color: Color(0xFF1F3A30),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _MiniInfoChip(
                                  icon: Icons.straighten,
                                  label:
                                      '${route?.distanceKm.toStringAsFixed(1) ?? '-'} km',
                                ),
                                const SizedBox(width: 8),
                                _MiniInfoChip(
                                  icon: Icons.timer,
                                  label: formatDurationMin(route?.durationMin),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${trip.departureCity} (${departureAddress.isEmpty ? 'Adres yok' : departureAddress})',
                              style: const TextStyle(
                                color: Color(0xFF2C4D40),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${trip.arrivalCity} (${arrivalAddress.isEmpty ? 'Adres yok' : arrivalAddress})',
                              style: const TextStyle(
                                color: Color(0xFF2C4D40),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 320,
                                child: MapView(
                                  initialPosition:
                                      _initialMapPosition(route, trip),
                                  markers: markers,
                                  polylines: routePolylines,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (viaCitiesUnique.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildViaStopsCard(viaCitiesUnique, lightTheme: true),
                      ],
                      const SizedBox(height: 12),
                      if (canViewLiveLocation)
                        _buildLiveTrackingSection(isDriver, trip)
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD4DED8)),
                          ),
                          child: const Text(
                            'Canlı konum, rezervasyon onayı ve ödeme tamamlandıktan sonra açılır.',
                            style: TextStyle(
                              color: Color(0xFF4E665C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD4DED8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yolcu durumu',
                              style: TextStyle(
                                color: Color(0xFF1F3A30),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MiniInfoChip(
                                  icon: Icons.person_outline,
                                  label: '$passengerCount yolcu',
                                ),
                                _MiniInfoChip(
                                  icon: Icons.event_seat,
                                  label: '$occupiedSeats koltuk dolu',
                                ),
                                _MiniInfoChip(
                                  icon: Icons.airline_seat_recline_normal,
                                  label: '${trip.availableSeats} boş koltuk',
                                ),
                                _PassengerVisibilityPill(
                                  canViewPassengerList: canViewPassengerList,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (canViewPassengerList &&
                                trip.passengers.isNotEmpty)
                              for (final passenger in trip.passengers)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PassengerRow(passenger: passenger),
                                )
                            else
                              const Text(
                                'Yolcu listesi sadece sürücü ve onaylı yolcular için görünür.',
                                style: TextStyle(
                                  color: Color(0xFF6A7F74),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final rightPanel = _buildWebBookingPanel(
                    trip,
                    totalPrice,
                    isFull: isFull,
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        leftColumn,
                        const SizedBox(height: 12),
                        rightPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: leftColumn),
                      const SizedBox(width: 14),
                      SizedBox(width: 330, child: rightPanel),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebBookingPanel(
    Trip trip,
    double totalPrice, {
    required bool isFull,
  }) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final approvalRequired = trip.bookingType == 'approval_required';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TL ${totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF2F6B57),
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          Text(
            '$_selectedSeats koltuk',
            style: const TextStyle(
              color: Color(0xFF4E665C),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: !isFull && _selectedSeats > 1
                    ? () => setState(() => _selectedSeats -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_selectedSeats',
                    style: const TextStyle(
                      color: Color(0xFF1F3A30),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: !isFull && _selectedSeats < trip.availableSeats
                    ? () => setState(() => _selectedSeats += 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              approvalRequired
                  ? 'Bu ilanda önce talep sürücü onayına düşer. Onaydan sonra ödeme açılır.'
                  : 'Bu ilanda anında rezervasyon açık. Rezervasyon sonrası ödeme adımı hemen açılır.',
              style: const TextStyle(
                color: Color(0xFF355A4C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: 130, child: _buildMessageButton(context, trip)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isBooking || isFull ? null : () => _book(trip),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: const Color(0xFF2F6B57),
              foregroundColor: Colors.white,
            ),
            child: Text(
              isFull
                  ? 'Dolu'
                  : (!isAuthenticated
                      ? 'Giriş yap ve rezerve et'
                      : (_isBooking
                          ? 'İşleniyor...'
                          : 'Rezervasyon talebi gönder')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingSection(bool isDriver, Trip trip) {
    final markers = _driverLocation != null
        ? [
            Marker(
              point: _driverLocation!,
              width: 48,
              height: 48,
              child: const Icon(Icons.navigation,
                  color: AppColors.accent, size: 34),
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
                  icon: Icons.my_location, label: 'Canlı Konum'),
              const Spacer(),
              Text(_locationConnected ? 'Bağlı' : 'Bağlı degil',
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
              height: 220,
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
              title: const Text('Konum paylaşımı',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Onaylı yolcular sürücü konumunu görür.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              activeThumbColor: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildBookingBar(Trip trip, double totalPrice) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isFull =
        trip.availableSeats <= 0 || trip.status.toLowerCase() == 'full';

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
            Row(
              children: [
                GlassContainer(
                  borderRadius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        onPressed:
                            !isFull && _selectedSeats < trip.availableSeats
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
                      Text('TL ${totalPrice.toStringAsFixed(0)}',
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
                      : (!isAuthenticated
                          ? 'Giriş yap ve rezerve et'
                          : (_isBooking ? 'İşleniyor...' : 'Rezerve Et')),
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
        strokeWidth: 5,
        borderStrokeWidth: 1.5,
        borderColor: Colors.white.withValues(alpha: 0.6),
      ),
    ];
  }

  List<Marker> _buildRouteMarkers(TripRouteSnapshot? route, Trip trip) {
    final seenVia = <String>{};
    final viaMarkers = trip.viaCities
        .where((via) => via.lat != null && via.lng != null)
        .where((via) {
          final key = via.city.trim().toLowerCase();
          if (key.isEmpty) return false;
          return seenVia.add(key);
        })
        .map(
          (via) => Marker(
            point: LatLng(via.lat!, via.lng!),
            width: 16,
            height: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        )
        .toList();

    if (route != null && route.points.isNotEmpty) {
      final first = route.points.first;
      final last = route.points.last;
      return [
        Marker(
          point: LatLng(first.lat, first.lng),
          width: 42,
          height: 42,
          child: const Icon(Icons.play_circle_fill,
              color: AppColors.primary, size: 28),
        ),
        Marker(
          point: LatLng(last.lat, last.lng),
          width: 42,
          height: 42,
          child:
              const Icon(Icons.flag_circle, color: AppColors.accent, size: 30),
        ),
        ...viaMarkers,
      ];
    }

    if (trip.departureLat != null &&
        trip.departureLng != null &&
        trip.arrivalLat != null &&
        trip.arrivalLng != null) {
      return [
        Marker(
          point: LatLng(trip.departureLat!, trip.departureLng!),
          width: 42,
          height: 42,
          child: const Icon(Icons.play_circle_fill,
              color: AppColors.primary, size: 28),
        ),
        Marker(
          point: LatLng(trip.arrivalLat!, trip.arrivalLng!),
          width: 42,
          height: 42,
          child:
              const Icon(Icons.flag_circle, color: AppColors.accent, size: 30),
        ),
        ...viaMarkers,
      ];
    }

    return viaMarkers;
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

class _PassengerVisibilityPill extends StatelessWidget {
  final bool canViewPassengerList;

  const _PassengerVisibilityPill({required this.canViewPassengerList});

  @override
  Widget build(BuildContext context) {
    final enabled = canViewPassengerList;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? AppColors.secondaryLight : AppColors.neutralBorder,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enabled ? 'Liste açık' : 'Liste kısıtlı',
        style: TextStyle(
          color: enabled ? const Color(0xFF166534) : const Color(0xFF374151),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PassengerRow extends StatelessWidget {
  final TripPassenger passenger;

  const _PassengerRow({required this.passenger});

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
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
    );
    final ratingBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            passenger.ratingAvg.toStringAsFixed(1),
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
    final seatsBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Text(
        '${passenger.seats} koltuk',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glassBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        passenger.fullName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [ratingBadge, seatsBadge],
                ),
              ],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  passenger.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ratingBadge,
              const SizedBox(width: 8),
              seatsBadge,
            ],
          );
        },
      ),
    );
  }
}
