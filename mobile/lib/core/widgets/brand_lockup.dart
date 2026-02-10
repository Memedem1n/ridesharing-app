import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandLockup extends StatelessWidget {
  final double iconSize;
  final double textSize;
  final double gap;
  final Color iconBackgroundColor;
  final Color textColor;

  const BrandLockup({
    super.key,
    this.iconSize = 26,
    this.textSize = 24,
    this.gap = 8,
    this.iconBackgroundColor = const Color(0xFF2F6B57),
    this.textColor = const Color(0xFF1F4B3D),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: iconBackgroundColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/branding/yoliva/icon-routepin-asphalt-soft-curve-app.svg',
            width: iconSize * 0.76,
            height: iconSize * 0.76,
            fit: BoxFit.contain,
            semanticsLabel: 'Yoliva',
          ),
        ),
        SizedBox(width: gap),
        Text(
          'Yoliva',
          style: GoogleFonts.manrope(
            color: textColor,
            fontSize: textSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1,
          ),
        ),
      ],
    );
  }
}
