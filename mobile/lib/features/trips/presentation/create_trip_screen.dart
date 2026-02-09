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
  String pickupType = 'city_center';
  String note = '';

  _PickupPolicyValue();

  Map<String, dynamic> toJson(Map<String, dynamic> city) {
    return {
      'city': city['city'],
      if (city['district'] != null) 'district': city['district'],
      'pickupAllowed': pickupAllowed,
      'pickupType': pickupType,
      if (note.trim().isNotEmpty) 'note': note.trim(),
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

  int _availableSeats = 3;
  String _tripType = 'people';
  bool _allowsPets = false;
  bool _allowsCargo = false;
  bool _womenOnly = false;
  bool _instantBooking = true;

  String? _selectedVehicleId;
  List<_RouteAlt> _routeAlternatives = const [];
  int _selectedRouteIndex = 0;
  final Map<String, _PickupPolicyValue> _pickupPolicies = {};

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
          content: Text('Rota cikarmak icin kalkis ve varis alanlarini doldurun.'),
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
        return _RouteAlt(
          id: map['id']?.toString() ?? '',
          route: Map<String, dynamic>.from(map['route'] as Map? ?? const {}),
          viaCities: ((map['viaCities'] as List?) ?? const [])
              .whereType<Map>()
              .map((city) => Map<String, dynamic>.from(city))
              .toList(),
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
      });
      _resetPickupPoliciesFromSelectedRoute();
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

  Future<bool> _ensureCoordinatesFromInputs() async {
    bool changed = false;

    if (_departureLat == null || _departureLng == null) {
      final suggestion = await _resolveSuggestion(_departureCityController.text);
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

  void _resetPickupPoliciesFromSelectedRoute() {
    _pickupPolicies.clear();
    final selected = _selectedRoute;
    if (selected == null) return;

    for (final city in selected.viaCities) {
      final key = _cityKey(city);
      _pickupPolicies[key] = _PickupPolicyValue();
    }
    setState(() {});
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
    final cityName = city['city']?.toString().toLowerCase() ?? '';
    final district = city['district']?.toString().toLowerCase() ?? '';
    return '$cityName|$district';
  }

  List<LatLng> _routePoints(_RouteAlt alternative) {
    final rawPoints = (alternative.route['points'] as List?) ?? const [];
    return rawPoints.whereType<Map>().map((point) {
      final map = Map<String, dynamic>.from(point);
      final lat = (map['lat'] ?? 0).toDouble();
      final lng = (map['lng'] ?? 0).toDouble();
      return LatLng(lat, lng);
    }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
  }

  LatLng _routeMapCenter() {
    final selected = _selectedRoute;
    if (selected != null) {
      final points = _routePoints(selected);
      if (points.isNotEmpty) {
        return points[(points.length / 2).floor()];
      }
    }

    if (_departureLat != null && _departureLng != null) {
      return LatLng(_departureLat!, _departureLng!);
    }
    return const LatLng(41.0082, 28.9784);
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
    return [
      Marker(
        point: points.first,
        width: 32,
        height: 32,
        child: const Icon(Icons.trip_origin, color: AppColors.primary, size: 20),
      ),
      Marker(
        point: points.last,
        width: 34,
        height: 34,
        child: const Icon(Icons.location_on, color: AppColors.accent, size: 24),
      ),
    ];
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
              'Henuz rota cikarilmadi. Kalkis/varis metni yaziliysa sistem koordinati otomatik cozmeye calisir.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassStroke),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _routeMapCenter(),
                  initialZoom: 6.5,
                  backgroundColor: AppColors.background,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.ridesharing_app',
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
                    onSelected: (_) {
                      setState(() => _selectedRouteIndex = i);
                      _resetPickupPoliciesFromSelectedRoute();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < _routeAlternatives.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RouteAlternativeCard(
                  alternative: _routeAlternatives[i],
                  isSelected: i == _selectedRouteIndex,
                  onTap: () {
                    setState(() => _selectedRouteIndex = i);
                    _resetPickupPoliciesFromSelectedRoute();
                  },
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
          const Text('Adim 3/5 - Ara sehir yolcu alma',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Her gecilen sehir/ilce icin yolcu alip almayacaginizi secin.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          if (selected.viaCities.isEmpty)
            const Text('Bu rota icin ara sehir bulunamadi.',
                style: TextStyle(color: AppColors.textSecondary))
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
                  city['district'] != null
                      ? '${city['city']} / ${city['district']}'
                      : city['city']?.toString() ?? '-',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Switch.adaptive(
                value: value.pickupAllowed,
                onChanged: (next) => setState(() => value.pickupAllowed = next),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(
                'pickup_${key}_${value.pickupType}_${value.pickupAllowed}'),
            initialValue: value.pickupType,
            items: const [
              DropdownMenuItem(value: 'bus_terminal', child: Text('Otogar')),
              DropdownMenuItem(
                  value: 'rest_stop', child: Text('Dinlenme Tesisi')),
              DropdownMenuItem(
                  value: 'city_center', child: Text('Sehir Merkezi')),
              DropdownMenuItem(value: 'address', child: Text('Adres')),
            ],
            onChanged: value.pickupAllowed
                ? (next) {
                    if (next != null) {
                      setState(() => value.pickupType = next);
                    }
                  }
                : null,
            decoration: const InputDecoration(labelText: 'Alim tipi'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value.note,
            enabled: value.pickupAllowed,
            decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
            onChanged: (next) => value.note = next,
          ),
        ],
      ),
    );
  }

  Widget _buildStepVehicleAndPricing(AsyncValue<List<Vehicle>> vehiclesAsync) {
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
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Kisi basi fiyat', suffixText: '₺'),
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
                                ? () => setState(() => _availableSeats -= 1)
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
                                ? () => setState(() => _availableSeats += 1)
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
              onChanged: (next) => setState(() => _tripType = next)),
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
              'Secili rota: ${selected.distanceKm.toStringAsFixed(1)} km, ${selected.durationMin.toStringAsFixed(0)} dk',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 8),
          const Text('Yolculuk olustur butonu ile kaydi tamamlayabilirsiniz.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
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
                          '${vehicle.brand} ${vehicle.model} - ${vehicle.licensePlate}',
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
        return value.toJson(city);
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

class _RouteAlternativeCard extends StatelessWidget {
  final _RouteAlt alternative;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteAlternativeCard({
    required this.alternative,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                Text('Rota ${alternative.id}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${alternative.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Text('${alternative.durationMin.toStringAsFixed(0)} dk',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alternative.viaCities
                  .map((city) => city['city'])
                  .whereType<String>()
                  .join(' -> '),
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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


