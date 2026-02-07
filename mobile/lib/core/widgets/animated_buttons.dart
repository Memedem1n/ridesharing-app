import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Gradient Button with glow effect
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final List<Color>? gradientColors;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradientColors,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ?? [
      AppColors.primary,
      AppColors.primaryDark,
    ];

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.diagonal3Values(_isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: _isPressed ? 0.2 : 0.4),
                blurRadius: _isPressed ? 8 : 16,
                offset: const Offset(0, 4),
                spreadRadius: _isPressed ? 0 : 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    ).animate(target: _isPressed ? 1 : 0)
     .shimmer(duration: 600.ms, color: Colors.white.withValues(alpha: 0.3));
  }
}

/// Outline Button with hover effect
class AnimatedOutlineButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;

  const AnimatedOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.borderColor,
  });

  @override
  State<AnimatedOutlineButton> createState() => _AnimatedOutlineButtonState();
}

class _AnimatedOutlineButtonState extends State<AnimatedOutlineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.borderColor ?? AppColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: _isHovered ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: color, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating Action Button with pulse animation
class PulseFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;

  const PulseFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(label != null ? 28 : 56),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(label != null ? 28 : 56),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 20 : 16,
              vertical: 16,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (label != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.05, 1.05),
      duration: 1500.ms,
      curve: Curves.easeInOut,
    );
  }
}

/// Icon Button with ripple effect
class RippleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const RippleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.textSecondary;
    
    final button = Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: size),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Social Login Button
class SocialLoginButton extends StatefulWidget {
  final String provider; // 'google', 'apple', 'facebook'
  final VoidCallback? onPressed;

  const SocialLoginButton({
    super.key,
    required this.provider,
    this.onPressed,
  });

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final config = _getProviderConfig();
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(_isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0, 1.0),
        height: 56,
        decoration: BoxDecoration(
          color: config['bgColor'] as Color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: config['borderColor'] as Color,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    config['icon'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    config['text'] as String,
                    style: TextStyle(
                      color: config['textColor'] as Color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getProviderConfig() {
    switch (widget.provider.toLowerCase()) {
      case 'google':
        return {
          'icon': '🔵',
          'text': 'Google ile devam et',
          'bgColor': Colors.white,
          'borderColor': AppColors.border,
          'textColor': AppColors.textPrimary,
        };
      case 'apple':
        return {
          'icon': '🍎',
          'text': 'Apple ile devam et',
          'bgColor': Colors.black,
          'borderColor': Colors.black,
          'textColor': Colors.white,
        };
      case 'facebook':
        return {
          'icon': '📘',
          'text': 'Facebook ile devam et',
          'bgColor': const Color(0xFF1877F2),
          'borderColor': const Color(0xFF1877F2),
          'textColor': Colors.white,
        };
      default:
        return {
          'icon': '👤',
          'text': 'Devam et',
          'bgColor': AppColors.surfaceVariant,
          'borderColor': AppColors.border,
          'textColor': AppColors.textPrimary,
        };
    }
  }
}

/// Chip-style small button
class ChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const ChipButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isSelected ? AppColors.primaryGradient : null,
        color: isSelected ? null : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
