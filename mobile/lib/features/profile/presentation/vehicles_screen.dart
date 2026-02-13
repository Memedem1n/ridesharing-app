import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/vehicle_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../vehicles/domain/vehicle_models.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    if (kIsWeb) {
      return _buildWeb(context, vehiclesAsync);
    }
    return _buildMobile(context, vehiclesAsync);
  }

  Widget _buildMobile(
    BuildContext context,
    AsyncValue<List<Vehicle>> vehiclesAsync,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araclarim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/vehicle-create'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: _buildBody(context, vehiclesAsync, webMode: false),
      ),
    );
  }

  Widget _buildWeb(
    BuildContext context,
    AsyncValue<List<Vehicle>> vehiclesAsync,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Araclarim',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F3A30),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/profile'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Profile Don'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Sayfa'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/vehicle-create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Arac Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Arac bilgileri ve dogrulama durumlari web panelinde listelenir.',
                    style: TextStyle(
                      color: Color(0xFF4E665C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _buildBody(context, vehiclesAsync, webMode: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<Vehicle>> vehiclesAsync, {
    required bool webMode,
  }) {
    return vehiclesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Hata: $e',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Henuz arac eklenmedi',
                  style: TextStyle(
                    color: webMode
                        ? const Color(0xFF365D4E)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/vehicle-create'),
                  icon: const Icon(Icons.add),
                  label: const Text('Arac Ekle'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/vehicle-verification'),
                  child: const Text('Ruhsat Dogrula'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VehicleCard(vehicle: vehicle, webMode: webMode),
            );
          },
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.webMode});

  final Vehicle vehicle;
  final bool webMode;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_car, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicle.brand} ${vehicle.model}',
                style: TextStyle(
                  color:
                      webMode ? const Color(0xFF1F3A30) : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vehicle.licensePlate,
                style: TextStyle(
                  color: webMode
                      ? const Color(0xFF4E665C)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          vehicle.verified ? Icons.verified : Icons.verified_outlined,
          color: vehicle.verified ? AppColors.success : AppColors.textTertiary,
        ),
      ],
    );

    if (webMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE6E1)),
        ),
        child: content,
      );
    }

    return GlassContainer(padding: const EdgeInsets.all(16), child: content);
  }
}
