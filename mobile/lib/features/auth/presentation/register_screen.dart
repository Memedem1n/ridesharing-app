import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kullanım şartlarını kabul etmelisiniz'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      '+90${_phoneController.text.trim()}',
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RippleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Hesap Oluştur',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Yolculuk deneyiminizi başlatın',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  
                  const SizedBox(height: 32),

                  // Error message
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.errorLight),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: TextStyle(color: AppColors.errorLight, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shakeX(hz: 4, amount: 3),
                    const SizedBox(height: 20),
                  ],

                  // Glass Form Container
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Name field
                        _buildField(
                          controller: _nameController,
                          hint: 'Ad Soyad',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Ad soyad gerekli';
                            if (value.split(' ').length < 2) return 'Ad ve soyad giriniz';
                            return null;
                          },
                        ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                        
                        const SizedBox(height: 16),

                        // Email field
                        _buildField(
                          controller: _emailController,
                          hint: 'E-posta',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'E-posta gerekli';
                            if (!value.contains('@')) return 'Geçerli bir e-posta girin';
                            return null;
                          },
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
                        
                        const SizedBox(height: 16),

                        // Phone field
                        _buildField(
                          controller: _phoneController,
                          hint: 'Telefon',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          prefixText: '+90 ',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Telefon gerekli';
                            if (value.length < 10) return 'Geçerli bir telefon girin';
                            return null;
                          },
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),
                        
                        const SizedBox(height: 16),

                        // Password field
                        _buildField(
                          controller: _passwordController,
                          hint: 'Şifre',
                          icon: Icons.lock_outline_rounded,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Şifre gerekli';
                            if (value.length < 6) return 'En az 6 karakter';
                            return null;
                          },
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),
                        
                        const SizedBox(height: 16),

                        // Confirm Password field
                        _buildField(
                          controller: _confirmPasswordController,
                          hint: 'Şifre Tekrar',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: (value) {
                            if (value != _passwordController.text) return 'Şifreler eşleşmiyor';
                            return null;
                          },
                        ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1, end: 0),
                        
                        const SizedBox(height: 20),

                        // Terms checkbox
                        Row(
                          children: [
                            Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: _acceptedTerms,
                                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                                activeColor: AppColors.primary,
                                checkColor: AppColors.background,
                                side: BorderSide(color: AppColors.glassStroke, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    children: [
                                      const TextSpan(text: 'Okudum, '),
                                      TextSpan(
                                        text: 'Kullanım Şartları',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: ' ve '),
                                      TextSpan(
                                        text: 'Gizlilik Politikası',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: "'nı kabul ediyorum."),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 800.ms),
                        
                        const SizedBox(height: 28),

                        // Register button
                        GradientButton(
                          text: 'Kayıt Ol',
                          icon: Icons.person_add_rounded,
                          isLoading: authState.status == AuthStatus.loading,
                          onPressed: _register,
                        ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0),
                      ],
                    ),
                  ), // End GlassContainer
                  
                  const SizedBox(height: 28),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten hesabınız var mı? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Giriş Yap',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1000.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
