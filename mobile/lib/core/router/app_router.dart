import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/bookings/presentation/my_reservations_screen.dart';
import '../../features/bookings/presentation/driver_reservations_screen.dart';
import '../../features/bookings/presentation/boarding_qr_screen.dart';
import '../../features/bookings/presentation/qr_scanner_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/verification_screen.dart';
import '../../features/trips/presentation/create_trip_screen.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/reviews/presentation/rate_driver_screen.dart';
import '../../features/profile/presentation/vehicle_verification_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/message_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_buttons.dart';

// ==================== HOME SCREEN ====================


// ==================== SEARCH SCREEN ====================
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  void _search() {
    ref.read(tripSearchParamsProvider.notifier).state = TripSearchParams(
      departureCity: _fromController.text,
      arrivalCity: _toController.text,
    );
    context.push('/search-results?from=${_fromController.text}&to=${_toController.text}');
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuk Ara')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _fromController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nereden?',
                        hintStyle: const TextStyle(color: AppColors.textTertiary),
                        prefixIcon: Icon(Icons.circle_outlined, color: AppColors.primary, size: 18),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(color: AppColors.glassStroke),
                    TextField(
                      controller: _toController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nereye?',
                        hintStyle: const TextStyle(color: AppColors.textTertiary),
                        prefixIcon: Icon(Icons.location_on, color: AppColors.accent, size: 18),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                child: Text('Popu00fcler Rotalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              _PopularRouteCard(from: 'u0130stanbul', to: 'Ankara', price: 350),
              const SizedBox(height: 8),
              _PopularRouteCard(from: 'u0130stanbul', to: 'Bursa', price: 150),
              const SizedBox(height: 8),
              _PopularRouteCard(from: 'Ankara', to: 'u0130zmir', price: 450),
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

  const _PopularRouteCard({required this.from, required this.to, required this.price});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search-results?from=$from&to=$to'),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$from u2192 $to', style: const TextStyle(color: AppColors.textPrimary)),
            ),
            Text('u20ba${price.toStringAsFixed(0)}+', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

// ==================== MESSAGES SCREEN ====================
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlar')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: conversationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          data: (conversations) {
            if (conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.primary),
                    ).animate().scale(),
                    const SizedBox(height: 24),
                    const Text('Henu00fcz mesaju0131nu0131z yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Yolculuk rezervasyonu yaptu0131u011fu0131nu0131zda\nsu00fcu00fccu00fcyle mesajlau015fabilirsiniz',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.2),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(conversation: conv, index: index);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int index;

  const _ConversationTile({required this.conversation, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.otherName)}&trip=${Uri.encodeComponent(conversation.tripInfo ?? '')}'),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundImage: conversation.otherPhoto != null ? NetworkImage(conversation.otherPhoto!) : null,
                  child: conversation.otherPhoto == null 
                    ? Text(conversation.otherName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))
                    : null,
                ),
                if (conversation.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        conversation.unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(conversation.otherName, 
                          style: TextStyle(
                            color: AppColors.textPrimary, 
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (conversation.lastMessageTime != null)
                        Text(
                          _formatTime(conversation.lastMessageTime!),
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                    ],
                  ),
                  if (conversation.tripInfo != null) ...[
                    const SizedBox(height: 2),
                    Text(conversation.tripInfo!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                  if (conversation.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: conversation.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: 0.1);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} sa';
    } else {
      return '${diff.inDays} g';
    }
  }
}

// ==================== PROFILE SCREEN ====================
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Profile header with glow
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.person, size: 48, color: Colors.white),
                ).animate().scale(curve: Curves.elasticOut),
                
                const SizedBox(height: 20),
                
                Text(
                  user?.fullName ?? 'Kullanıcı',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ).animate().fadeIn(delay: 200.ms),
                
                const SizedBox(height: 4),
                
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 36),
                
                // Menu items in glass container
                GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _ProfileMenuItem(icon: Icons.person_outline, title: 'Profil Bilgileri', onTap: () {}),
                      _Divider(),
                      _ProfileMenuItem(icon: Icons.verified_user_outlined, title: 'Hesap Doğrulama', onTap: () => context.push('/verification')),
                      _ProfileMenuItem(icon: Icons.directions_car_outlined, title: 'Araçlarım', onTap: () {}),
                      _Divider(),
                      _ProfileMenuItem(icon: Icons.history, title: 'Yolculuk Geçmişi', onTap: () {}),
                      _Divider(),
                      _ProfileMenuItem(icon: Icons.payment, title: 'Ödeme Yöntemleri', onTap: () {}),
                      _Divider(),
                      _ProfileMenuItem(icon: Icons.settings_outlined, title: 'Ayarlar', onTap: () {}),
                      _Divider(),
                      _ProfileMenuItem(icon: Icons.help_outline, title: 'Yardım', onTap: () {}),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                
                const SizedBox(height: 24),
                
                AnimatedOutlineButton(
                  text: 'Çıkış Yap',
                  icon: Icons.logout,
                  borderColor: AppColors.error,
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                ).animate().fadeIn(delay: 600.ms),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.glassStroke, indent: 56, endIndent: 16);
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient.scale(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

// ==================== DETAIL SCREENS ====================
class TripDetailsScreen extends StatelessWidget {
  final String tripId;
  const TripDetailsScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuk Detayı')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(child: Text('Trip ID: $tripId', style: TextStyle(color: AppColors.textPrimary))),
      ),
    );
  }
}

class BookingScreen extends StatelessWidget {
  final String tripId;
  const BookingScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(child: Text('Booking for Trip: $tripId', style: TextStyle(color: AppColors.textPrimary))),
      ),
    );
  }
}

// ==================== ROUTER ====================
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.status == AuthStatus.authenticated ? '/' : '/login',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/search', pageBuilder: (context, state) => const NoTransitionPage(child: SearchScreen())),
          GoRoute(path: '/reservations', pageBuilder: (context, state) => const NoTransitionPage(child: MyReservationsScreen())),
          GoRoute(path: '/messages', pageBuilder: (context, state) => const NoTransitionPage(child: MessagesScreen())),
          GoRoute(path: '/profile', pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen())),
        ],
      ),

      GoRoute(path: '/trip/:id', builder: (context, state) => TripDetailScreen(tripId: state.pathParameters['id']!)),
      GoRoute(path: '/search-results', builder: (context, state) => SearchResultsScreen(
        from: state.uri.queryParameters['from'],
        to: state.uri.queryParameters['to'],
        date: state.uri.queryParameters['date'],
      )),
      GoRoute(path: '/booking/:tripId', builder: (context, state) => BookingScreen(tripId: state.pathParameters['tripId']!)),
      GoRoute(path: '/verification', builder: (context, state) => const VerificationScreen()),
      GoRoute(path: '/create-trip', builder: (context, state) => const CreateTripScreen()),
      GoRoute(path: '/chat/:bookingId', builder: (context, state) => ChatScreen(
        bookingId: state.pathParameters['bookingId']!,
        otherName: state.uri.queryParameters['name'] ?? 'Kullanıcı',
        tripInfo: state.uri.queryParameters['trip'],
      )),
      GoRoute(path: '/driver-reservations', builder: (context, state) => const DriverReservationsScreen()),
      GoRoute(path: '/boarding-qr', builder: (context, state) => BoardingQRScreen(
        bookingId: state.uri.queryParameters['bookingId'] ?? '',
        tripInfo: state.uri.queryParameters['trip'] ?? '',
        passengerName: state.uri.queryParameters['name'] ?? '',
        seats: int.tryParse(state.uri.queryParameters['seats'] ?? '1') ?? 1,
      )),
      GoRoute(path: '/qr-scanner/:tripId', builder: (context, state) => QRScannerScreen(
        tripId: state.pathParameters['tripId']!,
      )),
      GoRoute(path: '/rate-driver', builder: (context, state) => RateDriverScreen(
        bookingId: state.uri.queryParameters['bookingId'] ?? '',
        driverName: state.uri.queryParameters['driver'] ?? 'Sürücü',
        tripInfo: state.uri.queryParameters['trip'] ?? '',
      )),
      GoRoute(path: '/vehicle-verification', builder: (context, state) => const VehicleVerificationScreen()),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          border: Border(top: BorderSide(color: AppColors.glassStroke)),
        ),
        child: NavigationBar(
          selectedIndex: _calculateIndex(GoRouterState.of(context).matchedLocation),
          onDestinationSelected: (index) => _onNavTap(context, index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
            NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Ara'),
            NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: 'Rezervasyonlar'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Mesajlar'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
      floatingActionButton: GoRouterState.of(context).matchedLocation == '/'
        ? PulseFloatingButton(
            onPressed: () => context.push('/create-trip'),
            icon: Icons.add,
            label: 'İlan Ver',
          )
        : null,
    );
  }

  int _calculateIndex(String location) {
    if (location == '/' || location.isEmpty) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/reservations')) return 2;
    if (location.startsWith('/messages')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/'); break;
      case 1: context.go('/search'); break;
      case 2: context.go('/reservations'); break;
      case 3: context.go('/messages'); break;
      case 4: context.go('/profile'); break;
    }
  }
}
