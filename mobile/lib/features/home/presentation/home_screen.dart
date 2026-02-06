import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/services/route_service.dart';

// State provider for active route
final activeRouteProvider = FutureProvider<RouteInfo?>((ref) async {
  // Mock route from Istanbul to Ankara for demo
  final service = RouteService();
  return await service.getRoute(
    const LatLng(41.0082, 28.9784), // Istanbul
    const LatLng(39.9208, 32.8541), // Ankara
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final routeAsync = ref.watch(activeRouteProvider);
    
    return Scaffold(
      extendBodyBehindAppBar: true, 
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer (Background)
          Positioned.fill(
            child: routeAsync.when(
              data: (routeInfo) => MapView(
                initialPosition: const LatLng(40.5, 30.5), // Center roughly between inst-ank
                polylines: routeInfo != null ? [
                  Polyline(
                    points: routeInfo.points,
                    strokeWidth: 4.0,
                    color: AppColors.primary,
                  ),
                ] : [],
                markers: [
                  // Mock cars
                  const Marker(
                    point: LatLng(41.01, 29.0),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.directions_car, color: AppColors.primary, size: 30),
                  ),
                   const Marker(
                    point: LatLng(40.99, 28.95),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.directions_car, color: AppColors.accent, size: 30),
                  ),
                ],
              ),
              loading: () => const MapView(), // Show empty map while loading
              error: (_, __) => const MapView(),
            ),
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
                    padding: const EdgeInsets.all(20),
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
                                    'Merhaba 👋',
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
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _LocationRow(
                                icon: Icons.circle_outlined,
                                iconColor: AppColors.primary,
                                hint: 'Nereden?',
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 11),
                                child: Container(
                                  width: 2,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.accent],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              _LocationRow(
                                icon: Icons.location_on,
                                iconColor: AppColors.accent,
                                hint: 'Nereye?',
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.glassBgDark,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.glassStroke),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                                          SizedBox(width: 8),
                                          Text('Bugün', style: TextStyle(color: AppColors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.glassBgDark,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.glassStroke),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.person, size: 18, color: AppColors.textSecondary),
                                          SizedBox(width: 8),
                                          Text('1 Yolcu', style: TextStyle(color: AppColors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              GradientButton(
                                text: 'Yolculuk Ara',
                                icon: Icons.search,
                                onPressed: () => context.go('/search'),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                      ],
                    ),
                  ),
                ),
                
                // Popular routes (showing real calculated data if available)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Popüler Güzergahlar',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        
                        if (routeAsync.asData?.value != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.success),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: AppColors.success, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${routeAsync.value!.durationMin.toStringAsFixed(0)} dk',
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ).animate().scale(),
                      ],
                    ),
                  ),
                ),
                
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _RouteCard(
                          from: 'İstanbul', 
                          to: 'Ankara', 
                          // Using calculated price if available
                          price: routeAsync.value != null ? '₺${routeAsync.value!.estimatedPrice.toStringAsFixed(0)}' : '₺250', 
                          duration: routeAsync.value != null ? '${(routeAsync.value!.durationMin/60).toStringAsFixed(1)} sa' : '4s 30dk'
                        ),
                        const _RouteCard(from: 'İstanbul', to: 'İzmir', price: '₺280', duration: '5s 15dk'),
                        const _RouteCard(from: 'Ankara', to: 'Antalya', price: '₺320', duration: '5s 45dk'),
                      ].animate(interval: 100.ms).fadeIn().slideX(begin: 0.2),
                    ),
                  ),
                ),
                
                // Recent trips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const _TripCard(
                        from: 'İstanbul',
                        to: 'Bursa',
                        date: '12 Şubat 2026',
                        driver: 'Ahmet Y.',
                        price: '₺180',
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
                      const SizedBox(height: 12),
                      const _TripCard(
                        from: 'Ankara',
                        to: 'Eskişehir',
                        date: '8 Şubat 2026',
                        driver: 'Mehmet K.',
                        price: '₺120',
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
                    ]),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String hint;

  const _LocationRow({required this.icon, required this.iconColor, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(hint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String from, to, price, duration;

  const _RouteCard({required this.from, required this.to, required this.price, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassBg, // Glass style for map
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
          Text(duration, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final String from, to, date, driver, price;

  const _TripCard({required this.from, required this.to, required this.date, required this.driver, required this.price});

  @override
  Widget build(BuildContext context) {
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
                Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('$date • $driver', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
