import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/company_context.dart';

/// Compact organization label (company name, optional sub-company suffix).
class OrganizationLine extends StatelessWidget {
  const OrganizationLine({
    super.key,
    required this.companyName,
    this.isSubCompany = false,
    this.icon = Icons.apartment_rounded,
    this.textColor,
    this.iconSize = 14,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
    this.maxLines = 2,
  });

  factory OrganizationLine.fromContext(
    CompanyContext context, {
    IconData icon = Icons.apartment_rounded,
    Color? textColor,
    double iconSize = 14,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    int maxLines = 2,
  }) {
    final name = context.displayCompanyName;
    return OrganizationLine(
      companyName: name,
      isSubCompany: context.isSubCompany,
      icon: icon,
      textColor: textColor,
      iconSize: iconSize,
      fontSize: fontSize,
      fontWeight: fontWeight,
      maxLines: maxLines,
    );
  }

  final String companyName;
  final bool isSubCompany;
  final IconData icon;
  final Color? textColor;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final int maxLines;

  String get _displayName {
    final trimmed = companyName.trim();
    if (trimmed.isEmpty) return '';
    if (isSubCompany && !trimmed.contains('(Sub)')) {
      return '$trimmed (Sub)';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final label = _displayName;
    if (label.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final color = textColor ?? scheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: iconSize, color: color),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1.35,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
