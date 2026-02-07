import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/location_autocomplete_field.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../vehicles/domain/vehicle_models.dart';
import 'package:dio/dio.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
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
  
  // Form state
  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departureTime = const TimeOfDay(hour: 9, minute: 0);
  int _availableSeats = 3;
  String _tripType = 'people'; // people, pets, cargo, food
  bool _allowsPets = false;
  bool _allowsCargo = false;
  bool _womenOnly = false;
  bool _instantBooking = true;
  bool _isLoading = false;
  String? _selectedVehicleId;

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final vehicles = await ref.read(myVehiclesProvider.future);
      final vehicleId = _selectedVehicleId ?? (vehicles.isNotEmpty ? vehicles.first.id : null);
      if (vehicleId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen önce bir araç ekleyin'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final dio = ref.read(dioProvider);
      final token = await ref.read(authTokenProvider.future);
      
      final departureDateTime = DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        _departureTime.hour,
        _departureTime.minute,
      );

      final data = <String, dynamic>{
        'departureCity': _departureCityController.text,
        'arrivalCity': _arrivalCityController.text,
        'departureTime': departureDateTime.toIso8601String(),
        'availableSeats': _availableSeats,
        'pricePerSeat': double.parse(_priceController.text),
        'type': _tripType,
        'allowsPets': _allowsPets,
        'allowsCargo': _allowsCargo,
        'womenOnly': _womenOnly,
        'instantBooking': _instantBooking,
        'description': _descriptionController.text,
        'vehicleId': vehicleId,
      };

      if (_departureAddress != null && _departureAddress!.isNotEmpty) {
        data['departureAddress'] = _departureAddress;
      }
      if (_arrivalAddress != null && _arrivalAddress!.isNotEmpty) {
        data['arrivalAddress'] = _arrivalAddress;
      }
      if (_departureLat != null && _departureLng != null) {
        data['departureLat'] = _departureLat;
        data['departureLng'] = _departureLng;
      }
      if (_arrivalLat != null && _arrivalLng != null) {
        data['arrivalLat'] = _arrivalLat;
        data['arrivalLng'] = _arrivalLng;
      }

      await dio.post(
        '/trips',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yolculuk başarıyla oluşturuldu!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    final hasVehicle = vehiclesAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Yolculuk Oluştur'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Type Selection
                  const Text('Yolculuk Tipi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _TripTypeSelector(
                    selected: _tripType,
                    onChanged: (type) => setState(() => _tripType = type),
                  ).animate().fadeIn(),

                  const SizedBox(height: 24),

                  // Route Card
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        LocationAutocompleteField(
                          controller: _departureCityController,
                          hintText: 'Nereden?',
                          icon: Icons.trip_origin,
                          iconColor: AppColors.primary,
                          validator: (value) => value == null || value.trim().isEmpty ? 'Bu alan gerekli' : null,
                          onSelected: (suggestion) {
                            final city = suggestion.city.trim();
                            if (city.isNotEmpty) {
                              _departureCityController.text = city;
                            }
                            _departureAddress = suggestion.displayName;
                            _departureLat = suggestion.lat;
                            _departureLng = suggestion.lon;
                          },
                        ),
                        const SizedBox(height: 16),
                        LocationAutocompleteField(
                          controller: _arrivalCityController,
                          hintText: 'Nereye?',
                          icon: Icons.location_on,
                          iconColor: AppColors.accent,
                          validator: (value) => value == null || value.trim().isEmpty ? 'Bu alan gerekli' : null,
                          onSelected: (suggestion) {
                            final city = suggestion.city.trim();
                            if (city.isNotEmpty) {
                              _arrivalCityController.text = city;
                            }
                            _arrivalAddress = suggestion.displayName;
                            _arrivalLat = suggestion.lat;
                            _arrivalLng = suggestion.lon;
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  _buildVehicleSection(vehiclesAsync).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  // Date & Time
                  Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: _selectDate,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tarih', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text(
                                      DateFormat('dd MMM', 'tr').format(_departureDate),
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: _selectTime,
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: AppColors.accent, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Saat', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text(
                                      _departureTime.format(context),
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 20),

                  // Seats & Price
                  Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Koltuk Sayısı', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _availableSeats > 1 ? () => setState(() => _availableSeats--) : null,
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                                  ),
                                  Text(
                                    '$_availableSeats',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    onPressed: _availableSeats < 7 ? () => setState(() => _availableSeats++) : null,
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kişi Başı Fiyat', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  suffixText: '₺',
                                  suffixStyle: TextStyle(color: AppColors.primary, fontSize: 20),
                                  hintText: '0',
                                  hintStyle: TextStyle(color: AppColors.textTertiary),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Fiyat girin' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),

                  // Preferences
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tercihler', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildSwitch('Evcil hayvana izin ver', Icons.pets, _allowsPets, (v) => setState(() => _allowsPets = v)),
                        _buildSwitch('Kargoya izin ver', Icons.inventory_2, _allowsCargo, (v) => setState(() => _allowsCargo = v)),
                        _buildSwitch('Sadece kadınlar', Icons.female, _womenOnly, (v) => setState(() => _womenOnly = v)),
                        _buildSwitch('Anında rezervasyon', Icons.flash_on, _instantBooking, (v) => setState(() => _instantBooking = v)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 20),

                  // Description
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Yolculuk hakkında not ekleyin (isteğe bağlı)',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: _isLoading ? 'Oluşturuluyor...' : 'Yolculuk Oluştur',
                      icon: Icons.check_circle,
                      onPressed: (!_isLoading && hasVehicle) ? _createTrip : null,
                    ),
                  ).animate().fadeIn(delay: 600.ms).scale(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSection(AsyncValue<List<Vehicle>> vehiclesAsync) {
    return vehiclesAsync.when(
      loading: () => GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Araçlar yükleniyor...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
      error: (e, _) => GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Text('Araçlar yüklenemedi: $e', style: const TextStyle(color: AppColors.error)),
      ),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Araç bulunamadı', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('İlan verebilmek için önce araç eklemelisiniz.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'Araç Ekle',
                    icon: Icons.directions_car_outlined,
                    onPressed: () => context.push('/vehicle-create'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/vehicle-verification'),
                  child: const Text('Ruhsat Doğrula'),
                ),
              ],
            ),
          );
        }

        final selectedId = _selectedVehicleId ?? vehicles.first.id;

        return GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Araç Seçimi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: vehicles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final isSelected = vehicle.id == selectedId;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedVehicleId = vehicle.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 220,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.glassBg : AppColors.glassBgDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.glassStroke,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${vehicle.brand} ${vehicle.model}',
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  vehicle.verified ? Icons.verified : Icons.verified_outlined,
                                  color: vehicle.verified ? AppColors.success : AppColors.textTertiary,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(vehicle.licensePlate, style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Text('${vehicle.year} . ${vehicle.seats} koltuk', style: const TextStyle(color: AppColors.textTertiary)),
                            if (vehicle.color != null) ...[
                              const SizedBox(height: 6),
                              Text(vehicle.color!, style: const TextStyle(color: AppColors.textTertiary)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildSwitch(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
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
        _TypeChip(icon: Icons.people, label: 'İnsan', value: 'people', selected: selected, onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(icon: Icons.pets, label: 'Hayvan', value: 'pets', selected: selected, onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(icon: Icons.inventory_2, label: 'Kargo', value: 'cargo', selected: selected, onTap: onChanged),
        const SizedBox(width: 8),
        _TypeChip(icon: Icons.restaurant, label: 'Gıda', value: 'food', selected: selected, onTap: onChanged),
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
            border: Border.all(color: isSelected ? Colors.transparent : AppColors.glassStroke),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.textSecondary, size: 20),
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





