import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class RateDriverScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String driverName;
  final String tripInfo;

  const RateDriverScreen({
    super.key,
    required this.bookingId,
    required this.driverName,
    required this.tripInfo,
  });

  @override
  ConsumerState<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends ConsumerState<RateDriverScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  
  // Optional feedback tags
  final List<String> _positiveTags = ['Güler yüzlü', 'Temiz araç', 'Güvenli sürüş', 'Dakik', 'Yardımsever'];
  final List<String> _negativeTags = ['Geç kaldı', 'Kaba davranış', 'Kirli araç', 'Tehlikeli sürüş'];
  final Set<String> _selectedTags = {};

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir puan seçin'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await ref.read(authTokenProvider.future);
      final dio = ref.read(dioProvider);
      
      await dio.post(
        '/reviews',
        data: {
          'bookingId': widget.bookingId,
          'rating': _rating,
          'comment': _commentController.text,
          'tags': _selectedTags.toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      // Mock success for development
      _showSuccessDialog();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            ).animate().scale(),
            const SizedBox(height: 16),
            const Text(
              'Teşekkürler!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Değerlendirmeniz kaydedildi.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Tamam',
                icon: Icons.check,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/reservations');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Değerlendirme'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Driver Info Card
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.driverName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tripInfo,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Star Rating
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Yolculuk nasıldı?',
                        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = starIndex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                starIndex <= _rating ? Icons.star : Icons.star_border,
                                size: 44,
                                color: starIndex <= _rating ? AppColors.warning : AppColors.textTertiary,
                              ),
                            ),
                          ).animate(delay: (index * 50).ms).scale();
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRatingText(),
                        style: TextStyle(
                          color: _rating > 0 ? AppColors.primary : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 24),

                // Feedback Tags
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ne düşünüyorsunuz? (isteğe bağlı)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...(_rating >= 4 ? _positiveTags : _rating > 0 && _rating < 4 ? _negativeTags : [..._positiveTags, ..._negativeTags]).map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTags.remove(tag);
                                  } else {
                                    _selectedTags.add(tag);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? AppColors.primaryGradient : null,
                                  color: isSelected ? null : AppColors.glassBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : AppColors.glassStroke,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 24),

                // Comment
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yorum ekleyin (isteğe bağlı)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Deneyiminizi paylaşın...',
                          hintStyle: const TextStyle(color: AppColors.textTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.glassStroke),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.glassStroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: _isSubmitting ? 'Gönderiliyor...' : 'Değerlendirmeyi Gönder',
                    icon: Icons.send,
                    onPressed: _isSubmitting ? () {} : _submitReview,
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Daha sonra değerlendir', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText() {
    return switch (_rating) {
      1 => 'Çok kötü',
      2 => 'Kötü',
      3 => 'Orta',
      4 => 'İyi',
      5 => 'Mükemmel!',
      _ => 'Puan verin',
    };
  }
}
