import 'package:flutter/material.dart';
import '../constants/theme_colors.dart';

/// Iniciales de un nombre ("Ana Herrera" -> "AH").
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '·';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
      .toUpperCase();
}

/// Título de sección con la línea dorada que lo acompaña en el diseño.
class SectionHeading extends StatelessWidget {
  final String title;
  final double size;

  const SectionHeading(this.title, {super.key, this.size = 21});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppText.serif(
            size: size,
            weight: FontWeight.w500,
            color: ThemeColors.darkGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: ThemeColors.goldHairline)),
      ],
    );
  }
}

/// Título de sección con una acción tipo "VER TODO" a la derecha.
class SectionHeadingWithAction extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  const SectionHeadingWithAction(
    this.title, {
    super.key,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppText.serif(
            size: 21,
            weight: FontWeight.w500,
            color: ThemeColors.darkGreen,
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Text(
            actionLabel,
            style: AppText.eyebrow(
              size: 11,
              color: ThemeColors.gold,
              spacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar circular verde con iniciales doradas; usa la foto si existe.
class InitialsAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double size;
  final Color background;
  final Color foreground;
  final bool goldBorder;
  final bool serifInitials;

  const InitialsAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 40,
    this.background = ThemeColors.darkGreen,
    this.foreground = ThemeColors.gold,
    this.goldBorder = false,
    this.serifInitials = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: goldBorder ? Border.all(color: ThemeColors.gold) : null,
        image: photoUrl != null
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: photoUrl != null
          ? null
          : Text(
              initials,
              style: serifInitials
                  ? AppText.serif(
                      size: size * 0.36,
                      weight: FontWeight.w400,
                      color: foreground,
                    )
                  : AppText.sans(size: size * 0.34, color: foreground),
            ),
    );
  }
}

/// Botón principal dorado en píldora ("RESERVAR TURNO", "CONFIRMAR 12:00").
class GoldPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GoldPillButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeColors.gold,
          foregroundColor: ThemeColors.darkGreen,
          disabledBackgroundColor: ThemeColors.gold.withValues(alpha: 0.35),
          disabledForegroundColor: ThemeColors.darkGreen.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w600,
            spacing: 2,
            color: enabled
                ? ThemeColors.darkGreen
                : ThemeColors.darkGreen.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario: solo contorno verde, sin relleno.
class OutlinePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const OutlinePillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = ThemeColors.darkGreen,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(color: color.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 9),
            ],
            Text(
              label,
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                spacing: 2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marco vacío color arena que reemplaza una foto todavía no cargada.
class PhotoPlaceholder extends StatelessWidget {
  final String label;
  final double? height;
  final double radius;
  final Color color;

  const PhotoPlaceholder({
    super.key,
    this.label = 'FOTO',
    this.height,
    this.radius = 14,
    this.color = ThemeColors.sand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppText.eyebrow(
          size: 9,
          spacing: 1.6,
          color: ThemeColors.olive.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

/// Imagen de red con placeholder arena mientras carga o si falla.
class NetworkPhoto extends StatelessWidget {
  final String url;
  final double? height;
  final double radius;
  final String placeholderLabel;
  final Color placeholderColor;

  const NetworkPhoto({
    super.key,
    required this.url,
    this.height,
    this.radius = 14,
    this.placeholderLabel = 'FOTO',
    this.placeholderColor = ThemeColors.sand,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = PhotoPlaceholder(
      label: placeholderLabel,
      height: height,
      radius: radius,
      color: placeholderColor,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// Tarjeta plana del diseño: fondo hueso claro y borde de 1px (sin sombra).
class FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color color;
  final double radius;

  const FlatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.color = ThemeColors.white,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? ThemeColors.hairline),
      ),
      child: child,
    );
  }
}

/// Glifo de WhatsApp del diseño (burbuja + auricular), dibujado a mano para no
/// depender de un paquete de iconos extra.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({
    super.key,
    this.size = 19,
    this.color = ThemeColors.darkGreen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WhatsAppPainter(color)),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;

  const _WhatsAppPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Los trazados están definidos sobre una caja de 24x24 (viewBox del diseño).
    final scale = size.width / 24;
    canvas.scale(scale);

    const radius = Radius.circular(8);
    final bubble = Path()
      ..moveTo(20, 11.5)
      ..arcToPoint(const Offset(8.2, 18.5), radius: radius)
      ..lineTo(4, 20)
      ..lineTo(5.6, 16)
      ..arcToPoint(const Offset(20, 11.5), radius: radius, largeArc: true)
      ..close();

    final handset = Path()
      ..moveTo(8.8, 9.2)
      ..cubicTo(9.2, 11.8, 12.2, 14.8, 14.8, 15.2)
      ..lineTo(16, 13.8)
      ..lineTo(14, 12.6)
      ..lineTo(13, 13.4)
      ..cubicTo(12, 12.9, 11, 11.9, 10.5, 10.9)
      ..lineTo(11.3, 9.9)
      ..lineTo(10.1, 7.9)
      ..close();

    canvas.drawPath(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawPath(handset, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Etiqueta y color de cada estado de turno, tal como aparecen en el diseño.
class AppointmentStatusStyle {
  final String label;
  final Color color;

  const AppointmentStatusStyle(this.label, this.color);

  /// Etiquetas de la vista de cliente ("CONFIRMADA" / "EN REVISIÓN").
  static AppointmentStatusStyle forClient(String status) {
    switch (status) {
      case 'confirmed':
        return const AppointmentStatusStyle(
          'CONFIRMADA',
          ThemeColors.darkGreen,
        );
      case 'cancelled':
        return const AppointmentStatusStyle('CANCELADA', ThemeColors.danger);
      default:
        return const AppointmentStatusStyle('EN REVISIÓN', ThemeColors.gold);
    }
  }

  /// Etiquetas del panel admin ("CONFIRMADO" / "POR CONFIRMAR").
  static AppointmentStatusStyle forAdmin(String status) {
    switch (status) {
      case 'confirmed':
        return const AppointmentStatusStyle(
          'CONFIRMADO',
          ThemeColors.darkGreen,
        );
      case 'cancelled':
        return const AppointmentStatusStyle('CANCELADO', ThemeColors.danger);
      default:
        return const AppointmentStatusStyle('POR CONFIRMAR', ThemeColors.gold);
    }
  }
}
