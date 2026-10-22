import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../landing_layout.dart';

/// Encabezado de sección de la landing: rótulo pequeño, título en serif con
/// una parte en cursiva y, opcionalmente, una nota (a la derecha en ancho
/// amplio, debajo en estrecho).
class LandingSectionHeader extends StatelessWidget {
  const LandingSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.titleEm,
    this.note,
    this.trailing,
    this.onBrandSurface = false,
  });

  final String eyebrow;
  final String title;
  final String? titleEm;
  final String? note;

  /// Elemento en el sitio de la nota (p. ej., un enlace); si hay los dos,
  /// manda este.
  final Widget? trailing;

  /// La sección va sobre `brandSurface` (crema en claro, verde en oscuro):
  /// usa sus tokens de texto.
  final bool onBrandSurface;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final wide = landingIsWide(context);
    final ink = onBrandSurface ? brand.onBrandSurface : brand.inkStrong;
    final gold = onBrandSurface ? brand.onBrandSurfaceAccent : brand.accentText;
    final muted = onBrandSurface ? brand.onBrandSurfaceMuted : brand.inkMuted;
    final titleStyle = AppText.serif(
      size: wide ? 40 : 32,
      color: ink,
      height: 1.15,
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: AppText.eyebrow(
            size: 11,
            spacing: 3,
            weight: FontWeight.w600,
            color: gold,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: titleStyle,
            children: [
              TextSpan(text: titleEm == null ? title : '$title '),
              if (titleEm != null)
                TextSpan(
                  text: titleEm,
                  style: titleStyle.copyWith(
                    fontStyle: FontStyle.italic,
                    color: gold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final note = this.note;
    final Widget? noteText =
        trailing ??
        (note == null
            ? null
            : Text(
                note,
                style: AppText.sans(size: 13, color: muted, height: 1.6),
              ));
    if (noteText == null) return heading;

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [heading, const SizedBox(height: 16), noteText],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: noteText,
        ),
      ],
    );
  }
}
