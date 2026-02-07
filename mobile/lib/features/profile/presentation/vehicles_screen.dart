import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/vehicle_provider.dart';
import '../../../core/theme/app_theme.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/vehicle-create'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: vehiclesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    const Text('Henüz araç eklenmedi', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/vehicle-create'),
                      icon: const Icon(Icons.add),
                      label: const Text('Araç Ekle'),
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

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
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
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicle.licensePlate,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          vehicle.verified ? Icons.verified : Icons.verified_outlined,
                          color: vehicle.verified ? AppColors.success : AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
