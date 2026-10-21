import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import 'web_menu_drawer.dart';
import 'web_top_bar.dart';

/// Estructura de todas las páginas de Web: la barra superior fija y, debajo,
/// la página (spec 002, RF-13). Sustituye a la barra inferior de Android/iOS.
class WebShell extends StatefulWidget {
  const WebShell({super.key, required this.child});

  /// Ancho desde el que la ventana es "amplia" (definición de la spec).
  static const wideBreakpoint = 900.0;

  /// Ancho máximo de las páginas de cuenta en ancho amplio (RF-30).
  static const accountPageMaxWidth = 640.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  final Widget child;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final wide = WebShell.isWide(context);

    // Al pasar a ancho amplio con el menú lateral abierto, se cierra: sus
    // enlaces y selectores ya están en la barra.
    if (wide && (_scaffoldKey.currentState?.isEndDrawerOpen ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldKey.currentState?.closeEndDrawer();
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.brand.background,
      endDrawer: const WebMenuDrawer(),
      body: Column(
        children: [
          const WebTopBar(),
          Expanded(
            // La página va en el navegador anidado del `ShellRoute`, cuya ruta
            // bloquea la semántica de lo pintado antes en su contenedor. Con
            // un contenedor propio, la barra superior sigue siendo accesible.
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Página de cuenta de Web (inicio de sesión, WhatsApp, reserva, perfil y
/// panel): centrada y con un ancho máximo legible en ancho amplio (RF-30).
///
/// Va en cada ruta y no en [WebShell]: si se limitara el navegador entero, la
/// landing se dibujaría estrecha durante la transición al salir de ella.
class WebAccountPage extends StatelessWidget {
  const WebAccountPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.brand.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WebShell.accountPageMaxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
