import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_density_web_mock.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/web/site_footer.dart';
import '../../../core/widgets/web/site_header.dart';
import '../../../features/bookings/domain/booking_models.dart' hide Trip;
import '../../../core/widgets/location_autocomplete_field.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _heroSlogan = 'Yol Acik, Yola Cik';

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
        const SnackBar(
            content: Text('Lutfen nereden ve nereye alanlarini doldurun.')),
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
        '/search-results?from=$encodedFrom&to=$encodedTo&date=$dateParam');
  }

  void _applyPopularRoute(PopularRouteSummary route) {
    _fromController.text = route.from;
    _toController.text = route.to;
    _search();
  }

  TextStyle _webHeadingStyle({
    double size = 22,
    FontWeight weight = FontWeight.w800,
    Color color = const Color(0xFF1F3A30),
    double height = 1.2,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -0.2,
    );
  }

  TextStyle _webBodyStyle({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = const Color(0xFF4E665C),
    double height = 1.4,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  int _resolveWebGridCount(
    double maxWidth, {
    int maxColumns = 4,
    double minCardWidth = 260,
  }) {
    var count = (maxWidth / minCardWidth).floor();
    if (count < 1) {
      count = 1;
    }
    if (count > maxColumns) {
      count = maxColumns;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isWideWeb = kIsWeb;
    final isCompactWidth = screenWidth <= 390;
    final horizontalPadding = isCompactWidth ? 14.0 : 20.0;
    final sectionBottomInset =
        kBottomNavigationBarHeight + mediaQuery.padding.bottom + 28;
    final user = ref.watch(currentUserProvider);
    final popularRoutesAsync = ref.watch(popularRoutesProvider);
    final mapDensityAsync = ref.watch(homeMapDensityProvider);
    final recentBookingsAsync = isAuthenticated
        ? ref.watch(recentBookingsProvider)
        : const AsyncValue<List<Booking>>.data(<Booking>[]);
    final dateLabel = DateFormat('dd MMM', 'tr').format(_selectedDate);
    if (isWideWeb) {
      return _buildWebScaffold(
        context,
        isAuthenticated: isAuthenticated,
        popularRoutesAsync: popularRoutesAsync,
        recentBookingsAsync: recentBookingsAsync,
        mapDensityAsync: mapDensityAsync,
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.38,
                  0,
                  0,
                  0,
                  0,
                  0,
                  0.42,
                  0,
                  0,
                  0,
                  0,
                  0,
                  0.38,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: MapView(
                  markers: _buildDensityMarkers(mapDensityAsync),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.28,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF111A16),
                    BlendMode.multiply,
                  ),
                  child: Image.asset(
                    'assets/illustrations/web/hero_rideshare.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF07120E).withValues(alpha: 0.92),
                    const Color(0xFF0A1813).withValues(alpha: 0.82),
                    const Color(0xFF0E1E17).withValues(alpha: 0.76),
                    const Color(0xFF07120E).withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.24, 0.62, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
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
                                    isAuthenticated
                                        ? 'Merhaba'
                                        : 'Hos geldiniz',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4)
                                      ],
                                    ),
                                  ).animate().fadeIn(),
                                  const SizedBox(height: 6),
                                  Text(
                                    isAuthenticated
                                        ? (user?.fullName ?? 'Yolcu')
                                        : _heroSlogan,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.15,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4,
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                      .animate()
                                      .fadeIn(delay: 100.ms)
                                      .slideX(begin: -0.1),
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
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child:
                                  const Icon(Icons.person, color: Colors.white),
                            ).animate().scale(delay: 200.ms),
                          ],
                        ),
                        const SizedBox(height: 28),
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
                                      child: _buildDateSelector(
                                          context, dateLabel),
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
                                      label: 'Insan',
                                      icon: Icons.group,
                                      selected: _selectedType == 'people',
                                      onSelected: () => setState(
                                          () => _selectedType = 'people'),
                                    ),
                                    _SearchTypeChip(
                                      label: 'Hayvan',
                                      icon: Icons.pets,
                                      selected: _selectedType == 'pets',
                                      onSelected: () => setState(
                                          () => _selectedType = 'pets'),
                                    ),
                                    _SearchTypeChip(
                                      label: 'Kargo',
                                      icon: Icons.inventory_2,
                                      selected: _selectedType == 'cargo',
                                      onSelected: () => setState(
                                          () => _selectedType = 'cargo'),
                                    ),
                                    _SearchTypeChip(
                                      label: 'Gida',
                                      icon: Icons.restaurant,
                                      selected: _selectedType == 'food',
                                      onSelected: () => setState(
                                          () => _selectedType = 'food'),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      12,
                    ),
                    child: Text(
                      'Populer Guzergahlar',
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: LinearProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Populer rotalar su an yuklenemiyor.',
                              style: TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(popularRoutesProvider),
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (routes) {
                      if (routes.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                                'Henuz populer rota yok. Ilk yolculuklari sen baslat!',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 140,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          children: routes
                              .map((route) {
                                return _RouteCard(
                                  from: route.from,
                                  to: route.to,
                                  price:
                                      'TL ${route.minPrice.toStringAsFixed(0)}',
                                  subtitle: '${route.count} sefer',
                                  onTap: () => _applyPopularRoute(route),
                                );
                              })
                              .toList()
                              .animate(interval: 80.ms)
                              .fadeIn()
                              .slideX(begin: 0.2),
                        ),
                      );
                    },
                  ),
                ),
                if (isAuthenticated) ...[
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
                            'Son Yolculuklarin',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8)
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/reservations'),
                            child: const Text('Tumu',
                                style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ).animate().fadeIn(delay: 600.ms),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverToBoxAdapter(
                      child: recentBookingsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child:
                              LinearProgressIndicator(color: AppColors.primary),
                        ),
                        error: (e, _) => GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yolculuklar su an yuklenemiyor.',
                                style: TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(recentBookingsProvider),
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                        data: (bookings) {
                          if (bookings.isEmpty) {
                            return GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                  'Henuz yolculugun yok. Arama yaparak baslayabilirsin.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            );
                          }
                          return Column(
                            children: [
                              for (final booking in bookings) ...[
                                _RecentBookingCard(booking: booking)
                                    .animate()
                                    .fadeIn()
                                    .slideY(begin: 0.1),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 28, horizontalPadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hesap olusturmadan kesfet',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Misafir olarak yolculuklari arayabilir ve detaylarini gorebilirsin. Rezervasyon icin giris yapman istenir.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: sectionBottomInset)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    String dateLabel, {
    bool forLightSurface = false,
  }) {
    final backgroundColor =
        forLightSurface ? AppColors.neutralInput : AppColors.glassBgDark;
    final borderColor =
        forLightSurface ? AppColors.neutralBorder : AppColors.glassStroke;
    final iconColor =
        forLightSurface ? const Color(0xFF6A7F74) : AppColors.textSecondary;
    final textColor =
        forLightSurface ? const Color(0xFF1F3A30) : AppColors.textPrimary;

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
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerSelector({bool forLightSurface = false}) {
    final backgroundColor =
        forLightSurface ? AppColors.neutralInput : AppColors.glassBgDark;
    final borderColor =
        forLightSurface ? AppColors.neutralBorder : AppColors.glassStroke;
    final textColor =
        forLightSurface ? const Color(0xFF1F3A30) : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.primary),
            onPressed:
                _passengers > 1 ? () => setState(() => _passengers--) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$_passengers',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon:
                const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed:
                _passengers < 8 ? () => setState(() => _passengers++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWebScaffold(
    BuildContext context, {
    required bool isAuthenticated,
    required AsyncValue<List<PopularRouteSummary>> popularRoutesAsync,
    required AsyncValue<List<Booking>> recentBookingsAsync,
    required AsyncValue<List<MapDensityPoint>> mapDensityAsync,
  }) {
    final dateLabel = DateFormat('dd MMM yyyy', 'tr').format(_selectedDate);
    final viewportWidth = MediaQuery.of(context).size.width;
    final stackHero = viewportWidth < 1060;
    final pageHorizontalPadding = viewportWidth < 900 ? 18.0 : 28.0;
    final pageVerticalPadding = viewportWidth < 900 ? 18.0 : 24.0;
    final sectionGap = viewportWidth < 900 ? 22.0 : 26.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: pageHorizontalPadding,
            vertical: pageVerticalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebTopBar(context, isAuthenticated: isAuthenticated),
                  SizedBox(height: sectionGap),
                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF325E50)),
                      image: const DecorationImage(
                        image: AssetImage(
                          'assets/illustrations/web/hero_rideshare.png',
                        ),
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D3A2F).withValues(alpha: 0.2),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF0B1712)
                                      .withValues(alpha: 0.86),
                                  const Color(0xFF122A21)
                                      .withValues(alpha: 0.8),
                                  const Color(0xFF1A3A2F)
                                      .withValues(alpha: 0.74),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: stackHero
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nereye gitmek istiyorsun?',
                                      style: _webHeadingStyle(
                                        size: 38,
                                        color: Colors.white,
                                        height: 1.12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ayni yone giden insanlarla paylasimli yolculuk bul, surucu profillerini incele ve rezervasyonunu guvenli adimlarla tamamla.',
                                      style: _webBodyStyle(
                                        size: 16,
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        weight: FontWeight.w500,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _heroSlogan,
                                      style: _webBodyStyle(
                                        size: 13,
                                        color: const Color(0xFFD2E4DB),
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildWebSearchPanel(
                                      context,
                                      dateLabel,
                                      isAuthenticated: isAuthenticated,
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                          top: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Nereye gitmek istiyorsun?',
                                              style: _webHeadingStyle(
                                                size: 50,
                                                color: Colors.white,
                                                height: 1.08,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              'Insan odakli paylasimli yolculuk akisiyla rotani sec, surucuyu tani ve rezervasyonunu net adimlarla yonet.',
                                              style: _webBodyStyle(
                                                size: 17,
                                                color: Colors.white
                                                    .withValues(alpha: 0.9),
                                                weight: FontWeight.w500,
                                                height: 1.45,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              _heroSlogan,
                                              style: _webBodyStyle(
                                                size: 14,
                                                color: const Color(0xFFD2E4DB),
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 520,
                                              ),
                                              child: _buildWebSearchPanel(
                                                context,
                                                dateLabel,
                                                isAuthenticated:
                                                    isAuthenticated,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 420,
                                          ),
                                          child: _buildWebIllustrationCard(
                                            assetPath:
                                                'assets/illustrations/web/hero_whatsapp_car_clean_fixed.png',
                                            maxHeight: 380,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(
                    child: _buildWebMapSection(mapDensityAsync),
                  ),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWebSectionHeader(
                          title: 'Populer Guzergahlar',
                          subtitle:
                              'Kullanici davranislarindan olusan populer rotalari burada topluyoruz. Tek tikla secip aramayi saniyeler icinde baslatabilirsin.',
                        ),
                        const SizedBox(height: 14),
                        popularRoutesAsync.when(
                          loading: () => const LinearProgressIndicator(
                            color: Color(0xFF2F6B57),
                          ),
                          error: (e, _) => Text(
                            'Populer rotalar su an yuklenemiyor.',
                            style: _webBodyStyle(
                              color: AppColors.error,
                              weight: FontWeight.w600,
                            ),
                          ),
                          data: (routes) {
                            if (routes.isEmpty) {
                              return Text(
                                'Henuz rota verisi yok.',
                                style: _webBodyStyle(),
                              );
                            }
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final gridCount = _resolveWebGridCount(
                                  constraints.maxWidth,
                                  maxColumns: 4,
                                  minCardWidth: 255,
                                );
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: routes.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.9,
                                  ),
                                  itemBuilder: (context, index) {
                                    final route = routes[index];
                                    return InkWell(
                                      onTap: () => _applyPopularRoute(route),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFD4DED8),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${route.from} -> ${route.to}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _webBodyStyle(
                                                size: 15,
                                                color: const Color(0xFF1F3A30),
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${route.count} sefer',
                                              style: _webBodyStyle(
                                                size: 12,
                                                color: const Color(0xFF4E665C),
                                                weight: FontWeight.w500,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'Baslayan fiyat: TL ${route.minPrice.toStringAsFixed(0)}',
                                              style: _webBodyStyle(
                                                size: 14,
                                                color: const Color(0xFF2F6B57),
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        if (!isAuthenticated) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFD4DED8)),
                            ),
                            child: const Text(
                              'Misafir modunda rota ve ilan detaylarini rahatca inceleyebilirsin. Rezervasyon, mesajlasma ve yolculuk takibi adimlarinda guvenlik sebebiyle giris veya kayit istenir.',
                              style: TextStyle(
                                color: Color(0xFF425E52),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  if (isAuthenticated) ...[
                    _buildWebSectionShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Son Yolculuklarin',
                            style: _webHeadingStyle(),
                          ),
                          const SizedBox(height: 12),
                          recentBookingsAsync.when(
                            loading: () => const LinearProgressIndicator(
                              color: Color(0xFF2F6B57),
                            ),
                            error: (e, _) => Text(
                              'Yolculuklar su an yuklenemiyor.',
                              style: _webBodyStyle(
                                color: AppColors.error,
                                weight: FontWeight.w600,
                              ),
                            ),
                            data: (bookings) {
                              if (bookings.isEmpty) {
                                return Text(
                                  'Henuz rezervasyonun yok.',
                                  style: _webBodyStyle(),
                                );
                              }
                              return Column(
                                children: [
                                  for (final booking in bookings)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFD4DED8),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.directions_car,
                                              color: Color(0xFF2F6B57),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                booking.trip == null
                                                    ? 'Yolculuk'
                                                    : '${booking.trip!.origin} -> ${booking.trip!.destination}',
                                                style: _webBodyStyle(
                                                  size: 14,
                                                  color:
                                                      const Color(0xFF1F3A30),
                                                  weight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'TL ${booking.totalPrice.toStringAsFixed(0)}',
                                              style: _webBodyStyle(
                                                size: 14,
                                                color: const Color(0xFF2F6B57),
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: sectionGap),
                  ],
                  _buildWebSectionShell(child: _buildWebValueCardsSection()),
                  SizedBox(height: sectionGap),
                  _buildWebShareCostCtaSection(
                    context,
                    isAuthenticated: isAuthenticated,
                  ),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(child: _buildWebSafetySection()),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(child: _buildWebFaqSection()),
                  SizedBox(height: sectionGap),
                  _buildWebFooter(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebTopBar(BuildContext context,
      {required bool isAuthenticated}) {
    final createTripNext = Uri.encodeComponent('/create-trip');
    final messagesNext = Uri.encodeComponent('/messages');
    return WebSiteHeader(
      isAuthenticated: isAuthenticated,
      primaryNavLabel: 'Yolculuk Ara',
      onBrandTap: () => context.go('/'),
      onPrimaryNavTap: () => context.go('/search'),
      onCreateTripTap: () {
        if (isAuthenticated) {
          context.push('/create-trip');
        } else {
          context.push('/login?next=$createTripNext');
        }
      },
      onMessagesTap: () {
        if (isAuthenticated) {
          context.go('/messages');
        } else {
          context.push('/login?next=$messagesNext');
        }
      },
      onReservationsTap: () => context.go('/reservations'),
      onProfileTap: () => context.go('/profile'),
      onLoginTap: () => context.push('/login'),
      onRegisterTap: () => context.push('/register'),
    );
  }

  Widget _buildWebSearchPanel(
    BuildContext context,
    String dateLabel, {
    required bool isAuthenticated,
  }) {
    final createTripNext = Uri.encodeComponent('/create-trip');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E1DA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWebField(
            controller: _fromController,
            icon: Icons.radio_button_checked,
            label: 'Nereden',
          ),
          const SizedBox(height: 10),
          _buildWebField(
            controller: _toController,
            icon: Icons.location_on,
            label: 'Nereye',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  context,
                  dateLabel,
                  forLightSurface: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPassengerSelector(forLightSurface: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 420;
              final searchButton = FilledButton.icon(
                onPressed: _search,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6B57),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.search),
                label: Text(
                  'Yolculuk Ara',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              );
              final createButton = OutlinedButton.icon(
                onPressed: () {
                  if (isAuthenticated) {
                    context.push('/create-trip');
                  } else {
                    context.push('/login?next=$createTripNext');
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2F6B57)),
                  foregroundColor: const Color(0xFF2F6B57),
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.add_road),
                label: Text(
                  'Yolculuk Olustur',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              );

              if (stacked) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: searchButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: createButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchButton),
                  const SizedBox(width: 10),
                  Expanded(child: createButton),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Rezervasyon adiminda giris yapmaniz istenir.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A7F74),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(
        color: const Color(0xFF1F3A30),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: const Color(0xFF6A7F74),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF2F6B57)),
        filled: true,
        fillColor: AppColors.neutralInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4DED8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4DED8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2F6B57), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildWebIllustrationCard({
    required String assetPath,
    double aspectRatio = 1.5,
    double? height,
    double? maxHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        final derivedHeight = availableWidth / aspectRatio;
        var resolvedHeight = height ?? derivedHeight;
        if (maxHeight != null && resolvedHeight > maxHeight) {
          resolvedHeight = maxHeight;
        }
        if (resolvedHeight < 120) {
          resolvedHeight = 120;
        }

        return SizedBox(
          width: double.infinity,
          height: resolvedHeight,
          child: assetPath.toLowerCase().endsWith('.svg')
              ? SvgPicture.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                )
              : Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
        );
      },
    );
  }

  Widget _buildWebShareActionVisual({
    double maxHeight = 210,
  }) {
    return SizedBox(
      width: double.infinity,
      height: maxHeight,
      child: Center(
        child: Container(
          width: maxHeight * 0.88,
          height: maxHeight * 0.88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFFE7F2EC), Color(0xFFD6E8DE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFC0D5C9)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 26,
                top: 30,
                child: _buildShareAvatar(Icons.person_outline),
              ),
              Positioned(
                right: 26,
                bottom: 28,
                child: _buildShareAvatar(Icons.person_outline),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2F6B57).withValues(alpha: 0.12),
                  border:
                      Border.all(color: const Color(0xFF2F6B57), width: 1.1),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  size: 44,
                  color: Color(0xFF2F6B57),
                ),
              ),
              Positioned(
                left: 68,
                top: 76,
                child: Transform.rotate(
                  angle: -0.55,
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF2F6B57),
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                right: 66,
                bottom: 74,
                child: Transform.rotate(
                  angle: 2.6,
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF2F6B57),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareAvatar(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBDD2C7)),
      ),
      child: Icon(icon, color: const Color(0xFF2F6B57), size: 24),
    );
  }

  List<Marker> _buildDensityMarkers(AsyncValue<List<MapDensityPoint>> density) {
    final points = density.asData?.value ?? const <MapDensityPoint>[];
    if (points.isEmpty) return const [];

    final maxIntensity = points
        .map((point) => point.intensity)
        .fold<double>(0, (prev, val) => val > prev ? val : prev);
    final safeMax = maxIntensity <= 0 ? 1.0 : maxIntensity;

    return points.map((point) {
      final ratio = (point.intensity / safeMax).clamp(0.18, 1.0);
      final size = 16 + (ratio * 34);
      final glowAlpha = 0.14 + (ratio * 0.22);
      final strokeAlpha = 0.12 + (ratio * 0.28);
      final innerSize = size * 0.35;

      return Marker(
        width: size,
        height: size,
        point: LatLng(point.lat, point.lng),
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: glowAlpha),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: strokeAlpha),
                width: 1.1,
              ),
            ),
            child: Center(
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildWebDensityMarkers(
      AsyncValue<List<MapDensityPoint>> densityAsync) {
    final realPoints = densityAsync.asData?.value ?? const <MapDensityPoint>[];
    final points = buildWebDensityPoints(realPoints);
    if (points.isEmpty) return const [];

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (prev, val) => val > prev ? val : prev);
    final safeMax = maxCount <= 0 ? 1 : maxCount;

    return points.map((point) {
      final ratio = (point.count / safeMax).clamp(0.2, 1.0).toDouble();
      final dotSize = 8 + (ratio * 14);
      final ringSize = dotSize + 4 + (ratio * 6);
      final showLabel = point.count >= 72;
      final markerWidth = showLabel ? dotSize + 56 : ringSize;
      final markerHeight = ringSize;

      return Marker(
        width: markerWidth,
        height: markerHeight,
        point: LatLng(point.lat, point.lng),
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: ringSize,
                      height: ringSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF17372D)
                            .withValues(alpha: 0.12 + (ratio * 0.14)),
                      ),
                    ),
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3D9A7B)
                            .withValues(alpha: 0.46 + (ratio * 0.36)),
                        border: Border.all(
                          color: const Color(0xFFE8F4EE)
                              .withValues(alpha: 0.24 + (ratio * 0.24)),
                          width: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17352B)
                          .withValues(alpha: 0.62 + (ratio * 0.18)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      '+${point.count.clamp(1, 99)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  String _densityHeadline(AsyncValue<List<MapDensityPoint>> densityAsync) {
    final realPoints = densityAsync.asData?.value ?? const <MapDensityPoint>[];
    final points = buildWebDensityPoints(realPoints);
    if (points.isEmpty) return 'Canli ilan dagilimi hazirlaniyor';
    final totalCount = points.fold<int>(0, (sum, point) => sum + point.count);
    final peak = points.first.count;
    return 'Dagilim: ${points.length} sehir, toplam +$totalCount yolculuk, zirve +$peak';
  }

  Widget _buildWebSectionShell({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D3A2F).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildWebSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: _webHeadingStyle(),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            subtitle,
            style: _webBodyStyle(),
          ),
        ),
      ],
    );
  }

  Widget _buildWebMapSection(AsyncValue<List<MapDensityPoint>> densityAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Harita gorunumu',
          subtitle:
              'Arama oncesinde guzergahlari harita uzerinde inceleyebilir, bolgesel hareketliligi hizlica gorebilirsin.',
        ),
        const SizedBox(height: 8),
        Text(
          _densityHeadline(densityAsync),
          style: _webBodyStyle(
            size: 13,
            color: const Color(0xFF2F6B57),
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 320,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.8,
                      0,
                      0,
                      0,
                      0,
                      0,
                      0.84,
                      0,
                      0,
                      0,
                      0,
                      0,
                      0.8,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: MapView(
                      markers: _buildWebDensityMarkers(densityAsync),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0F2019).withValues(alpha: 0.03),
                            const Color(0xFF11241C).withValues(alpha: 0.05),
                            const Color(0xFF0F2019).withValues(alpha: 0.07),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebValueCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Neden bu platform?',
          subtitle:
              'Yoliva sadece arama ekrani sunmaz; yolculuk planlama, guvenli eslestirme ve iletisim sureclerini tek akista yonetmeni saglar.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final gridCount = _resolveWebGridCount(
              constraints.maxWidth,
              maxColumns: 4,
              minCardWidth: 255,
            );
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: gridCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.02,
              children: const [
                _WebInfoCard(
                  icon: Icons.route_outlined,
                  title: 'Yolculuk Paylas',
                  description:
                      'Ayni yone giden yolculari bir araya getirir; bos koltuklar degerlendirilirken yolculuk planin daha verimli hale gelir.',
                ),
                _WebInfoCard(
                  icon: Icons.savings_outlined,
                  title: 'Masrafi Azalt',
                  description:
                      'Rota maliyetini tek basina ustlenmek yerine paylasimli modelle dengeleyerek yakit ve yol masraflarini azaltmana yardimci olur.',
                ),
                _WebInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Dogrulanmis Profiller',
                  description:
                      'Profil ve belge adimlari ile hem surucu hem yolcu tarafinda daha guvenilir bir topluluk deneyimi olusturmayi hedefler.',
                ),
                _WebInfoCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Anlik Iletisim',
                  description:
                      'Rezervasyon sonrasinda uygulama ici mesajlasma ile bulusma noktasi, saat degisikligi ve yolculuk detaylari hizla netlesir.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebShareCostCtaSection(
    BuildContext context, {
    required bool isAuthenticated,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF3EE), Color(0xFFDCEBE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC8D8CF)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yolculugunu paylas, masrafini azalt',
                      style: _webHeadingStyle(size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Suruculer bos koltuklarini acarak yol maliyetini paylasabilir, yolcular ise guvenli bir akista uygun yolculugu bulup rezervasyon talebi olusturabilir.',
                      style: _webBodyStyle(),
                    ),
                    const SizedBox(height: 12),
                    _buildWebShareActionVisual(maxHeight: 220),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _buildWebCtaButtons(
                        context,
                        isAuthenticated: isAuthenticated,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yolculugunu paylas, masrafini azalt',
                            style: _webHeadingStyle(size: 28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Suruculer bos koltuklarini acarak yol maliyetini paylasabilir, yolcular ise guvenli bir akista uygun yolculugu bulup rezervasyon talebi olusturabilir.',
                            style: _webBodyStyle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 250,
                      child: _buildWebShareActionVisual(maxHeight: 190),
                    ),
                    const SizedBox(width: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _buildWebCtaButtons(
                        context,
                        isAuthenticated: isAuthenticated,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildWebCtaButtons(
    BuildContext context, {
    required bool isAuthenticated,
  }) {
    return [
      FilledButton.icon(
        onPressed: () {
          if (isAuthenticated) {
            context.push('/create-trip');
          } else {
            context.push('/register');
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2F6B57),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
        ),
        icon: Icon(
          isAuthenticated ? Icons.add_road : Icons.person_add_alt_1,
        ),
        label: Text(
          isAuthenticated ? 'Yolculuk Paylas' : 'Uye Ol ve Basla',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      if (!isAuthenticated)
        OutlinedButton(
          onPressed: () => context.push('/login'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            side: const BorderSide(color: Color(0xFF2F6B57)),
            foregroundColor: const Color(0xFF2F6B57),
          ),
          child: Text(
            'Giris Yap',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
        ),
    ];
  }

  Widget _buildWebSafetySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Guvenlik ve risk onleme',
          subtitle:
              'Yolculuk surecinde olusabilecek riskleri azaltmak icin profil dogrulama, rezervasyon kontrolu ve destek akislari birlikte calisir.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebIllustrationCard(
                    assetPath: 'assets/illustrations/web/safety_trust.svg',
                    maxHeight: 220,
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profil dogrulama, check-in ve destek akislarini tek yerde yonetiyoruz.',
                        style: _webBodyStyle(
                          size: 15,
                          weight: FontWeight.w600,
                          color: const Color(0xFF355A4C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildWebIllustrationCard(
                        assetPath: 'assets/illustrations/web/safety_trust.svg',
                        maxHeight: 190,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final gridCount = _resolveWebGridCount(
              constraints.maxWidth,
              maxColumns: 4,
              minCardWidth: 255,
            );
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: gridCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: const [
                _WebSafetyCard(
                  icon: Icons.badge_outlined,
                  riskTitle: 'Sahte profil riski',
                  riskDetail:
                      'Eksik bilgiye sahip veya dogrulanmamis hesaplarla eslesme ihtimali yolculuk guvenini azaltabilir.',
                  measureTitle: 'Onlem',
                  measureDetail:
                      'Kimlik, ehliyet ve temel profil belge kontrolleriyle hesaplarin guven adimlari tamamlanir.',
                ),
                _WebSafetyCard(
                  icon: Icons.qr_code_2_outlined,
                  riskTitle: 'Yanlis eslesme riski',
                  riskDetail:
                      'Rezervasyon sahibi disinda birinin araca binmeye calismasi veya yolcunun yanlis eslesmesi sorun yaratabilir.',
                  measureTitle: 'Onlem',
                  measureDetail:
                      'QR ve PNR tabanli check-in adimlariyla yolcu ve rezervasyon kaydi dogrulanir.',
                ),
                _WebSafetyCard(
                  icon: Icons.place_outlined,
                  riskTitle: 'Belirsiz bulusma riski',
                  riskDetail:
                      'Bulusma noktasinin net olmamasi gecikmeye, iptale veya yanlis konumda beklemeye neden olabilir.',
                  measureTitle: 'Onlem',
                  measureDetail:
                      'Rota, saat, bulusma notlari ve uygulama ici mesajlasma ile yolculuk oncesi net koordinasyon saglanir.',
                ),
                _WebSafetyCard(
                  icon: Icons.report_problem_outlined,
                  riskTitle: 'Acil durum riski',
                  riskDetail:
                      'Yolculuk sirasinda beklenmedik bir durumda hizli destek ve dogru yonlendirme ihtiyaci dogabilir.',
                  measureTitle: 'Onlem',
                  measureDetail:
                      'Yardim merkezi, bildirim akislari ve hesap guvenligi adimlariyla hizli aksiyon alinmasi desteklenir.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebFaqSection() {
    const faqItems = <(String, String)>[
      (
        'Giris yapmadan neler yapabilirim?',
        'Misafir olarak rota, tarih ve fiyat odakli arama yapabilir; ilan detaylarini, koltuk durumunu ve surucu bilgilerini inceleyebilirsiniz. Rezervasyon adimina kadar tum kesif sureci acik kalir.'
      ),
      (
        'Neden rezervasyon asamasinda giris gerekiyor?',
        'Rezervasyon islemi kisiye ozeldir ve dogrudan hesapla iliskilendirilir. Bu sayede mesajlasma, check-in, iptal/iade ve yolculuk takibi gibi adimlar guvenli sekilde yonetilir.'
      ),
      (
        'Rezervasyon kesinlesmesi nasil oluyor?',
        'Yolcu talep olusturduktan sonra surucu uygunluk durumuna gore onay verir. Onay sonrasinda rezervasyon kesinlesir ve her iki tarafin ekraninda yolculuk plani detayli olarak gorunur.'
      ),
      (
        'Yolculuk gunu dogrulama nasil yapiliyor?',
        'Yolculuk gununde sistem QR veya PNR tabanli check-in adimlarini destekler. Bu akis, rezervasyon sahibinin dogrulanmasini kolaylastirir ve yanlis eslesme riskini azaltir.'
      ),
      (
        'Guvenlik sorunu yasarsam ne yapmaliyim?',
        'Yardim ve destek bolumunden aninda bildirim olusturabilir, gerekirse hesap guvenligi adimlarini hizla aktif ederek sureci kayit altina alabilirsiniz. Ekiplerimiz olay tipine gore yonlendirme saglar.'
      ),
      (
        'Surucu olarak yolculuk paylasmak icin ne gerekli?',
        'Surucu olarak baslamak icin hesap olusturup profil bilgilerinizi ve gerekli belge adimlarini tamamlamaniz gerekir. Ardindan tarih, rota, koltuk ve tercih detaylariyla ilan acabilirsiniz.'
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Sikca sorulan sorular',
          subtitle:
              'Platformu ilk kez kullananlarin en cok sordugu sorulari burada topladik.',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4DED8)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (int i = 0; i < faqItems.length; i++) ...[
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    iconColor: const Color(0xFF2F6B57),
                    collapsedIconColor: const Color(0xFF2F6B57),
                    title: Text(
                      faqItems[i].$1,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF1F3A30),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faqItems[i].$2,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4E665C),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i != faqItems.length - 1)
                    const Divider(height: 1, color: Color(0xFFE2EAE6)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final reservationsNext = Uri.encodeComponent('/reservations');

    return WebSiteFooter(
      sections: [
        WebFooterSectionData(
          title: 'Urun',
          links: [
            WebFooterLinkData(
              label: 'Yolculuk Ara',
              onTap: () => context.go('/search'),
            ),
            WebFooterLinkData(
              label: 'Rezervasyonlar',
              onTap: () {
                if (isAuthenticated) {
                  context.go('/reservations');
                } else {
                  context.push('/login?next=$reservationsNext');
                }
              },
            ),
            WebFooterLinkData(
              label: 'Yolculuk Olustur',
              onTap: () {
                if (isAuthenticated) {
                  context.push('/create-trip');
                } else {
                  context.push('/register');
                }
              },
            ),
          ],
        ),
        WebFooterSectionData(
          title: 'Destek',
          links: [
            WebFooterLinkData(
              label: 'Yardim Merkezi',
              onTap: () => context.push('/help'),
            ),
            WebFooterLinkData(
              label: 'Guvenlik',
              onTap: () => context.push('/security'),
            ),
            WebFooterLinkData(
              label: 'SSS',
              onTap: () => context.push('/help'),
            ),
          ],
        ),
        WebFooterSectionData(
          title: 'Kurumsal',
          links: [
            WebFooterLinkData(
              label: 'Hakkimizda',
              onTap: () => context.push('/about'),
            ),
            WebFooterLinkData(
              label: 'Iletisim',
              onTap: () => context.push('/help'),
            ),
          ],
        ),
      ],
      description:
          'Yoliva, ayni yone giden insanlari guvenli sekilde bulusturup yolculuk maliyetlerini dengelemeyi hedefler.',
      copyright:
          '(c) 2026 Yoliva. Tum haklari saklidir. Platform ozellikleri ulke ve bolgeye gore degisebilir.',
      onPrivacyTap: () => context.push('/help'),
      onTermsTap: () => context.push('/help'),
      onCookieTap: () => context.push('/help'),
    );
  }
}

class _WebInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _WebInfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B57).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2F6B57)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: const Color(0xFF1F3A30),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                color: const Color(0xFF4E665C),
                height: 1.45,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSafetyCard extends StatelessWidget {
  final IconData icon;
  final String riskTitle;
  final String riskDetail;
  final String measureTitle;
  final String measureDetail;
  const _WebSafetyCard({
    required this.icon,
    required this.riskTitle,
    required this.riskDetail,
    required this.measureTitle,
    required this.measureDetail,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2F6B57)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  riskTitle,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF1F3A30),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riskDetail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4E665C),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: const Color(0xFF2C4D40),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '$measureTitle: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: measureDetail),
                      ],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
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
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        ),
        label: Text(
          label,
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        ),
        side: BorderSide(color: AppColors.glassStroke),
        selectedColor: AppColors.primary.withValues(alpha: 0.22),
        backgroundColor: AppColors.glassBgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            Text('$from -> $to',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(price,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
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
    final routeLabel =
        trip == null ? 'Yolculuk' : '${trip.origin} -> ${trip.destination}';
    final dateLabel = trip == null
        ? dateFormat.format(booking.createdAt)
        : dateFormat.format(trip.departureTime);
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
                Text(routeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(dateLabel,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Text('TL ${booking.totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
