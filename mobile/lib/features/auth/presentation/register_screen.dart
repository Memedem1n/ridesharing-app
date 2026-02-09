import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';

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
    final strings = ref.watch(appStringsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 390 ? 16.0 : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
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
                        strings.registerTitle,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 8),

                      Text(
                        strings.registerSubtitle,
                        style: const TextStyle(
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
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
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
                              hint: strings.name,
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
                              hint: strings.email,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'E-posta gerekli';
                                if (!value.contains('@')) return 'Gecerli bir e-posta girin';
                                return null;
                              },
                            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),

                            const SizedBox(height: 16),

                            // Phone field
                            _buildField(
                              controller: _phoneController,
                              hint: strings.phone,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              prefixText: '+90 ',
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Telefon gerekli';
                                if (value.length < 10) return 'Gecerli bir telefon girin';
                                return null;
                              },
                            ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),

                            const SizedBox(height: 16),

                            // Password field
                            _buildField(
                              controller: _passwordController,
                              hint: strings.password,
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
                                if (value == null || value.isEmpty) return strings.passwordRequired;
                                if (value.length < 6) return strings.passwordMin;
                                return null;
                              },
                            ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),

                            const SizedBox(height: 16),

                            // Confirm Password field
                            _buildField(
                              controller: _confirmPasswordController,
                              hint: strings.confirmPassword,
                              icon: Icons.lock_outline_rounded,
                              obscureText: !_isPasswordVisible,
                              validator: (value) {
                                if (value == null || value.isEmpty) return strings.passwordRequired;
                                if (value != _passwordController.text) return strings.passwordMismatch;
                                return null;
                              },
                            ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1, end: 0),

                            const SizedBox(height: 16),

                            // Terms
                            Row(
                              children: [
                                Checkbox(
                                  value: _acceptedTerms,
                                  onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Kullanim sartlarini kabul ediyorum',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Register button
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                text: authState.status == AuthStatus.loading ? '${strings.register}...' : strings.register,
                                icon: Icons.person_add_alt_1_rounded,
                                onPressed: authState.status == AuthStatus.loading ? null : _register,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            strings.alreadyHaveAccount,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(strings.login),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
    bool obscureText = false,
    String? prefixText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}
