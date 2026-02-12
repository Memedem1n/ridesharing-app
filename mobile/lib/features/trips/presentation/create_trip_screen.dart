import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/location_autocomplete_field.dart';
import '../../vehicles/domain/vehicle_models.dart';

class _RouteAlt {
  final String id;
  final Map<String, dynamic> route;
  final List<Map<String, dynamic>> viaCities;

  const _RouteAlt(
      {required this.id, required this.route, required this.viaCities});

  double get distanceKm => (route['distanceKm'] ?? 0).toDouble();
  double get durationMin => (route['durationMin'] ?? 0).toDouble();
}

class _PickupPolicyValue {
  bool pickupAllowed = true;

  _PickupPolicyValue();

  Map<String, dynamic> toJson(
    Map<String, dynamic> city,
    String globalPickupType,
  ) {
    return {
      'city': city['city'],
      if (city['district'] != null) 'district': city['district'],
      'pickupAllowed': pickupAllowed,
      'pickupType': globalPickupType,
    };
  }
}

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  final _departureCityController = TextEditingController();
  final _arrivalCityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _departureAddress;
  String? _arrivalAddress;
  double? _departureLat;
  double? _departureLng;
  double? _arrivalLat;
  double? _arrivalLng;

  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departureTime = const TimeOfDay(hour: 9, minute: 0);

  int _step = 0;
  bool _isLoading = false;
  bool _isRoutePreviewLoading = false;
  bool _isEstimateLoading = false;

  int _availableSeats = 3;
  String _tripType = 'people';
  bool _allowsPets = false;
  bool _allowsCargo = false;
  bool _womenOnly = false;
  bool _instantBooking = false;

  String? _selectedVehicleId;
  List<_RouteAlt> _routeAlternatives = const [];
  int _selectedRouteIndex = 0;
  final Map<String, _PickupPolicyValue> _pickupPolicies = {};
  String _globalPickupType = 'city_center';
  double? _estimatedDistanceKm;
  double? _estimatedDurationMin;
  double? _estimatedTotalCost;

  @override
  void dispose() {
    _departureCityController.dispose();
    _arrivalCityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  Future<void> _previewRoutes() async {
    final departureText = _departureCityController.text.trim();
    final arrivalText = _arrivalCityController.text.trim();
    if (departureText.isEmpty || arrivalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Rota cikarmak icin kalkis ve varis alanlarini doldurun.'),
        ),
      );
      return;
    }

    setState(() => _isRoutePreviewLoading = true);

    try {
      await _ensureCoordinatesFromInputs();

      final dio = ref.read(dioProvider);
      final token = await ref.read(authTokenProvider.future);
      final payload = <String, dynamic>{
        'departureCity': _departureCityController.text.trim(),
        'arrivalCity': _arrivalCityController.text.trim(),
      };
      if (_departureLat != null) payload['departureLat'] = _departureLat;
      if (_departureLng != null) payload['departureLng'] = _departureLng;
      if (_arrivalLat != null) payload['arrivalLat'] = _arrivalLat;
      if (_arrivalLng != null) payload['arrivalLng'] = _arrivalLng;

      final response = await dio.post(
        '/trips/route-preview',
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 35),
        ),
      );

      final alternativesRaw =
          (response.data['alternatives'] as List?) ?? const [];
      final alternatives = alternativesRaw.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final viaCitiesRaw = ((map['viaCities'] as List?) ?? const [])
            .whereType<Map>()
            .map((city) => Map<String, dynamic>.from(city))
            .toList();
        return _RouteAlt(
          id: map['id']?.toString() ?? '',
          route: Map<String, dynamic>.from(map['route'] as Map? ?? const {}),
          viaCities: _normalizeViaCities(viaCitiesRaw),
        );
      }).toList();

      if (alternatives.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rota bulunamadi. Kalkis/varis icin daha net bir sehir veya ilce secin.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _routeAlternatives = alternatives;
        _selectedRouteIndex = 0;
        _syncPickupPoliciesFromSelectedRoute();
        _syncEstimateFromSelectedRoute();
      });
      await _estimateRouteCost();
    } on DioException catch (e) {
      final apiError = ApiException.fromDioError(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiError.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isRoutePreviewLoading = false);
      }
    }
  }

  Future<LocationSuggestion?> _resolveSuggestion(String input) async {
    final query = input.trim();
    if (query.isEmpty) return null;

    final results = await _locationService.search(query);
    if (results.isEmpty) return null;

    final normalized = query.toLowerCase();
    for (final suggestion in results) {
      if (suggestion.city.trim().toLowerCase() == normalized) {
        return suggestion;
      }
    }

    return results.first;
  }

  String _normalizeCityKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u0307', '') // remove Turkish dotted-i combining mark
        .replaceAll('i', 'i');
  }

  List<Map<String, dynamic>> _normalizeViaCities(
    List<Map<String, dynamic>> raw,
  ) {
    if (raw.isEmpty) return const [];
    final departureKey = _normalizeCityKey(_departureCityController.text);
    final arrivalKey = _normalizeCityKey(_arrivalCityController.text);

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      final name = entry['city']?.toString() ?? '';
      final key = _normalizeCityKey(name);
      if (key.isEmpty) continue;
      if (key == departureKey || key == arrivalKey) continue;
      if (!seen.add(key)) continue;

      final normalized = Map<String, dynamic>.from(entry);
      // UX: keep ara-durak list at city level (no district noise).
      normalized.remove('district');
      result.add(normalized);
    }

    return result;
  }

  Future<bool> _ensureCoordinatesFromInputs() async {
    bool changed = false;

    if (_departureLat == null || _departureLng == null) {
      final suggestion =
          await _resolveSuggestion(_departureCityController.text);
      if (suggestion != null) {
        _departureLat = suggestion.lat;
        _departureLng = suggestion.lon;
        _departureAddress ??= suggestion.displayName;
        if (_departureCityController.text.trim().isEmpty) {
          _departureCityController.text = suggestion.city;
        }
        changed = true;
      }
    }

    if (_arrivalLat == null || _arrivalLng == null) {
      final suggestion = await _resolveSuggestion(_arrivalCityController.text);
      if (suggestion != null) {
        _arrivalLat = suggestion.lat;
        _arrivalLng = suggestion.lon;
        _arrivalAddress ??= suggestion.displayName;
        if (_arrivalCityController.text.trim().isEmpty) {
          _arrivalCityController.text = suggestion.city;
        }
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }

    return _departureLat != null &&
        _departureLng != null &&
        _arrivalLat != null &&
        _arrivalLng != null;
  }

  void _syncEstimateFromSelectedRoute() {
    final selected = _selectedRoute;
    if (selected == null) {
      _estimatedDistanceKm = null;
      _estimatedDurationMin = null;
      return;
    }
    _estimatedDistanceKm = selected.distanceKm;
    _estimatedDurationMin = selected.durationMin;
  }

  Future<void> _estimateRouteCost() async {
    final hasCoordinates = _departureLat != null &&
        _departureLng != null &&
        _arrivalLat != null &&
        _arrivalLng != null;
    if (!hasCoordinates) return;

    setState(() => _isEstimateLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/routes/estimate',
        data: {
          'departureCity': _departureCityController.text.trim(),
          'arrivalCity': _arrivalCityController.text.trim(),
          'departureLat': _departureLat,
          'departureLng': _departureLng,
          'arrivalLat': _arrivalLat,
          'arrivalLng': _arrivalLng,
          'tripType': _tripType,
          'seats': _availableSeats,
          'peakTraffic': false,
        },
      );

      final data = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _estimatedDistanceKm =
            (data['distanceKm'] ?? _estimatedDistanceKm ?? 0).toDouble();
        _estimatedDurationMin =
            (data['durationMin'] ?? _estimatedDurationMin ?? 0).toDouble();
        _estimatedTotalCost = (data['estimatedCost'] ?? 0).toDouble();
      });
    } on DioException {
      // Soft-fail: keep route creation flow usable even if estimate API is unavailable.
    } finally {
      if (mounted) {
        setState(() => _isEstimateLoading = false);
      }
    }
  }

  void _syncPickupPoliciesFromSelectedRoute() {
    final selected = _selectedRoute;
    if (selected == null) {
      _pickupPolicies.clear();
      return;
    }

    final nextPolicies = <String, _PickupPolicyValue>{};
    for (final city in selected.viaCities) {
      final key = _cityKey(city);
      nextPolicies[key] = _pickupPolicies[key] ?? _PickupPolicyValue();
    }
    _pickupPolicies
      ..clear()
      ..addAll(nextPolicies);
  }

  Future<void> _selectRoute(int index) async {
    if (index < 0 || index >= _routeAlternatives.length) return;
    setState(() {
      _selectedRouteIndex = index;
      _syncPickupPoliciesFromSelectedRoute();
      _syncEstimateFromSelectedRoute();
    });
    await _estimateRouteCost();
  }

  _RouteAlt? get _selectedRoute {
    if (_routeAlternatives.isEmpty) return null;
    if (_selectedRouteIndex < 0 ||
        _selectedRouteIndex >= _routeAlternatives.length) {
      return _routeAlternatives.first;
    }
    return _routeAlternatives[_selectedRouteIndex];
  }

  String _cityKey(Map<String, dynamic> city) {
    final cityName = city['city']?.toString() ?? '';
    return _normalizeCityKey(cityName);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<LatLng> _routePoints(_RouteAlt alternative) {
    final rawPoints = (alternative.route['points'] as List?) ?? const [];
    return rawPoints
        .whereType<Map>()
        .map((point) {
          final map = Map<String, dynamic>.from(point);
          final lat = (map['lat'] ?? 0).toDouble();
          final lng = (map['lng'] ?? 0).toDouble();
          return LatLng(lat, lng);
        })
        .where((point) => point.latitude != 0 || point.longitude != 0)
        .toList();
  }

  ({double minLat, double minLng, double maxLat, double maxLng})?
      _routeBoundsFromBbox(_RouteAlt alternative) {
    final raw = alternative.route['bbox'];
    if (raw is! Map) return null;
    final bbox = Map<String, dynamic>.from(raw);
    final minLat = _toDouble(bbox['minLat']);
    final minLng = _toDouble(bbox['minLng']);
    final maxLat = _toDouble(bbox['maxLat']);
    final maxLng = _toDouble(bbox['maxLng']);
    if (minLat == null || minLng == null || maxLat == null || maxLng == null) {
      return null;
    }
    return (
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }

  ({double minLat, double minLng, double maxLat, double maxLng})?
      _routeBoundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return (
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }

  ({double minLat, double minLng, double maxLat, double maxLng})?
      _selectedRouteBounds() {
    final selected = _selectedRoute;
    if (selected == null) return null;
    final bboxBounds = _routeBoundsFromBbox(selected);
    if (bboxBounds != null) return bboxBounds;
    return _routeBoundsFromPoints(_routePoints(selected));
  }

  LatLng _routeMapCenter() {
    final bounds = _selectedRouteBounds();
    if (bounds != null) {
      return LatLng(
        (bounds.minLat + bounds.maxLat) / 2,
        (bounds.minLng + bounds.maxLng) / 2,
      );
    }

    if (_departureLat != null && _departureLng != null) {
      return LatLng(_departureLat!, _departureLng!);
    }
    return const LatLng(41.0082, 28.9784);
  }

  double _routeMapZoom() {
    final bounds = _selectedRouteBounds();
    if (bounds == null) return 7.2;

    final latSpan = (bounds.maxLat - bounds.minLat).abs();
    final lngSpan = (bounds.maxLng - bounds.minLng).abs();
    final span = (latSpan > lngSpan ? latSpan : lngSpan) * 1.22;

    if (span >= 18) return 4.8;
    if (span >= 12) return 5.4;
    if (span >= 7) return 6.2;
    if (span >= 4) return 7.0;
    if (span >= 2.2) return 8.0;
    if (span >= 1.2) return 8.8;
    if (span >= 0.6) return 9.6;
    if (span >= 0.3) return 10.6;
    if (span >= 0.15) return 11.4;
    return 12.2;
  }

  CameraFit? _selectedRouteCameraFit() {
    final bounds = _selectedRouteBounds();
    if (bounds == null) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(bounds.minLat, bounds.minLng),
        LatLng(bounds.maxLat, bounds.maxLng),
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  List<Polyline> _routePreviewPolylines() {
    final polylines = <Polyline>[];
    for (int i = 0; i < _routeAlternatives.length; i++) {
      final points = _routePoints(_routeAlternatives[i]);
      if (points.length < 2) continue;
      final isSelected = i == _selectedRouteIndex;
      polylines.add(
        Polyline(
          points: points,
          color: isSelected
              ? AppColors.primary
              : AppColors.textTertiary.withValues(alpha: 0.45),
          strokeWidth: isSelected ? 5 : 3,
          borderStrokeWidth: isSelected ? 2 : 0,
          borderColor:
              isSelected ? AppColors.background.withValues(alpha: 0.55) : null,
        ),
      );
    }
    return polylines;
  }

  List<Marker> _routePreviewMarkers() {
    final selected = _selectedRoute;
    if (selected == null) return const [];
    final points = _routePoints(selected);
    if (points.length < 2) return const [];
    final markers = <Marker>[
      Marker(
        point: points.first,
        width: 32,
        height: 32,
        child: const Icon(Icons.play_circle_fill,
            color: AppColors.primary, size: 22),
      ),
      Marker(
        point: points.last,
        width: 34,
        height: 34,
        child: const Icon(Icons.flag_circle, color: AppColors.accent, size: 24),
      ),
    ];

    for (final city in selected.viaCities) {
      final lat = _toDouble(city['lat']);
      final lng = _toDouble(city['lng']);
      final name = city['city']?.toString() ?? '';
      if (lat == null || lng == null || name.trim().isEmpty) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 12,
          height: 12,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  bool _canContinueStep(int step) {
    switch (step) {
      case 0:
        return (_departureCityController.text.trim().isNotEmpty &&
            _arrivalCityController.text.trim().isNotEmpty);
      case 1:
        return _routeAlternatives.isNotEmpty;
      case 2:
        return _selectedRoute != null;
      case 3:
        return _selectedVehicleId != null &&
            (_priceController.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  String? _blockedReasonForStep(int step) {
    if (_canContinueStep(step)) return null;
    switch (step) {
      case 0:
        return 'Kalkis ve varis alanlarini doldurun.';
      case 1:
        return 'Devam etmek icin once "Rotalari Cikar" ile rota secin.';
      case 2:
        return 'Ara durak adimi icin secili rota gerekli.';
      case 3:
        return 'Arac secimi ve fiyat girisi tamamlanmali.';
      default:
        return null;
    }
  }

  void _nextStep() {
    if (!_canContinueStep(_step)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bu adimi tamamlamadan devam edemezsiniz.')),
      );
      return;
    }

    if (_step < 4) {
      setState(() => _step += 1);
    }
  }

  void _previousStep() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    if (kIsWeb) {
      return _buildWebScaffold(vehiclesAsync);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Yolculuk Olustur'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _StepHeader(currentStep: _step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _buildStepContent(vehiclesAsync),
                  ),
                ),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebScaffold(AsyncValue<List<Vehicle>> vehiclesAsync) {
    const stepTitles = <String>[
      'Rota bilgileri',
      'Rota secimi',
      'Ara duraklar',
      'Arac ve fiyat',
      'Son ayarlar',
    ];
    const stepDescriptions = <String>[
      'Kalkis, varis, tarih ve saat sec.',
      'Alternatif rotalari getir ve sec.',
      'Ara sehir toplama politikasini belirle.',
      'Arac secimi ve kisi basi fiyat tanimi.',
      'Tercihleri kontrol et ve ilani yayinla.',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        title: const Text('Yolculuk Olustur'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Ana Sayfa'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE6E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Web panelinden ilani adim adim olustur. Tum alanlar mobil ile ayni API akisini kullanir.',
                              style: const TextStyle(
                                color: Color(0xFF4E665C),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 220,
                            child: _StepHeader(currentStep: _step),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 300,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFDCE6E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Adimlar',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F3A30),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  for (int i = 0; i < stepTitles.length; i++)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _WebStepTile(
                                        index: i,
                                        title: stepTitles[i],
                                        description: stepDescriptions[i],
                                        isActive: i == _step,
                                        isDone: i < _step,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(right: 2),
                              child: _buildStepContent(vehiclesAsync),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildWebBottomActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(AsyncValue<List<Vehicle>> vehiclesAsync) {
    switch (_step) {
      case 0:
        return _buildStepRouteBasics();
      case 1:
        return _buildStepRouteSelection();
      case 2:
        return _buildStepPickupPolicies();
      case 3:
        return _buildStepVehicleAndPricing(vehiclesAsync);
      default:
        return _buildStepReview();
    }
  }

  Widget _buildStepRouteBasics() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adim 1/5 - Nereden nereye?',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          LocationAutocompleteField(
            controller: _departureCityController,
            hintText: 'Nereden?',
            icon: Icons.trip_origin,
            iconColor: AppColors.primary,
            onTextChanged: (_) {
              _departureAddress = null;
              _departureLat = null;
              _departureLng = null;
              if (_routeAlternatives.isNotEmpty) {
                setState(() {
                  _routeAlternatives = const [];
                  _selectedRouteIndex = 0;
                  _pickupPolicies.clear();
                });
              }
            },
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bu alan gerekli'
                : null,
            onSelected: (suggestion) {
              _departureCityController.text = suggestion.city.trim().isNotEmpty
                  ? suggestion.city
                  : _departureCityController.text;
              _departureAddress = suggestion.displayName;
              _departureLat = suggestion.lat;
              _departureLng = suggestion.lon;
            },
          ),
          const SizedBox(height: 12),
          LocationAutocompleteField(
            controller: _arrivalCityController,
            hintText: 'Nereye?',
            icon: Icons.location_on,
            iconColor: AppColors.accent,
            onTextChanged: (_) {
              _arrivalAddress = null;
              _arrivalLat = null;
              _arrivalLng = null;
              if (_routeAlternatives.isNotEmpty) {
                setState(() {
                  _routeAlternatives = const [];
                  _selectedRouteIndex = 0;
                  _pickupPolicies.clear();
                });
              }
            },
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bu alan gerekli'
                : null,
            onSelected: (suggestion) {
              _arrivalCityController.text = suggestion.city.trim().isNotEmpty
                  ? suggestion.city
                  : _arrivalCityController.text;
              _arrivalAddress = suggestion.displayName;
              _arrivalLat = suggestion.lat;
              _arrivalLng = suggestion.lon;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                      DateFormat('dd MMM yyyy', 'tr').format(_departureDate)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_departureTime.format(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildStepRouteSelection() {
    final routePolylines = _routePreviewPolylines();
    final routeMarkers = _routePreviewMarkers();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adim 2/5 - Rota secimi',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Rotalari cikarip size en uygun alternatifi secin.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: _isRoutePreviewLoading
                  ? 'Rotalar getiriliyor...'
                  : 'Rotalari Cikar',
              icon: Icons.alt_route,
              isLoading: _isRoutePreviewLoading,
              onPressed: _isRoutePreviewLoading ? null : _previewRoutes,
            ),
          ),
          const SizedBox(height: 10),
          if (_routeAlternatives.isEmpty)
            const Text(
              'Henuz rota cikarilmadi. Kalkis ve varis metni varsa sistem koordinati otomatik cozmeye calisir.',
              style: TextStyle(color: AppColors.textPrimary),
            )
          else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.glassBgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassStroke),
              ),
              child: Text(
                '${_routeAlternatives.length} rota bulundu. Secim degistiginde ara durak tercihleri korunur.',
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
            Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassStroke),
              ),
              child: FlutterMap(
                key: ValueKey(
                    'route_map_${_selectedRouteIndex}_${_routeAlternatives.length}'),
                options: MapOptions(
                  initialCenter: _routeMapCenter(),
                  initialZoom: _routeMapZoom(),
                  initialCameraFit: _selectedRouteCameraFit(),
                  backgroundColor: AppColors.background,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yoliva.app',
                  ),
                  PolylineLayer(polylines: routePolylines),
                  MarkerLayer(markers: routeMarkers),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _routeAlternatives.length; i++)
                  ChoiceChip(
                    label: Text('Rota ${i + 1}'),
                    selected: i == _selectedRouteIndex,
                    onSelected: (_) => _selectRoute(i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedRoute != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RouteAlternativeCard(
                  index: _selectedRouteIndex,
                  alternative: _selectedRoute!,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _step > 0 ? _previousStep : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Geri'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 180,
                      child: GradientButton(
                        text: 'Devam Et',
                        icon: Icons.arrow_forward,
                        onPressed: _canContinueStep(_step) ? _nextStep : null,
                      ),
                    ),
                  ],
                ),
              ),
            if (kIsWeb && _blockedReasonForStep(_step) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _blockedReasonForStep(_step)!,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildStepPickupPolicies() {
    final selected = _selectedRoute;
    if (selected == null) {
      return const GlassContainer(
        padding: EdgeInsets.all(16),
        child: Text('Once bir rota secmelisiniz.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adim 3/5 - Ara durak politikasi',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Tum ara duraklar icin tek bir alim noktasi secin, ardindan sehir bazinda ac/kapat yapin.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _globalPickupType,
            decoration: const InputDecoration(
              labelText: 'Yolcu alma noktasi',
            ),
            items: const [
              DropdownMenuItem(
                value: 'city_center',
                child: Text('Sehir merkezi'),
              ),
              DropdownMenuItem(
                value: 'bus_terminal',
                child: Text('Otogar'),
              ),
              DropdownMenuItem(
                value: 'rest_stop',
                child: Text('Dinlenme tesisi'),
              ),
              DropdownMenuItem(
                value: 'address',
                child: Text('Adres'),
              ),
            ],
            onChanged: (next) {
              if (next == null) return;
              setState(() => _globalPickupType = next);
            },
          ),
          const SizedBox(height: 12),
          if (selected.viaCities.isEmpty)
            const Text(
              'Bu rota icin ara sehir bulunamadi. Bir sonraki adima gecebilirsiniz.',
              style: TextStyle(color: AppColors.textPrimary),
            )
          else
            for (final city in selected.viaCities)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPickupPolicyCard(city),
              ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildPickupPolicyCard(Map<String, dynamic> city) {
    final key = _cityKey(city);
    final value = _pickupPolicies.putIfAbsent(key, () => _PickupPolicyValue());
    final cityName = city['city']?.toString().trim() ?? '-';
    final title = cityName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: value.pickupAllowed
                      ? AppColors.secondaryLight
                      : AppColors.neutralBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value.pickupAllowed
                      ? 'Yolcu alimi acik'
                      : 'Yolcu alimi kapali',
                  style: TextStyle(
                    color: value.pickupAllowed
                        ? const Color(0xFF166534)
                        : const Color(0xFF4B5563),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value.pickupAllowed,
                onChanged: (next) => setState(() => value.pickupAllowed = next),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ortak alim noktasi: ${_pickupTypeLabel(_globalPickupType)}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
          if (!value.pickupAllowed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Bu sehirde yolcu alinmayacak.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  String _pickupTypeLabel(String type) {
    switch (type) {
      case 'bus_terminal':
        return 'Otogar';
      case 'rest_stop':
        return 'Dinlenme tesisi';
      case 'address':
        return 'Adres';
      default:
        return 'Sehir merkezi';
    }
  }

  Widget _buildStepVehicleAndPricing(AsyncValue<List<Vehicle>> vehiclesAsync) {
    final suggestedPerSeat = _availableSeats > 0 && _estimatedTotalCost != null
        ? (_estimatedTotalCost! / _availableSeats)
        : null;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adim 4/5 - Arac ve fiyat',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildVehicleSection(vehiclesAsync),
          const SizedBox(height: 12),
          _buildRouteEstimateCard(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kisi basi fiyat',
              helperText: suggestedPerSeat == null
                  ? 'Orn: 250'
                  : 'Oneri: TL ${suggestedPerSeat.toStringAsFixed(0)} kisi basi',
              helperStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              suffixText: 'TL',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Fiyat gerekli' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Koltuk',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _availableSeats > 1
                                ? () {
                                    setState(() => _availableSeats -= 1);
                                    _estimateRouteCost();
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.primary),
                          ),
                          Text('$_availableSeats',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          IconButton(
                            onPressed: _availableSeats < 7
                                ? () {
                                    setState(() => _availableSeats += 1);
                                    _estimateRouteCost();
                                  }
                                : null,
                            icon: const Icon(Icons.add_circle_outline,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildStepReview() {
    final selected = _selectedRoute;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adim 5/5 - Son ayarlar',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _TripTypeSelector(
              selected: _tripType,
              onChanged: (next) async {
                setState(() => _tripType = next);
                await _estimateRouteCost();
              }),
          const SizedBox(height: 12),
          _buildSwitch('Evcil hayvana izin ver', Icons.pets, _allowsPets,
              (v) => setState(() => _allowsPets = v)),
          _buildSwitch('Kargoya izin ver', Icons.inventory_2, _allowsCargo,
              (v) => setState(() => _allowsCargo = v)),
          _buildSwitch('Sadece kadinlar', Icons.female, _womenOnly,
              (v) => setState(() => _womenOnly = v)),
          _buildSwitch('Aninda rezervasyon', Icons.flash_on, _instantBooking,
              (v) => setState(() => _instantBooking = v)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Yolculuk notu (opsiyonel)'),
          ),
          const SizedBox(height: 12),
          if (selected != null)
            Text(
              'Secili rota: ${selected.distanceKm.toStringAsFixed(1)} km, ${formatDurationMin(selected.durationMin)}',
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          const SizedBox(height: 8),
          const Text('Yolculuk olustur butonu ile kaydi tamamlayabilirsiniz.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _buildRouteEstimateCard() {
    final hasEstimate = _estimatedTotalCost != null &&
        _estimatedDistanceKm != null &&
        _estimatedDurationMin != null;

    if (!hasEstimate) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.glassBgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Tahmini maliyet icin once rota cikarin.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isEstimateLoading ? null : _estimateRouteCost,
              child: Text(_isEstimateLoading ? 'Hesaplaniyor...' : 'Hesapla'),
            ),
          ],
        ),
      );
    }

    final perSeatSuggestion = _availableSeats > 0
        ? (_estimatedTotalCost! / _availableSeats)
        : _estimatedTotalCost!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rota tahmini',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isEstimateLoading ? null : _estimateRouteCost,
                child: Text(_isEstimateLoading ? 'Yenileniyor...' : 'Yenile'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_estimatedDistanceKm!.toStringAsFixed(1)} km • ${formatDurationMin(_estimatedDurationMin)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Toplam tahmini maliyet: TL ${_estimatedTotalCost!.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Onerilen kisi basi: TL ${perSeatSuggestion.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary))),
          Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildVehicleSection(AsyncValue<List<Vehicle>> vehiclesAsync) {
    return vehiclesAsync.when(
      loading: () => const Text('Araclar yukleniyor...',
          style: TextStyle(color: AppColors.textSecondary)),
      error: (e, _) => Text('Araclar yuklenemedi: $e',
          style: const TextStyle(color: AppColors.error)),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Arac bulunamadi. Once arac ekleyin.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              GradientButton(
                  text: 'Arac Ekle',
                  icon: Icons.directions_car_outlined,
                  onPressed: () => context.push('/vehicle-create')),
            ],
          );
        }

        final selectedId = _selectedVehicleId ?? vehicles.first.id;
        _selectedVehicleId ??= vehicles.first.id;

        return Column(
          children: vehicles.map((vehicle) {
            final selected = vehicle.id == selectedId;
            final ownerBadge =
                vehicle.ownershipType == 'relative' ? ' • Akraba araci' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedVehicleId = vehicle.id),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.glassBg : AppColors.glassBgDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.glassStroke,
                        width: selected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${vehicle.brand} ${vehicle.model} - ${vehicle.licensePlate}$ownerBadge',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppColors.glassStroke)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 10),
          Expanded(
            child: GradientButton(
              text: _step == 4
                  ? (_isLoading ? 'Olusturuluyor...' : 'Yolculuk Olustur')
                  : 'Devam Et',
              icon: _step == 4 ? Icons.check_circle : Icons.arrow_forward,
              isLoading: _isLoading,
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_step == 4) {
                        _createTrip();
                      } else {
                        _nextStep();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6E1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Geri'),
            ),
          if (_step > 0) const SizedBox(width: 10),
          SizedBox(
            width: 230,
            child: GradientButton(
              text: _step == 4
                  ? (_isLoading ? 'Olusturuluyor...' : 'Yolculugu Olustur')
                  : 'Devam Et',
              icon: _step == 4 ? Icons.check_circle : Icons.arrow_forward,
              isLoading: _isLoading,
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_step == 4) {
                        _createTrip();
                      } else {
                        _nextStep();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedRoute = _selectedRoute;
    if (selectedRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Yolculuk olusturmadan once rota secmelisiniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final token = await ref.read(authTokenProvider.future);
      final departureDateTime = DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        _departureTime.hour,
        _departureTime.minute,
      );

      final pickupPolicies = selectedRoute.viaCities.map((city) {
        final key = _cityKey(city);
        final value = _pickupPolicies[key] ?? _PickupPolicyValue();
        return value.toJson(city, _globalPickupType);
      }).toList();

      await dio.post(
        '/trips',
        data: {
          'departureCity': _departureCityController.text.trim(),
          'arrivalCity': _arrivalCityController.text.trim(),
          if ((_departureAddress ?? '').isNotEmpty)
            'departureAddress': _departureAddress,
          if ((_arrivalAddress ?? '').isNotEmpty)
            'arrivalAddress': _arrivalAddress,
          if (_departureLat != null) 'departureLat': _departureLat,
          if (_departureLng != null) 'departureLng': _departureLng,
          if (_arrivalLat != null) 'arrivalLat': _arrivalLat,
          if (_arrivalLng != null) 'arrivalLng': _arrivalLng,
          'departureTime': departureDateTime.toIso8601String(),
          'availableSeats': _availableSeats,
          'pricePerSeat': double.parse(_priceController.text.trim()),
          'type': _tripType,
          'allowsPets': _allowsPets,
          'allowsCargo': _allowsCargo,
          'womenOnly': _womenOnly,
          'instantBooking': _instantBooking,
          'bookingType': _instantBooking ? 'instant' : 'approval_required',
          'description': _descriptionController.text.trim(),
          'vehicleId': _selectedVehicleId,
          'routeSnapshot': selectedRoute.route,
          'viaCities': selectedRoute.viaCities,
          'pickupPolicies': pickupPolicies,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Yolculuk basariyla olusturuldu.'),
            backgroundColor: AppColors.success),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final apiError = ApiException.fromDioError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiError.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _StepHeader extends StatelessWidget {
  final int currentStep;

  const _StepHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final done = index <= currentStep;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : AppColors.glassStroke,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WebStepTile extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final bool isActive;
  final bool isDone;

  const _WebStepTile({
    required this.index,
    required this.title,
    required this.description,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive
        ? AppColors.primary
        : isDone
            ? const Color(0xFF3A8C6B)
            : const Color(0xFF93A8A0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEAF3EE) : const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF8EB9A7) : const Color(0xFFD9E4DE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F3A30),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF597469),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteAlternativeCard extends StatelessWidget {
  final int index;
  final _RouteAlt alternative;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteAlternativeCard({
    required this.index,
    required this.alternative,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final viaSummary = alternative.viaCities
        .map((city) => city['city'])
        .whereType<String>()
        .where((city) => city.trim().isNotEmpty)
        .toList();
    final viaText =
        viaSummary.isEmpty ? 'Direkt rota' : viaSummary.join(' -> ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.glassBg : AppColors.glassBgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.glassStroke,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Rota ${index + 1}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Secili',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${alternative.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatDurationMin(alternative.durationMin),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              viaText,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TripTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
            icon: Icons.people,
            label: 'Insan',
            value: 'people',
            selected: selected,
            onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(
            icon: Icons.pets,
            label: 'Hayvan',
            value: 'pets',
            selected: selected,
            onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(
            icon: Icons.inventory_2,
            label: 'Kargo',
            value: 'cargo',
            selected: selected,
            onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(
            icon: Icons.restaurant,
            label: 'Gida',
            value: 'food',
            selected: selected,
            onTap: onChanged),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : AppColors.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.glassStroke),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
