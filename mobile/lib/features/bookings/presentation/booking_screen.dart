import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  final String tripId;

  const BookingScreen({super.key, required this.tripId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _seats = 1;
  bool _isLoading = false;

  void _confirmBooking() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: AppColors.success, size: 64),
        title: const Text('Rezervasyon Başarılı!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('QR kodunuz hazır. Yolculuk günü sürücüye gösterin.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2, size: 120, color: AppColors.textPrimary),
                  const SizedBox(height: 8),
                  const Text('BK-ABC123456789', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/home');
            },
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = 150 * _seats;
    final commission = (price * 0.1).round();
    final total = price;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yolculuk Özeti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    Row(
                      children: [
                        Icon(Icons.trip_origin, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text('İstanbul, Kadıköy'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Container(width: 2, height: 20, color: AppColors.border),
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.secondary, size: 20),
                        const SizedBox(width: 8),
                        const Text('Ankara, Kızılay'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary), const SizedBox(width: 4), const Text('15 Şubat 2026')]),
                        Row(children: [Icon(Icons.access_time, size: 16, color: AppColors.textSecondary), const SizedBox(width: 4), const Text('08:00')]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Seat Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Koltuk Sayısı', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text('$_seats', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        IconButton.filled(
                          onPressed: _seats < 3 ? () => setState(() => _seats++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text('Maksimum 3 koltuk seçebilirsiniz', style: TextStyle(color: AppColors.textSecondary))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Price Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fiyat Detayı', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _PriceRow(label: 'Koltuk başı', value: '150 ₺'),
                    _PriceRow(label: 'Koltuk sayısı', value: 'x $_seats'),
                    const Divider(),
                    _PriceRow(label: 'Ara toplam', value: '$price ₺'),
                    _PriceRow(label: 'Platform komisyonu', value: '$commission ₺', subtitle: '%10'),
                    const Divider(),
                    _PriceRow(label: 'Toplam', value: '$total ₺', isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cancellation Policy
            Card(
              color: AppColors.info.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('İptal Politikası', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('24 saat öncesi: Tam iade\n2-24 saat: %50 iade\n2 saat içi: İade yok', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _confirmBooking,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('$total ₺ Öde ve Rezervasyon Yap'),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final bool isBold;

  const _PriceRow({required this.label, required this.value, this.subtitle, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null)),
              if (subtitle != null) Text(' ($subtitle)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null, color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}
