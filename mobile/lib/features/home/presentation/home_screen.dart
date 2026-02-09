import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../features/bookings/domain/booking_models.dart' hide Trip;
import '../../../core/widgets/location_autocomplete_field.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _passengers = 1;
  String _selectedType = 'people';

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

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

  void _applyPopularRoute(PopularRouteSummary route) {
    _fromController.text = route.from;
    _toController.text = route.to;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isCompactWidth = screenWidth <= 390;
    final horizontalPadding = isCompactWidth ? 14.0 : 20.0;
    final sectionBottomInset =
        kBottomNavigationBarHeight + mediaQuery.padding.bottom + 28;

    final user = ref.watch(currentUserProvider);
    final popularRoutesAsync = ref.watch(popularRoutesProvider);
    final recentBookingsAsync = ref.watch(recentBookingsProvider);
    final dateLabel = DateFormat('dd MMM', 'tr').format(_selectedDate);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer (Background)
          const Positioned.fill(
            child: MapView(),
          ),

          // 2. Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0.8),
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 3. Floating Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merhaba',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                    ),
                                  ).animate().fadeIn(),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.fullName ?? 'Yolcu',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                                ],
                              ),
                            ),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, color: Colors.white),
                            ).animate().scale(delay: 200.ms),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Search card
                        GlassContainer(
                          padding: EdgeInsets.all(isCompactWidth ? 16 : 20),
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
                              if (isCompactWidth)
                                Column(
                                  children: [
                                    _buildDateSelector(context, dateLabel),
                                    const SizedBox(height: 12),
                                    _buildPassengerSelector(),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateSelector(context, dateLabel),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPassengerSelector(),
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
                              const SizedBox(height: 20),
                              GradientButton(
                                text: 'Yolculuk Ara',
                                icon: Icons.search,
                                onPressed: _search,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                      ],
                    ),
                  ),
                ),

                // Popular routes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      12,
                    ),
                    child: Text(
                      'Popüler Güzergahlar',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ),
                ),
                SliverToBoxAdapter(
                  child: popularRoutesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: LinearProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Text('Rotalar yüklenemedi: $e', style: const TextStyle(color: AppColors.error)),
                      ),
                    ),
                    data: (routes) {
                      if (routes.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: const Text('Henüz popüler rota yok. İlk yolculukları sen başlat!', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 140,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          children: routes.map((route) {
                            return _RouteCard(
                              from: route.from,
                              to: route.to,
                              price: '₺${route.minPrice.toStringAsFixed(0)}',
                              subtitle: '${route.count} sefer',
                              onTap: () => _applyPopularRoute(route),
                            );
                          }).toList().animate(interval: 80.ms).fadeIn().slideX(begin: 0.2),
                        ),
                      );
                    },
                  ),
                ),

                // Recent trips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      28,
                      horizontalPadding,
                      12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Son Yolculuklarınız',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/reservations'),
                          child: const Text('Tümü', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: recentBookingsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(color: AppColors.primary),
                      ),
                      error: (e, _) => GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Text('Yolculuklar yüklenemedi: $e', style: const TextStyle(color: AppColors.error)),
                      ),
                      data: (bookings) {
                        if (bookings.isEmpty) {
                          return GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: const Text('Henüz yolculuğun yok. Arama yaparak başlayabilirsin.', style: TextStyle(color: AppColors.textSecondary)),
                          );
                        }

                        return Column(
                          children: [
                            for (final booking in bookings) ...[
                              _RecentBookingCard(booking: booking).animate().fadeIn().slideY(begin: 0.1),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: sectionBottomInset)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, String dateLabel) {
    return InkWell(
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
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(dateLabel, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerSelector() {
    return Container(
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
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
            onPressed: _passengers > 1 ? () => setState(() => _passengers--) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$_passengers',
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: _passengers < 8 ? () => setState(() => _passengers++) : null,
          ),
        ],
      ),
    );
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

class _RouteCard extends StatelessWidget {
  final String from;
  final String to;
  final String price;
  final String subtitle;
  final VoidCallback onTap;

  const _RouteCard({
    required this.from,
    required this.to,
    required this.price,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          border: Border.all(color: AppColors.glassStroke),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$from → $to', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RecentBookingCard extends StatelessWidget {
  final Booking booking;

  const _RecentBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.trip;
    final dateFormat = DateFormat('dd MMM yyyy', 'tr');
    final routeLabel = trip == null ? 'Yolculuk' : '${trip.origin} → ${trip.destination}';
    final dateLabel = trip == null ? dateFormat.format(booking.createdAt) : dateFormat.format(trip.departureTime);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routeLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(dateLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Text('₺${booking.totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
