import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';

/// Imagen de la landing con su descripción para el lector de pantalla
/// (RNF-3). Si no carga, muestra un recuadro del color de fondo con la
/// descripción, sin romper la sección (caso límite de la spec 002).
class LandingImage extends StatelessWidget {
  const LandingImage({
    super.key,
    required this.asset,
    required this.description,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String asset;
  final String description;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ColoredBox(
      color: brand.placeholder,
      child: Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        semanticLabel: description,
        errorBuilder: (context, error, stackTrace) => Semantics(
          label: description,
          image: true,
          excludeSemantics: true,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: AppText.sans(size: 12, color: brand.inkMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
