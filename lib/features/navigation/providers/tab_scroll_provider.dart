import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestañas de la barra inferior de Android/iOS, en su orden.
enum MobileTab { home, services, booking, profile }

/// El scroll principal de cada pestaña. Con él, la barra la devuelve a su
/// comienzo al tocar la pestaña activa (spec 003, RF-4) e Inicio abre
/// Servicios desde arriba (RF-7).
final tabScrollControllerProvider =
    Provider.family<ScrollController, MobileTab>((ref, tab) {
      final controller = ScrollController();
      ref.onDispose(controller.dispose);
      return controller;
    });
