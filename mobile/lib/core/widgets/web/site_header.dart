import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../brand_lockup.dart';

class WebSiteHeader extends StatelessWidget {
  final bool isAuthenticated;
  final String primaryNavLabel;
  final String createTripLabel;
  final String messagesLabel;
  final VoidCallback onBrandTap;
  final VoidCallback onPrimaryNavTap;
  final VoidCallback onCreateTripTap;
  final VoidCallback onReservationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback? onMessagesTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  const WebSiteHeader({
    super.key,
    required this.isAuthenticated,
    required this.primaryNavLabel,
    this.createTripLabel = 'Yolculuk Olustur',
    this.messagesLabel = 'Mesajlar',
    required this.onBrandTap,
    required this.onPrimaryNavTap,
    required this.onCreateTripTap,
    required this.onReservationsTap,
    required this.onProfileTap,
    this.onMessagesTap,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    final actionStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: const Color(0xFF214336),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4DED8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D3A2F).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final bookingsLabel =
              constraints.maxWidth < 1160 ? 'Rezerv.' : 'Rezervasyonlar';
          final navItems = <Widget>[
            TextButton(
              onPressed: onPrimaryNavTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(primaryNavLabel, style: actionStyle),
            ),
            TextButton(
              onPressed: onCreateTripTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(createTripLabel, style: actionStyle),
            ),
          ];

          final actionItems = isAuthenticated
              ? <Widget>[
                  if (onMessagesTap != null)
                    TextButton(
                      onPressed: onMessagesTap,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(messagesLabel, style: actionStyle),
                    ),
                  TextButton(
                    onPressed: onReservationsTap,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(bookingsLabel, style: actionStyle),
                  ),
                  OutlinedButton(
                    onPressed: onProfileTap,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: Color(0xFF2F6B57)),
                      foregroundColor: const Color(0xFF2F6B57),
                    ),
                    child: Text(
                      'Profil',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]
              : <Widget>[
                  if (onMessagesTap != null)
                    TextButton(
                      onPressed: onMessagesTap,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(messagesLabel, style: actionStyle),
                    ),
                  OutlinedButton(
                    onPressed: onLoginTap,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: Color(0xFF2F6B57)),
                      foregroundColor: const Color(0xFF2F6B57),
                    ),
                    child: Text(
                      'Giris Yap',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton(
                    onPressed: onRegisterTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F6B57),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      'Kayit Ol',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onBrandTap,
                  child: const BrandLockup(
                    iconSize: 28,
                    textSize: 23,
                    gap: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [...navItems, ...actionItems],
                ),
              ],
            );
          }

          return Row(
            children: [
              InkWell(
                onTap: onBrandTap,
                child: const BrandLockup(
                  iconSize: 28,
                  textSize: 23,
                  gap: 8,
                ),
              ),
              const Spacer(),
              ...navItems,
              const SizedBox(width: 4),
              ...actionItems,
            ],
          );
        },
      ),
    );
  }
}
