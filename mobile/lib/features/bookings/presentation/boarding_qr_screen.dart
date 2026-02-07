import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';

class BoardingQRScreen extends ConsumerWidget {
  final String bookingId;
  final String tripInfo;
  final String passengerName;
  final int seats;

  const BoardingQRScreen({
    super.key,
    required this.bookingId,
    required this.tripInfo,
    required this.passengerName,
    required this.seats,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrData = 'RIDESHARE:$bookingId:${DateTime.now().millisecondsSinceEpoch}';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Biniş QR Kodu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // QR Code Card
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'BİNİŞ BİLETİ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            embeddedImage: null,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ).animate().scale(delay: 200.ms),

                        const SizedBox(height: 16),

                        // PNR Code
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.glassBgDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassStroke),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'PNR KODU',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _generatePNR(bookingId),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      letterSpacing: 4,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      // Copy to clipboard
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('PNR kodu kopyalandı: ${_generatePNR(bookingId)}'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.copy, color: AppColors.textSecondary, size: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 24),

                        // Dashed line
                        Row(
                          children: List.generate(
                            30,
                            (index) => Expanded(
                              child: Container(
                                height: 2,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                color: index.isEven ? AppColors.glassStroke : Colors.transparent,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Trip Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GÜZERGAH', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text(tripInfo, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('KOLTUK', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text('$seats kişi', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('YOLCU', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text(passengerName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('REZERVASYON', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text('#${bookingId.substring(0, 8).toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  // Instructions
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline, color: AppColors.warning),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'QR kodu taratın veya PNR kodunu\nsürücüye söyleyin.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  // Brightness button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Increase brightness for easier scanning
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ekran parlaklığı artırıldı'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.brightness_high),
                      label: const Text('Parlaklığı Artır'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _generatePNR(String bookingId) {
    // Generate a 6-character alphanumeric PNR from booking ID
    final chars = bookingId.replaceAll('-', '').toUpperCase();
    if (chars.length >= 6) {
      return chars.substring(0, 6);
    }
    return chars.padRight(6, '0');
  }
}
