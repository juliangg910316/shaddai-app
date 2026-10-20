import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'contrast.dart';

/// Estilo de la barra de estado y de la barra de navegación del sistema
/// (Android/iOS) para un fondo dado, con los iconos que mejor contrastan con
/// él (RF-23).
SystemUiOverlayStyle systemBarsStyleFor(Color background) {
  final lightIcons = prefersLightIcons(background.toARGB32());
  final icons = lightIcons ? Brightness.light : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS no recibe el brillo de los iconos sino el del fondo.
    statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: background,
    systemNavigationBarIconBrightness: icons,
  );
}
