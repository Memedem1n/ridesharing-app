import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/animated_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
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
                      const SizedBox(height: 60),

                      // Logo with glow effect
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),

                      const SizedBox(height: 40),

                      // Title
                      Text(
                        strings.loginTitle,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 8),

                      Text(
                        strings.loginSubtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 48),

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
                        const SizedBox(height: 24),
                      ],

                      // Glass card for form
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: strings.emailOrPhone,
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return strings.fieldRequired;
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: strings.password,
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () {
                                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return strings.passwordRequired;
                                }
                                if (value.length < 6) {
                                  return strings.passwordMin;
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 8),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: Text(
                                  strings.forgotPassword,
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                text: authState.status == AuthStatus.loading ? '${strings.login}...' : strings.login,
                                icon: Icons.login_rounded,
                                onPressed: authState.status == AuthStatus.loading ? null : _login,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Register prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            strings.noAccount,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: Text(strings.register),
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
}
