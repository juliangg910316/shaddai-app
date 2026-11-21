import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/push_notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../logic/push_notices.dart';
import '../providers/admin_push_provider.dart';
import 'admin_push_dialog.dart';

/// Los avisos push de la admin en la app (spec 011, plan § 6). Envuelve toda
/// la app, sin interfaz propia: arranca [AdminPushController], explica los
/// avisos y pide el permiso cuando toca (RF-15), muestra los avisos que
/// llegan con la app abierta (RF-14) y vuelve a leer el permiso al volver a
/// primer plano (RF-18).
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
  StreamSubscription<PushNotice>? _foreground;

  /// Al volver a primer plano se vuelve a leer el permiso, por si se activó
  /// o desactivó en los ajustes del teléfono (RF-17, RF-18).
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Fuera del build: arrancar cambia providers.
    Future.microtask(() {
      if (!mounted) return;
      final controller = ref.read(adminPushControllerProvider)..start();
      _foreground = controller.foregroundNotices.listen(_showNotice);
      _lifecycle = AppLifecycleListener(onResume: controller.sync);
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _foreground?.cancel();
    super.dispose();
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

  /// Un aviso con la app abierta: un `SnackBar` sobre la pantalla que esté
  /// arriba, sin interrumpir ni navegar, con "Ver" (RF-14, plan D-9). El
  /// título y el texto vienen siempre en español (RF-7).
  void _showNotice(PushNotice notice) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: _NoticeContent(
            notice: notice,
            onView: () {
              messenger.hideCurrentSnackBar();
              ref.read(adminPushControllerProvider).open(notice);
            },
          ),
        ),
      );
    SemanticsService.sendAnnouncement(
      View.of(context),
      [notice.title, notice.body].where((t) => t.isNotEmpty).join('. '),
      TextDirection.ltr,
    );
  }
}

class _NoticeContent extends StatelessWidget {
  const _NoticeContent({required this.notice, required this.onView});

  final PushNotice notice;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    // Se traduce aquí: "Ver" cambia si cambia el idioma (RC-1).
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final title = notice.title;
    final body = notice.body;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: AppText.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: brand.onBrand,
                  ),
                ),
              if (body.isNotEmpty)
                Text(body, style: AppText.sans(size: 14, color: brand.onBrand)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onView,
          style: TextButton.styleFrom(
            foregroundColor: brand.onBrand,
            minimumSize: const Size(48, 48),
          ),
          child: Semantics(
            label: l10n.adminPushViewLabel,
            excludeSemantics: true,
            child: Text(
              l10n.adminPushView,
              style: AppText.sans(
                size: 14,
                weight: FontWeight.w700,
                color: brand.onBrand,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
