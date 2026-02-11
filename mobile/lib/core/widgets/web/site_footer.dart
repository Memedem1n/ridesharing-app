import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../brand_lockup.dart';

class WebFooterLinkData {
  final String label;
  final VoidCallback onTap;

  const WebFooterLinkData({
    required this.label,
    required this.onTap,
  });
}

class WebFooterSectionData {
  final String title;
  final List<WebFooterLinkData> links;

  const WebFooterSectionData({
    required this.title,
    required this.links,
  });
}

class WebSiteFooter extends StatelessWidget {
  final List<WebFooterSectionData> sections;
  final String description;
  final String copyright;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;
  final VoidCallback onCookieTap;

  const WebSiteFooter({
    super.key,
    required this.sections,
    required this.description,
    required this.copyright,
    required this.onPrivacyTap,
    required this.onTermsTap,
    required this.onCookieTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideFooter = constraints.maxWidth >= 980;
        final twoColumnWidth = (constraints.maxWidth - 12) / 2;
        final brandBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLockup(
              iconSize: 26,
              textSize: 21,
              gap: 8,
              iconBackgroundColor: Color(0xFFEAF3EE),
              textColor: Color(0xFFEAF3EE),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFC2D6CA),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _FooterLegalButton(label: 'Gizlilik', onTap: onPrivacyTap),
                _FooterLegalButton(label: 'Kosullar', onTap: onTermsTap),
                _FooterLegalButton(label: 'Cerezler', onTap: onCookieTap),
              ],
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF163026),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF27473B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wideFooter)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: brandBlock),
                    const SizedBox(width: 24),
                    for (final section in sections) ...[
                      Expanded(
                        child: _FooterSection(
                          title: section.title,
                          links: section.links,
                        ),
                      ),
                      if (section != sections.last) const SizedBox(width: 12),
                    ],
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brandBlock,
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: [
                        for (final section in sections)
                          SizedBox(
                            width: twoColumnWidth < 240
                                ? constraints.maxWidth
                                : twoColumnWidth,
                            child: _FooterSection(
                              title: section.title,
                              links: section.links,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF355A4C), height: 1),
              const SizedBox(height: 14),
              Text(
                copyright,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFA8C2B4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FooterSection extends StatelessWidget {
  final String title;
  final List<WebFooterLinkData> links;

  const _FooterSection({
    required this.title,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: link.onTap,
              child: Text(
                link.label,
                style: GoogleFonts.inter(
                  color: const Color(0xFFC2D6CA),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterLegalButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLegalButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F4134),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF355A4C)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFFD2E4DB),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
