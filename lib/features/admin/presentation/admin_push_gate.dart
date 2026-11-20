import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../logic/push_notices.dart';
import '../providers/admin_push_provider.dart';
import 'admin_push_dialog.dart';

/// Los avisos push de la admin en la app (spec 011, plan § 6). Envuelve toda
/// la app, sin interfaz propia: arranca [AdminPushController] y, cuando toca,
/// explica los avisos y pide el permiso (RF-15).
///
/// Solo en Android/iOS: en Web devuelve [child] sin más y no toca nada
/// (Plataformas).
class AdminPushGate extends ConsumerWidget {
  const AdminPushGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isWebProvider)) return child;
    return _MobilePushGate(child: child);
  }
}

class _MobilePushGate extends ConsumerStatefulWidget {
  const _MobilePushGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_MobilePushGate> createState() => _MobilePushGateState();
}

class _MobilePushGateState extends ConsumerState<_MobilePushGate> {
  /// La explicación sale una vez por ejecución de la app (plan § 6).
  bool _explained = false;

  @override
  void initState() {
    super.initState();
    // Fuera del build: arrancar cambia providers.
    Future.microtask(() {
      if (mounted) ref.read(adminPushControllerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el controlador: sin oyentes, Riverpod lo pausa.
    ref.watch(adminPushControllerProvider);
    final explain = shouldExplainPush(
      isWeb: false,
      user: ref.watch(currentUserProvider).value,
      permission: ref.watch(pushPermissionProvider),
    );
    if (explain && !_explained) {
      _explained = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _explain());
    }
    return widget.child;
  }

  Future<void> _explain() async {
    final navigator = ref
        .read(goRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (!mounted || navigator == null) return;
    await showAdminPushDialog(navigator);
    if (!mounted) return;
    await ref.read(adminPushControllerProvider).requestPermission();
  }
}
