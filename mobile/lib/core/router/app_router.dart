import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/bookings/presentation/my_reservations_screen.dart';
import '../../features/bookings/presentation/driver_reservations_screen.dart';
import '../../features/bookings/presentation/boarding_qr_screen.dart';
import '../../features/bookings/presentation/qr_scanner_screen.dart';
import '../../features/bookings/presentation/booking_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/verification_screen.dart';
import '../../features/trips/presentation/create_trip_screen.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/search_screen.dart';
import '../../features/trips/presentation/my_trips_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/reviews/presentation/rate_driver_screen.dart';
import '../../features/profile/presentation/vehicle_verification_screen.dart';
import '../../features/profile/presentation/profile_details_screen.dart';
import '../../features/profile/presentation/vehicles_screen.dart';
import '../../features/vehicles/presentation/vehicle_create_screen.dart';
import '../../features/profile/presentation/placeholder_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/help_support_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_buttons.dart';

const Set<String> _publicExactPaths = {
  '/',
  '/search',
  '/search-results',
  '/login',
  '/register',
  '/about',
  '/help',
  '/forgot-password',
};

const List<String> _publicPathPrefixes = ['/trip/'];

bool _isPublicPath(String path) {
  if (_publicExactPaths.contains(path)) {
    return true;
  }
  return _publicPathPrefixes.any(path.startsWith);
}

String _buildLoginRedirect(Uri currentUri) {
  final next = Uri.encodeComponent(currentUri.toString());
  return '/login?next=$next';
}

String? _sanitizeNextRoute(String? rawNext) {
  if (rawNext == null || rawNext.trim().isEmpty) {
    return null;
  }
  final next = rawNext.trim();
  if (!next.startsWith('/')) {
    return null;
  }
  if (next.startsWith('/login') || next.startsWith('/register')) {
    return null;
  }
  return next;
}

// ==================== ROUTER ====================
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final webInitialLocation = kIsWeb
      ? '${Uri.base.path.isEmpty ? '/' : Uri.base.path}'
          '${Uri.base.hasQuery ? '?${Uri.base.query}' : ''}'
      : '/';

  return GoRouter(
    initialLocation: webInitialLocation,
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register';

      if (!isAuth && !_isPublicPath(path)) {
        return _buildLoginRedirect(state.uri);
      }

      if (isAuth && isAuthRoute) {
        return _sanitizeNextRoute(state.uri.queryParameters['next']) ?? '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen())),
          GoRoute(
              path: '/search',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SearchScreen())),
          GoRoute(
              path: '/reservations',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MyReservationsScreen())),
          GoRoute(
              path: '/messages',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MessagesScreen())),
          GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen())),
        ],
      ),
      GoRoute(
          path: '/trip/:id',
          builder: (context, state) => TripDetailScreen(
                tripId: state.pathParameters['id']!,
                requestedFrom: state.uri.queryParameters['from'],
                requestedTo: state.uri.queryParameters['to'],
              )),
      GoRoute(
        path: '/search-results',
        builder: (context, state) => SearchResultsScreen(
          from: state.uri.queryParameters['from'],
          to: state.uri.queryParameters['to'],
          date: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
          path: '/booking/:tripId',
          builder: (context, state) => BookingScreen(
                tripId: state.pathParameters['tripId']!,
                requestedFrom: state.uri.queryParameters['from'],
                requestedTo: state.uri.queryParameters['to'],
                segmentPricePerSeat:
                    double.tryParse(state.uri.queryParameters['sp'] ?? ''),
              )),
      GoRoute(
          path: '/verification',
          builder: (context, state) => const VerificationScreen()),
      GoRoute(
          path: '/create-trip',
          builder: (context, state) => const CreateTripScreen()),
      GoRoute(
          path: '/chat/:bookingId',
          builder: (context, state) => ChatScreen(
                bookingId: state.pathParameters['bookingId']!,
                otherName: state.uri.queryParameters['name'] ?? 'Kullanici',
                tripInfo: state.uri.queryParameters['trip'],
              )),
      GoRoute(
          path: '/driver-reservations',
          builder: (context, state) => DriverReservationsScreen(
                initialTripId: state.uri.queryParameters['tripId'],
              )),
      GoRoute(
          path: '/boarding-qr',
          builder: (context, state) => BoardingQRScreen(
                bookingId: state.uri.queryParameters['bookingId'] ?? '',
                tripInfo: state.uri.queryParameters['trip'] ?? '',
                passengerName: state.uri.queryParameters['name'] ?? '',
                seats:
                    int.tryParse(state.uri.queryParameters['seats'] ?? '1') ??
                        1,
                qrCode: state.uri.queryParameters['qr'],
                pnrCode: state.uri.queryParameters['pnr'],
              )),
      GoRoute(
          path: '/qr-scanner/:tripId',
          builder: (context, state) => QRScannerScreen(
                tripId: state.pathParameters['tripId']!,
              )),
      GoRoute(
          path: '/rate-driver',
          builder: (context, state) => RateDriverScreen(
                bookingId: state.uri.queryParameters['bookingId'] ?? '',
                driverName: state.uri.queryParameters['driver'] ?? 'Sürücü',
                tripInfo: state.uri.queryParameters['trip'] ?? '',
              )),
      GoRoute(
          path: '/vehicle-verification',
          builder: (context, state) => const VehicleVerificationScreen()),
      GoRoute(
          path: '/vehicle-create',
          builder: (context, state) => const VehicleCreateScreen()),
      GoRoute(
          path: '/profile-details',
          builder: (context, state) => const ProfileDetailsScreen()),
      GoRoute(
          path: '/my-vehicles',
          builder: (context, state) => const VehiclesScreen()),
      GoRoute(
          path: '/trip-history',
          builder: (context, state) => const MyTripsScreen()),
      GoRoute(
        path: '/payment-methods',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Ödeme Yöntemleri',
          message: 'Ödeme yöntemleri yönetimi yakında eklenecek.',
        ),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Cüzdan',
          message: 'Cüzdan yönetimi yakında eklenecek.',
        ),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Güvenlik',
          message: 'Güvenlik ayarları yakında eklenecek.',
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Şifre Sıfırlama',
          message: 'Şifre sıfırlama yakında eklenecek.',
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
    ],
  );
});

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isWideWeb = kIsWeb;
    final location = GoRouterState.of(context).matchedLocation;
    final bookingsLabel = 'Rezerv.';
    final navDestinations = isAuthenticated
        ? <NavigationDestination>[
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: strings.navHome),
            NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: strings.navSearch),
            NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: bookingsLabel),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: strings.navMessages),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: strings.navProfile),
          ]
        : const <NavigationDestination>[
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Ana Sayfa'),
            NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Ara'),
            NavigationDestination(
                icon: Icon(Icons.login_rounded),
                selectedIcon: Icon(Icons.login_rounded),
                label: 'Giriş Yap'),
          ];

    return Scaffold(
      body: child,
      bottomNavigationBar: isWideWeb
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                border: Border(top: BorderSide(color: AppColors.glassStroke)),
              ),
              child: NavigationBar(
                selectedIndex: _calculateIndex(location, isAuthenticated),
                onDestinationSelected: (index) =>
                    _onNavTap(context, index, isAuthenticated),
                backgroundColor: Colors.transparent,
                elevation: 0,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: navDestinations,
              ),
            ),
      floatingActionButton: location == '/' && isAuthenticated
          ? PulseFloatingButton(
              onPressed: () => context.push('/create-trip'),
              icon: Icons.add,
              label: strings.actionCreateTrip,
            )
          : null,
    );
  }

  int _calculateIndex(String location, bool isAuthenticated) {
    if (!isAuthenticated) {
      if (location.startsWith('/search')) return 1;
      return 0;
    }
    if (location == '/' || location.isEmpty) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/reservations')) return 2;
    if (location.startsWith('/messages')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onNavTap(BuildContext context, int index, bool isAuthenticated) {
    if (!isAuthenticated) {
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/search');
          break;
        case 2:
          context.push('/login');
          break;
      }
      return;
    }
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/reservations');
        break;
      case 3:
        context.go('/messages');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }
}
