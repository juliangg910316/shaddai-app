import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_colors.dart';
import '../../booking/providers/booking_provider.dart';
import 'web_menu_drawer.dart';
import 'web_top_bar.dart';

/// Estructura de todas las páginas de Web: la barra superior fija y, debajo,
/// la página (spec 002, RF-13). Sustituye a la barra inferior de Android/iOS.
///
/// También cierra la edición del turno cuando "atrás" o "adelante" del
/// navegador sale de la reserva (spec 006, RF-20, D-8); los enlaces de la app
/// la conservan (RF-19).
class WebShell extends ConsumerStatefulWidget {
  const WebShell({super.key, required this.child});

  /// Ancho desde el que la ventana es "amplia" (definición de la spec).
  static const wideBreakpoint = 900.0;

  /// Ancho máximo de las páginas de cuenta en ancho amplio (RF-30).
  static const accountPageMaxWidth = 640.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  final Widget child;

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GoRouteInformationProvider? _routes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routes = GoRouter.of(context).routeInformationProvider;
    if (routes != _routes) {
      _routes?.removeListener(_onRouteChanged);
      _routes = routes..addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _routes?.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// Las navegaciones de la app avisan con el estado de go_router; las del
  /// navegador, con el que guardó en su historial (plan D-8). Si el navegador
  /// sale de la reserva, la edición se cierra sin guardar (RF-20).
  void _onRouteChanged() {
    final route = _routes?.value;
    if (route == null || route.state is RouteInformationState) return;
    if (route.uri.path == '/booking') return;
    ref.read(editTargetProvider.notifier).end();
  }

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
