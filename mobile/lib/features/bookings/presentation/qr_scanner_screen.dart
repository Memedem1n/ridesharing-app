import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  final String tripId;

  const QRScannerScreen({super.key, required this.tripId});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isVerifying = false;
  String? _scannedCode;
  String? _verificationResult;
  bool? _verificationSuccess;
  late TabController _tabController;

  // Controllers for both input types
  final _qrCodeController = TextEditingController();
  final _pnrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _verifyCode(String code, {bool isPNR = false}) async {
    setState(() {
      _isVerifying = true;
      _scannedCode = code;
    });

    try {
      if (isPNR) {
        setState(() {
          _verificationSuccess = false;
          _verificationResult = 'PNR doğrulama desteklenmiyor';
        });
        return;
      }

      final token = await ref.read(authTokenProvider.future);
      final dio = ref.read(dioProvider);
      
      await dio.post(
        '/bookings/check-in',
        data: {
          'qrCode': code,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() {
        _verificationSuccess = true;
        _verificationResult = 'Yolcu binişi onaylandı!';
      });
    } catch (e) {
      setState(() {
        _verificationSuccess = false;
        _verificationResult = 'Doğrulama başarısız';
      });
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _reset() {
    setState(() {
      _scannedCode = null;
      _verificationResult = null;
      _verificationSuccess = null;
      _isScanning = false;
      _qrCodeController.clear();
      _pnrController.clear();
    });
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    _pnrController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Biniş Doğrulama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _verificationResult != null
                ? _buildResultView()
                : _buildVerificationView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tab Bar
        GlassContainer(
          padding: const EdgeInsets.all(8),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR Tara'),
              Tab(icon: Icon(Icons.pin), text: 'PNR Gir'),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 24),

        // Tab Content
        SizedBox(
          height: 420,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQRTab(),
              _buildPNRTab(),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Instructions
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'QR kod taratın veya yolcunun PNR kodunu girin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Onay sonrası yolcu binişi kaydedilir',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildQRTab() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner decorations
                Positioned(top: 0, left: 0, child: _CornerDecoration()),
                Positioned(top: 0, right: 0, child: Transform.rotate(angle: 1.5708, child: _CornerDecoration())),
                Positioned(bottom: 0, left: 0, child: Transform.rotate(angle: -1.5708, child: _CornerDecoration())),
                Positioned(bottom: 0, right: 0, child: Transform.rotate(angle: 3.1416, child: _CornerDecoration())),
                Center(
                  child: _isScanning
                    ? Container(
                        width: 180,
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat())
                        .slideY(begin: -3, end: 3, duration: 2.seconds)
                    : const Icon(Icons.qr_code_scanner, size: 48, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Web modunda manuel QR girin:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _qrCodeController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'RIDESHARE:...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassStroke)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: _isVerifying ? 'Doğrulanıyor...' : 'QR Doğrula',
              icon: Icons.qr_code,
              onPressed: _isVerifying ? () {} : () {
                if (_qrCodeController.text.isNotEmpty) {
                  _verifyCode(_qrCodeController.text);
                }
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildPNRTab() {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.pin, size: 48, color: AppColors.primary),
          ),

          const SizedBox(height: 24),

          const Text(
            'PNR KODU',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _pnrController,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                color: AppColors.textTertiary.withValues(alpha: 0.5),
                fontSize: 32,
                letterSpacing: 8,
              ),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.glassStroke, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '6 haneli PNR kodunu girin',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: _isVerifying ? 'Doğrulanıyor...' : 'PNR Doğrula',
              icon: Icons.verified_user,
              onPressed: _isVerifying ? () {} : () {
                if (_pnrController.text.length == 6) {
                  _verifyCode(_pnrController.text.toUpperCase(), isPNR: true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PNR kodu 6 karakter olmalı'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildResultView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: (_verificationSuccess ?? false) 
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (_verificationSuccess ?? false) ? Icons.check_circle : Icons.cancel,
                  size: 64,
                  color: (_verificationSuccess ?? false) ? AppColors.success : AppColors.error,
                ),
              ).animate().scale(),

              const SizedBox(height: 24),

              Text(
                _verificationResult ?? '',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              if (_scannedCode != null)
                Text(
                  'Kod: ${_scannedCode!.length > 30 ? '${_scannedCode!.substring(0, 30)}...' : _scannedCode}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'monospace'),
                ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Yeni Tarama'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      text: 'Tamam',
                      icon: Icons.check,
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1),
      ],
    );
  }
}

class _CornerDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerPainter(),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
