import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';

/// El título de una parte de la reserva ("Fecha", "Hora"…). Es un
/// encabezado con su propio nodo de semántica: el lector de pantalla puede
/// saltar de una parte a otra, y el nodo mide solo el texto (RNF-2).
class BookingSectionTitle extends StatelessWidget {
  const BookingSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    child: Text(
      text,
      style: AppText.eyebrow(
        size: 12,
        weight: FontWeight.w600,
        color: context.brand.inkMuted,
      ),
    ),
  );
}
