import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/location_autocomplete_field.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _passengers = 1;
  String _selectedType = 'people';

  void _search() {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen nereden ve nereye alanlarını doldurun.')),
      );
      return;
    }

    ref.read(tripSearchParamsProvider.notifier).state = TripSearchParams(
      from: from,
      to: to,
      date: _selectedDate,
      seats: _passengers,
      type: _selectedType,
    );
    final dateParam = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final encodedFrom = Uri.encodeComponent(from);
    final encodedTo = Uri.encodeComponent(to);
    context.push('/search-results?from=$encodedFrom&to=$encodedTo&date=$dateParam');
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM', 'tr').format(_selectedDate);
    final popularRoutesAsync = ref.watch(popularRoutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuk Ara')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    LocationAutocompleteField(
                      controller: _fromController,
                      hintText: 'Nereden?',
                      icon: Icons.circle_outlined,
                      iconColor: AppColors.primary,
                    ),
                    const Divider(color: AppColors.glassStroke),
                    LocationAutocompleteField(
                      controller: _toController,
                      hintText: 'Nereye?',
                      icon: Icons.location_on,
                      iconColor: AppColors.accent,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.glassBgDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.glassStroke),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(dateLabel, style: const TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.glassBgDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.glassStroke),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                                  onPressed: _passengers > 1 ? () => setState(() => _passengers--) : null,
                                ),
                                Text('$_passengers', style: const TextStyle(color: AppColors.textPrimary)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  onPressed: _passengers < 8 ? () => setState(() => _passengers++) : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SearchTypeChip(
                            label: 'İnsan',
                            icon: Icons.group,
                            selected: _selectedType == 'people',
                            onSelected: () => setState(() => _selectedType = 'people'),
                          ),
                          _SearchTypeChip(
                            label: 'Hayvan',
                            icon: Icons.pets,
                            selected: _selectedType == 'pets',
                            onSelected: () => setState(() => _selectedType = 'pets'),
                          ),
                          _SearchTypeChip(
                            label: 'Kargo',
                            icon: Icons.inventory_2,
                            selected: _selectedType == 'cargo',
                            onSelected: () => setState(() => _selectedType = 'cargo'),
                          ),
                          _SearchTypeChip(
                            label: 'Gıda',
                            icon: Icons.restaurant,
                            selected: _selectedType == 'food',
                            onSelected: () => setState(() => _selectedType = 'food'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(text: 'Ara', icon: Icons.search, onPressed: _search),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Popüler Rotalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              popularRoutesAsync.when(
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (e, _) => Text('Rotalar yüklenemedi: $e', style: const TextStyle(color: AppColors.error)),
                data: (routes) {
                  if (routes.isEmpty) {
                    return const Text('Henüz popüler rota yok.', style: TextStyle(color: AppColors.textSecondary));
                  }

                  return Column(
                    children: [
                      for (final route in routes.take(5)) ...[
                        _PopularRouteCard(
                          from: route.from,
                          to: route.to,
                          price: route.minPrice,
                          count: route.count,
                          onTap: () {
                            _fromController.text = route.from;
                            _toController.text = route.to;
                            _search();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
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
}

class _PopularRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final double price;
  final int count;
  final VoidCallback onTap;

  const _PopularRouteCard({
    required this.from,
    required this.to,
    required this.price,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$from → $to', style: const TextStyle(color: AppColors.textPrimary)),
            ),
            Text('₺${price.toStringAsFixed(0)}+', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('$count sefer', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _SearchTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _SearchTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
