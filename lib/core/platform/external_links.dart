import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace externo: WhatsApp, Google Maps, redes, teléfono o correo.
typedef ExternalLinkLauncher = Future<void> Function(Uri url);

/// Firma de `launchUrl`, para poder sustituirla en los tests.
typedef LaunchUrl =
    Future<bool> Function(
      Uri url, {
      LaunchMode mode,
      String? webOnlyWindowName,
    });

/// Esquemas que abre el sistema (llamada, correo) sin salir de la página.
const _sameTabSchemes = {'tel', 'mailto'};

/// Lanzador real. Las páginas web se abren en una pestaña nueva; `tel:` y
/// `mailto:`, en la misma. Si el navegador lo bloquea o falla, no se muestra
/// ningún error propio y la página sigue igual (spec 002, D-12).
ExternalLinkLauncher externalLinkLauncher({LaunchUrl launch = launchUrl}) {
  return (url) async {
    final sameTab = _sameTabSchemes.contains(url.scheme);
    try {
      final opened = await launch(
        url,
        mode: sameTab
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: sameTab ? '_self' : '_blank',
      );
      if (!opened) debugPrint('No se pudo abrir el enlace: $url');
    } catch (e) {
      debugPrint('Error al abrir el enlace $url: $e');
    }
  };
}

/// Lanzador de enlaces externos. Los tests lo sustituyen por uno que solo
/// registra las URLs.
final externalLinkLauncherProvider = Provider<ExternalLinkLauncher>(
  (ref) => externalLinkLauncher(),
);
