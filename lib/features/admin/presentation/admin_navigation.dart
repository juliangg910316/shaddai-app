import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';

/// Abre la edición del turno [id] desde el panel (spec 008, D-5). En Web con
/// `go`, para que la edición tenga su dirección y "atrás" del navegador
/// salga de ella; en Android/iOS con `push`, como las demás páginas del
/// panel.
void openAdminEdit(BuildContext context, WidgetRef ref, String id) {
  final location = '/admin/appointments/$id/edit';
  if (ref.read(isWebProvider)) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Sale de la edición de un turno a la agenda (spec 008, RF-28, RF-30,
/// RF-35): en Android/iOS vuelve atrás si se llegó desde el panel; si no, y
/// en Web, va a `/admin`.
void closeAdminEdit(BuildContext context, WidgetRef ref) {
  if (!ref.read(isWebProvider) && context.canPop()) {
    context.pop();
  } else {
    context.go('/admin');
  }
}
