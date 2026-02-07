import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class TripDetailsScreen extends StatelessWidget {
  final String tripId;

  const TripDetailsScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yolculuk Detayı'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Driver Card
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ahmet Yılmaz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: AppColors.warning),
                            const Text(' 4.8'),
                            const SizedBox(width: 8),
                            Text('• 47 yolculuk', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('Onaylı Profil', style: TextStyle(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Route Details
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  _RoutePoint(
                    time: '08:00',
                    location: 'İstanbul, Kadıköy',
                    isStart: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 35),
                    child: Row(
                      children: [Text('~4 saat 30 dk', style: TextStyle(color: AppColors.textSecondary))],
                    ),
                  ),
                  _RoutePoint(
                    time: '12:30',
                    location: 'Ankara, Kızılay',
                    isStart: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Vehicle
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Araç', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.directions_car, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Toyota Corolla 2022', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('34 ABC 123', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Features
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Özellikler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: [
                      _Feature(icon: Icons.ac_unit, label: 'Klima', active: true),
                      _Feature(icon: Icons.smoke_free, label: 'Sigara yok', active: true),
                      _Feature(icon: Icons.pets, label: 'Evcil hayvan', active: false),
                      _Feature(icon: Icons.music_note, label: 'Müzik', active: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Price Comparison
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fiyat Karşılaştırma', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PriceCompare(label: 'Bu İlan', price: '150 ₺', highlight: true),
                      _PriceCompare(label: 'Otobüs', price: '350 ₺', highlight: false),
                      _PriceCompare(label: 'Tasarruf', price: '200 ₺', highlight: false, isGreen: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Koltuk başı', style: TextStyle(color: AppColors.textSecondary)),
                Text('150 ₺', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.push('/booking/$tripId'),
                child: const Text('Rezervasyon Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String time;
  final String location;
  final bool isStart;

  const _RoutePoint({required this.time, required this.location, required this.isStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold))),
        Icon(isStart ? Icons.trip_origin : Icons.location_on, size: 20, color: isStart ? AppColors.primary : AppColors.secondary),
        const SizedBox(width: 12),
        Expanded(child: Text(location, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _Feature({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textSecondary),
      label: Text(label),
      backgroundColor: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.border,
    );
  }
}

class _PriceCompare extends StatelessWidget {
  final String label;
  final String price;
  final bool highlight;
  final bool isGreen;

  const _PriceCompare({required this.label, required this.price, required this.highlight, this.isGreen = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          price,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.primary : (isGreen ? AppColors.success : null),
          ),
        ),
      ],
    );
  }
}
