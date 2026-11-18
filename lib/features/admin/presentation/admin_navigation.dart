import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';

/// Abre la página [location] del panel: en Web con `go`, para que tenga su
/// dirección y la de debajo siga montada (rutas anidadas); en Android/iOS
/// con `push` (spec 008, Navegación).
void openAdminPage(BuildContext context, WidgetRef ref, String location) {
  if (ref.read(isWebProvider)) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// El formulario de un cierre nuevo: la edición abierta desde sus turnos
/// que chocan vuelve a él (spec 008, Navegación).
const closureFormPath = '/admin/closures/new';

/// Abre la edición del turno [id] desde la agenda o, con [fromClosure],
/// desde los turnos que chocan con un cierre (spec 008, D-5). En Web con
/// `go`, para que la edición tenga su dirección y "atrás" del navegador
/// salga de ella; desde un cierre, como ruta hija del formulario, que sigue
/// debajo con lo elegido. En Android/iOS con `push`, como las demás páginas
/// del panel.
void openAdminEdit(
  BuildContext context,
  WidgetRef ref,
  String id, {
  bool fromClosure = false,
}) {
  if (ref.read(isWebProvider)) {
    final base = fromClosure ? closureFormPath : '/admin';
    context.go('$base/appointments/$id/edit');
  } else {
    context.push('/admin/appointments/$id/edit');
  }
}

/// Sale de la edición de un turno a donde se abrió (spec 008, RF-28, RF-30,
/// RF-35, Navegación): en Android/iOS vuelve atrás si puede; en Web, al
/// cierre si se abrió desde él y, si no, a la agenda (`/admin`).
void closeAdminEdit(BuildContext context, WidgetRef ref) {
  if (!ref.read(isWebProvider) && context.canPop()) {
    context.pop();
  } else if (GoRouterState.of(context).uri.path
      .startsWith('$closureFormPath/')) {
    context.go(closureFormPath);
  } else {
    context.go('/admin');
  }
}
