import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.construction_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Geri dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
