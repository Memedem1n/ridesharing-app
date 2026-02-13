import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
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
        const SnackBar(
          content: Text('Lutfen nereden ve nereye alanlarini doldurun.'),
        ),
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
    context.push(
      '/search-results?from=$encodedFrom&to=$encodedTo&date=$dateParam',
    );
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

    if (kIsWeb) {
      return _buildWeb(context, dateLabel, popularRoutesAsync);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuk Ara')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSearchForm(dateLabel, forWeb: false)
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2),
              const SizedBox(height: 28),
              _buildPopularRoutes(popularRoutesAsync, forWeb: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeb(
    BuildContext context,
    String dateLabel,
    AsyncValue<List<PopularRouteSummary>> popularRoutesAsync,
  ) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Yolculuk Ara',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F3A30),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/search-results'),
                        icon: const Icon(Icons.list_alt_outlined),
                        label: const Text('Sonuclar'),
                      ),
                      const SizedBox(width: 8),
                      if (isAuthenticated)
                        OutlinedButton.icon(
                          onPressed: () => context.go('/profile'),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Profil'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () => context.go('/login?next=/search'),
                          icon: const Icon(Icons.login),
                          label: const Text('Giris Yap'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildSearchForm(dateLabel, forWeb: true),
                        const SizedBox(height: 16),
                        _buildPopularRoutes(popularRoutesAsync, forWeb: true),
                      ],
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

  Widget _buildSearchForm(String dateLabel, {required bool forWeb}) {
    final fieldBg =
        forWeb ? AppColors.neutralInput : AppColors.glassBgDark;
    final fieldBorder =
        forWeb ? AppColors.neutralBorder : AppColors.glassStroke;
    final fieldTextColor =
        forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary;
    final fieldHintColor =
        forWeb ? const Color(0xFF5A7066) : AppColors.textSecondary;

    final container = Column(
      children: [
        LocationAutocompleteField(
          controller: _fromController,
          hintText: 'Nereden?',
          icon: Icons.circle_outlined,
          iconColor: AppColors.primary,
          forLightSurface: forWeb,
        ),
        Divider(color: fieldBorder),
        LocationAutocompleteField(
          controller: _toController,
          hintText: 'Nereye?',
          icon: Icons.location_on,
          iconColor: AppColors.accent,
          forLightSurface: forWeb,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: fieldHintColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          color: fieldTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fieldBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.primary,
                      ),
                      onPressed: _passengers > 1
                          ? () => setState(() => _passengers--)
                          : null,
                    ),
                    Text(
                      '$_passengers',
                      style: TextStyle(
                        color: fieldTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                      onPressed: _passengers < 8
                          ? () => setState(() => _passengers++)
                          : null,
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
                label: 'Insan',
                icon: Icons.group,
                selected: _selectedType == 'people',
                forWeb: forWeb,
                onSelected: () => setState(() => _selectedType = 'people'),
              ),
              _SearchTypeChip(
                label: 'Hayvan',
                icon: Icons.pets,
                selected: _selectedType == 'pets',
                forWeb: forWeb,
                onSelected: () => setState(() => _selectedType = 'pets'),
              ),
              _SearchTypeChip(
                label: 'Kargo',
                icon: Icons.inventory_2,
                selected: _selectedType == 'cargo',
                forWeb: forWeb,
                onSelected: () => setState(() => _selectedType = 'cargo'),
              ),
              _SearchTypeChip(
                label: 'Gida',
                icon: Icons.restaurant,
                selected: _selectedType == 'food',
                forWeb: forWeb,
                onSelected: () => setState(() => _selectedType = 'food'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Yolculuk Ara',
            icon: Icons.search,
            onPressed: _search,
          ),
        ),
      ],
    );

    if (forWeb) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: container,
      );
    }

    return GlassContainer(padding: const EdgeInsets.all(20), child: container);
  }

  Widget _buildPopularRoutes(
    AsyncValue<List<PopularRouteSummary>> popularRoutesAsync, {
    required bool forWeb,
  }) {
    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Populer Rotalar', style: titleStyle)
            .animate()
            .fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        popularRoutesAsync.when(
          loading: () =>
              const LinearProgressIndicator(color: AppColors.primary),
          error: (e, _) => Text(
            'Rotalar yuklenemedi: $e',
            style: const TextStyle(color: AppColors.error),
          ),
          data: (routes) {
            if (routes.isEmpty) {
              return Text(
                'Henuz populer rota yok.',
                style: TextStyle(
                  color: forWeb
                      ? const Color(0xFF4E665C)
                      : AppColors.textSecondary,
                ),
              );
            }

            return Column(
              children: [
                for (final route in routes.take(5)) ...[
                  _PopularRouteCard(
                    from: route.from,
                    to: route.to,
                    price: route.minPrice,
                    count: route.count,
                    forWeb: forWeb,
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
    );
  }
}

class _PopularRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final double price;
  final int count;
  final bool forWeb;
  final VoidCallback onTap;

  const _PopularRouteCard({
    required this.from,
    required this.to,
    required this.price,
    required this.count,
    required this.forWeb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$from -> $to',
            style: TextStyle(
              color: forWeb ? const Color(0xFF1F3A30) : AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          'TL ${price.toStringAsFixed(0)}+',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count sefer',
          style: TextStyle(
            color: forWeb ? const Color(0xFF5A7066) : AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );

    if (forWeb) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE6E1)),
          ),
          child: child,
        ),
      ).animate().fadeIn(delay: 300.ms);
    }

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _SearchTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool forWeb;
  final VoidCallback onSelected;

  const _SearchTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.forWeb,
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
        showCheckmark: false,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        backgroundColor:
            forWeb ? const Color(0xFFF3F7F4) : AppColors.glassBgDark,
        side: BorderSide(
          color: forWeb ? AppColors.neutralBorder : AppColors.glassStroke,
        ),
        labelStyle: TextStyle(
          color: selected
              ? const Color(0xFF1F4B3D)
              : (forWeb ? const Color(0xFF4E665C) : AppColors.textSecondary),
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
