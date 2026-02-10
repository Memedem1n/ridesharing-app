import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/brand_lockup.dart';
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
        const SnackBar(
            content: Text('Lütfen nereden ve nereye alanlarını doldurun.')),
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
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapView(),
          ),
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
                                        : 'Hoş geldiniz',
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
                                        : 'Aynı yöne, daha az masraf',
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
                                      label: 'İnsan',
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
                                      label: 'Gıda',
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
                              'Popüler rotalar şu an yüklenemiyor.',
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
                                'Henüz popüler rota yok. İlk yolculukları sen başlat!',
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
                            'Son Yolculukların',
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
                            child: const Text('Tümü',
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
                                'Yolculuklar şu an yüklenemiyor.',
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
                                  'Henüz yolculuğun yok. Arama yaparak başlayabilirsin.',
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
                              'Hesap oluşturmadan keşfet',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Misafir olarak yolculukları arayabilir ve detaylarını görebilirsin. Rezervasyon için giriş yapman istenir.',
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
  }) {
    final dateLabel = DateFormat('dd MMM yyyy', 'tr').format(_selectedDate);
    final viewportWidth = MediaQuery.of(context).size.width;
    final stackHero = viewportWidth < 1060;
    final pageHorizontalPadding = viewportWidth < 900 ? 16.0 : 24.0;
    final pageVerticalPadding = viewportWidth < 900 ? 16.0 : 20.0;
    final sectionGap = viewportWidth < 900 ? 18.0 : 22.0;
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
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWebTopBar(context, isAuthenticated: isAuthenticated),
                  SizedBox(height: sectionGap),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F6B57), Color(0xFF3F7F68)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3D7F67)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF1D3A2F).withValues(alpha: 0.24),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: stackHero
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nereye gitmek istiyorsun?',
                                style: _webHeadingStyle(
                                  size: 44,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Giriş yapmadan uygun yolculukları arayabilir, rota detaylarını inceleyebilir ve rezervasyon aşamasında hesabını açarak işlemini güvenle tamamlayabilirsin.',
                                style: _webBodyStyle(
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.87),
                                  weight: FontWeight.w500,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Güvenli. Ekonomik. Yoliva.',
                                style: _webBodyStyle(
                                  size: 13,
                                  color: const Color(0xFFD2E4DB),
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 22),
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
                                  padding:
                                      const EdgeInsets.only(right: 24, top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Nereye gitmek istiyorsun?',
                                        style: _webHeadingStyle(
                                          size: 52,
                                          color: Colors.white,
                                          height: 1.08,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Giriş yapmadan uygun rotaları arayabilir, sürücü ve yolculuk detaylarını inceleyebilir, rezervasyon adımında hesabını oluşturarak süreci güvenli şekilde tamamlayabilirsin.',
                                        style: _webBodyStyle(
                                          size: 17,
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          weight: FontWeight.w500,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Güvenli. Ekonomik. Yoliva.',
                                        style: _webBodyStyle(
                                          size: 14,
                                          color: const Color(0xFFD2E4DB),
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 470),
                                    child: _buildWebSearchPanel(
                                      context,
                                      dateLabel,
                                      isAuthenticated: isAuthenticated,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(child: _buildWebMapSection()),
                  SizedBox(height: sectionGap),
                  _buildWebSectionShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWebSectionHeader(
                          title: 'Popüler Güzergahlar',
                          subtitle:
                              'Kullanıcı davranışlarından oluşan popüler rotaları burada topluyoruz. Tek tıkla seçip aramayı saniyeler içinde başlatabilirsin.',
                        ),
                        const SizedBox(height: 14),
                        popularRoutesAsync.when(
                          loading: () => const LinearProgressIndicator(
                            color: Color(0xFF2F6B57),
                          ),
                          error: (e, _) => Text(
                            'Popüler rotalar şu an yüklenemiyor.',
                            style: _webBodyStyle(
                              color: AppColors.error,
                              weight: FontWeight.w600,
                            ),
                          ),
                          data: (routes) {
                            if (routes.isEmpty) {
                              return Text(
                                'Henüz rota verisi yok.',
                                style: _webBodyStyle(),
                              );
                            }
                            final shownRoutes = routes.take(8).toList();
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
                                  itemCount: shownRoutes.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.9,
                                  ),
                                  itemBuilder: (context, index) {
                                    final route = shownRoutes[index];
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
                                              'Başlayan fiyat: TL ${route.minPrice.toStringAsFixed(0)}',
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
                              'Misafir modunda rota ve ilan detaylarını rahatça inceleyebilirsin. Rezervasyon, mesajlaşma ve yolculuk takibi adımlarında güvenlik sebebiyle giriş veya kayıt istenir.',
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
                            'Son Yolculukların',
                            style: _webHeadingStyle(),
                          ),
                          const SizedBox(height: 12),
                          recentBookingsAsync.when(
                            loading: () => const LinearProgressIndicator(
                              color: Color(0xFF2F6B57),
                            ),
                            error: (e, _) => Text(
                              'Yolculuklar şu an yüklenemiyor.',
                              style: _webBodyStyle(
                                color: AppColors.error,
                                weight: FontWeight.w600,
                              ),
                            ),
                            data: (bookings) {
                              if (bookings.isEmpty) {
                                return Text(
                                  'Henüz rezervasyonun yok.',
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
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: const BrandLockup(
            iconSize: 28,
            textSize: 23,
            gap: 8,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/'),
          child: Text(
            'Yolculuk Ara',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            if (isAuthenticated) {
              context.push('/create-trip');
            } else {
              context.push('/login?next=$createTripNext');
            }
          },
          child: Text(
            'Yolculuk Oluştur',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        if (isAuthenticated) ...[
          TextButton(
            onPressed: () => context.go('/reservations'),
            child: Text(
              'Rezervasyonlar',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/profile'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B57),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              'Profil',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ] else ...[
          OutlinedButton(
            onPressed: () => context.push('/login'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: const BorderSide(color: Color(0xFF2F6B57)),
            ),
            child: Text(
              'Giriş Yap',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push('/register'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B57),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              'Kayıt Ol',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
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
                ),
                icon: const Icon(Icons.add_road),
                label: Text(
                  'Yolculuk Oluştur',
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

  Widget _buildWebSectionShell({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5E1DA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D3A2F).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

  Widget _buildWebMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Harita görünümü',
          subtitle:
              'Arama öncesinde güzergahları harita üzerinde inceleyebilir, bölgesel hareketliliği hızlıca görebilirsin.',
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 320,
            child: const MapView(),
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
              'Yoliva sadece arama ekranı sunmaz; yolculuk planlama, güvenli eşleştirme ve iletişim süreçlerini tek akışta yönetmeni sağlar.',
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
                  title: 'Yolculuk Paylaş',
                  description:
                      'Aynı yöne giden yolcuları bir araya getirir; boş koltuklar değerlendirilirken yolculuk planın daha verimli hale gelir.',
                ),
                _WebInfoCard(
                  icon: Icons.savings_outlined,
                  title: 'Masrafı Azalt',
                  description:
                      'Rota maliyetini tek basina ustlenmek yerine paylasimli modelle dengeleyerek yakit ve yol masraflarini azaltmana yardimci olur.',
                ),
                _WebInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Doğrulanmış Profiller',
                  description:
                      'Profil ve belge adımları ile hem sürücü hem yolcu tarafında daha güvenilir bir topluluk deneyimi oluşturmayı hedefler.',
                ),
                _WebInfoCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Anlık İletişim',
                  description:
                      'Rezervasyon sonrasında uygulama içi mesajlaşma ile buluşma noktası, saat değişikliği ve yolculuk detayları hızla netleşir.',
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
                      'Yolculuğunu paylaş, masrafını azalt',
                      style: _webHeadingStyle(size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sürücüler boş koltuklarını açarak yol maliyetini paylaşabilir, yolcular ise güvenli bir akışta uygun yolculuğu bulup rezervasyon talebi oluşturabilir.',
                      style: _webBodyStyle(),
                    ),
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
                            'Yolculuğunu paylaş, masrafını azalt',
                            style: _webHeadingStyle(size: 28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sürücüler boş koltuklarını açarak yol maliyetini paylaşabilir, yolcular ise güvenli bir akışta uygun yolculuğu bulup rezervasyon talebi oluşturabilir.',
                            style: _webBodyStyle(),
                          ),
                        ],
                      ),
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
          isAuthenticated ? 'Yolculuk Paylaş' : 'Üye Ol ve Başla',
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
            'Giriş Yap',
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
          title: 'Güvenlik ve risk önleme',
          subtitle:
              'Yolculuk sürecinde oluşabilecek riskleri azaltmak için profil doğrulama, rezervasyon kontrolü ve destek akışları birlikte çalışır.',
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
              childAspectRatio: 0.95,
              children: const [
                _WebSafetyCard(
                  icon: Icons.badge_outlined,
                  riskTitle: 'Sahte profil riski',
                  riskDetail:
                      'Eksik bilgiye sahip veya doğrulanmamış hesaplarla eşleşme ihtimali yolculuk güvenini azaltabilir.',
                  measureTitle: 'Önlem',
                  measureDetail:
                      'Kimlik, ehliyet ve temel profil belge kontrolleriyle hesapların güven adımları tamamlanır.',
                ),
                _WebSafetyCard(
                  icon: Icons.qr_code_2_outlined,
                  riskTitle: 'Yanlış eşleşme riski',
                  riskDetail:
                      'Rezervasyon sahibi disinda birinin araca binmeye calismasi veya yolcunun yanlis eslesmesi sorun yaratabilir.',
                  measureTitle: 'Önlem',
                  measureDetail:
                      'QR ve PNR tabanlı check-in adımlarıyla yolcu ve rezervasyon kaydı doğrulanır.',
                ),
                _WebSafetyCard(
                  icon: Icons.place_outlined,
                  riskTitle: 'Belirsiz buluşma riski',
                  riskDetail:
                      'Bulusma noktasinin net olmamasi gecikmeye, iptale veya yanlis konumda beklemeye neden olabilir.',
                  measureTitle: 'Önlem',
                  measureDetail:
                      'Rota, saat, buluşma notları ve uygulama içi mesajlaşma ile yolculuk öncesi net koordinasyon sağlanır.',
                ),
                _WebSafetyCard(
                  icon: Icons.report_problem_outlined,
                  riskTitle: 'Acil durum riski',
                  riskDetail:
                      'Yolculuk sırasında beklenmedik bir durumda hızlı destek ve doğru yönlendirme ihtiyacı doğabilir.',
                  measureTitle: 'Önlem',
                  measureDetail:
                      'Yardım merkezi, bildirim akışları ve hesap güvenliği adımlarıyla hızlı aksiyon alınması desteklenir.',
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
        'Giriş yapmadan neler yapabilirim?',
        'Misafir olarak rota, tarih ve fiyat odaklı arama yapabilir; ilan detaylarını, koltuk durumunu ve sürücü bilgilerini inceleyebilirsiniz. Rezervasyon adımına kadar tüm keşif süreci açık kalır.'
      ),
      (
        'Neden rezervasyon aşamasında giriş gerekiyor?',
        'Rezervasyon işlemi kişiye özeldir ve doğrudan hesapla ilişkilendirilir. Bu sayede mesajlaşma, check-in, iptal/iade ve yolculuk takibi gibi adımlar güvenli şekilde yönetilir.'
      ),
      (
        'Rezervasyon kesinlesmesi nasil oluyor?',
        'Yolcu talep oluşturduktan sonra sürücü uygunluk durumuna göre onay verir. Onay sonrasında rezervasyon kesinleşir ve her iki tarafın ekranında yolculuk planı detaylı olarak görünür.'
      ),
      (
        'Yolculuk günü doğrulama nasıl yapılıyor?',
        'Yolculuk gününde sistem QR veya PNR tabanlı check-in adımlarını destekler. Bu akış, rezervasyon sahibinin doğrulanmasını kolaylaştırır ve yanlış eşleşme riskini azaltır.'
      ),
      (
        'Güvenlik sorunu yaşarsam ne yapmalıyım?',
        'Yardım ve destek bölümünden anında bildirim oluşturabilir, gerekirse hesap güvenliği adımlarını hızla aktif ederek süreci kayıt altına alabilirsiniz. Ekiplerimiz olay tipine göre yönlendirme sağlar.'
      ),
      (
        'Sürücü olarak yolculuk paylaşmak için ne gerekli?',
        'Sürücü olarak başlamak için hesap oluşturup profil bilgilerinizi ve gerekli belge adımlarını tamamlamanız gerekir. Ardından tarih, rota, koltuk ve tercih detaylarıyla ilan açabilirsiniz.'
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWebSectionHeader(
          title: 'Sıkça sorulan sorular',
          subtitle:
              'Platformu ilk kez kullananların en çok sorduğu soruları burada topladık.',
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
    final brandBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLockup(
          iconSize: 26,
          textSize: 21,
          gap: 8,
          iconBackgroundColor: Color(0xFFEAF3EE),
          textColor: Color(0xFFEAF3EE),
        ),
        const SizedBox(height: 10),
        Text(
          'Yoliva, aynı yöne giden insanları güvenli bir şekilde buluşturarak yolculuk maliyetini azaltmayı ve şehirler arası planlamayı kolaylaştırmayı hedefler.',
          style: _webBodyStyle(
            size: 13,
            color: const Color(0xFFC2D6CA),
            weight: FontWeight.w500,
          ),
        ),
      ],
    );

    final footerColumns = [
      _WebFooterColumn(
        title: 'Ürün',
        links: [
          _WebFooterLinkData(
            label: 'Yolculuk Ara',
            onTap: () => context.go('/search'),
          ),
          _WebFooterLinkData(
            label: 'Rezervasyonlar',
            onTap: () {
              if (isAuthenticated) {
                context.go('/reservations');
              } else {
                context.push('/login?next=$reservationsNext');
              }
            },
          ),
          _WebFooterLinkData(
            label: 'Yolculuk Paylaş',
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
      _WebFooterColumn(
        title: 'Destek ve Güvenlik',
        links: [
          _WebFooterLinkData(
            label: 'Yardım Merkezi',
            onTap: () => context.push('/help'),
          ),
          _WebFooterLinkData(
            label: 'Güvenlik',
            onTap: () => context.push('/security'),
          ),
          _WebFooterLinkData(
            label: 'SSS',
            onTap: () => context.push('/help'),
          ),
        ],
      ),
      _WebFooterColumn(
        title: 'Kurumsal',
        links: [
          _WebFooterLinkData(
            label: 'Hakkımızda',
            onTap: () => context.push('/about'),
          ),
          _WebFooterLinkData(
            label: 'Ayarlar',
            onTap: () => context.push('/settings'),
          ),
          _WebFooterLinkData(
            label: 'İletişim',
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideFooter = constraints.maxWidth >= 980;
        final twoColumnWidth = (constraints.maxWidth - 12) / 2;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF163026),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF27473B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wideFooter)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: brandBlock),
                    const SizedBox(width: 24),
                    for (final column in footerColumns) ...[
                      Expanded(child: column),
                      if (column != footerColumns.last)
                        const SizedBox(width: 12),
                    ],
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brandBlock,
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: [
                        for (final column in footerColumns)
                          SizedBox(
                            width: twoColumnWidth < 240
                                ? constraints.maxWidth
                                : twoColumnWidth,
                            child: column,
                          ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF355A4C), height: 1),
              const SizedBox(height: 14),
              Text(
                '© 2026 Yoliva. Tüm hakları saklıdır. Platform özellikleri ülke ve bölgeye göre değişebilir.',
                style: _webBodyStyle(
                  size: 12,
                  color: const Color(0xFFA8C2B4),
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
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

class _WebFooterLinkData {
  final String label;
  final VoidCallback onTap;
  const _WebFooterLinkData({
    required this.label,
    required this.onTap,
  });
}

class _WebFooterColumn extends StatelessWidget {
  final String title;
  final List<_WebFooterLinkData> links;
  const _WebFooterColumn({
    required this.title,
    required this.links,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: link.onTap,
              child: Text(
                link.label,
                style: GoogleFonts.inter(
                  color: const Color(0xFFC2D6CA),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
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
