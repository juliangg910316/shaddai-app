import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/push_notice.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/push_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../logic/push_notices.dart';
import 'admin_provider.dart';

/// El repositorio de los avisos push (spec 011, plan D-11). `main` lo
/// sustituye por uno con el almacenamiento del dispositivo; los tests, por
/// `FakePushRepository`.
final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(),
);

/// El permiso de notificaciones de este dispositivo, solo para la admin en
/// Android/iOS; `null` mientras no se sabe. Se lee al arrancar, al cambiar
/// de sesión y al volver a primer plano (plan § 6).
final pushPermissionProvider = StateProvider<PushPermission?>((ref) => null);

/// El controlador de los avisos push de la admin (plan § 6).
final adminPushControllerProvider = Provider<AdminPushController>((ref) {
  final controller = AdminPushController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Registra el dispositivo de la admin para recibir avisos, lo vuelve a
/// registrar cuando hace falta y lo da de baja al cerrar sesión (spec 011,
/// RF-16, RF-18 a RF-21, RF-25; plan D-7, D-15, § 6). También abre la agenda
/// del día de un aviso tocado y pasa a la puerta los que llegan con la app
/// abierta (RF-12 a RF-14; plan D-9, D-10).
///
/// En Web no hace nada (Plataformas). Con una clienta o sin sesión no toca
/// el repositorio, salvo para repetir una baja pendiente de la admin (D-7).
/// Nunca lanza: los fallos van a `debugPrint` y se reintentan la próxima vez
/// que se abra la app o vuelva a primer plano (RF-25).
class AdminPushController {
  AdminPushController(this._ref);

  final Ref _ref;
  bool _started = false;

  /// El aviso que abrió la app solo se mira con la primera sesión conocida:
  /// si no es de la admin, se descarta (RF-13).
  bool _initialHandled = false;

  final List<StreamSubscription<Object>> _subscriptions = [];

  /// Los avisos que llegan con la app abierta, solo con la sesión de la
  /// admin (RF-13, RF-14).
  final _foreground = StreamController<PushNotice>.broadcast();

  /// Cuánto se espera a saber quién tiene la sesión antes de abrir un aviso
  /// (plan D-10).
  static const sessionTimeout = Duration(seconds: 10);

  /// El FID que este dispositivo registró en esta ejecución.
  String? _fid;

  /// Las tareas van en fila, para que dos registros no se crucen.
  Future<void> _queue = Future.value();

  PushRepository get _repository => _ref.read(pushRepositoryProvider);
  bool get _isWeb => _ref.read(isWebProvider);
  UserModel? get _user => _ref.read(currentUserProvider).value;
  bool _isAdmin(UserModel? user) => !_isWeb && user?.role == 'admin';

  static String get _platform =>
      PushRepository.platformName(defaultTargetPlatform);

  /// Empieza a seguir la sesión y los FID de FCM. Se llama una vez al montar
  /// la app; las siguientes llamadas no hacen nada.
  void start() {
    if (_isWeb || _started) return;
    _started = true;
    _ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      // Sin dato aún, nada: se espera a saber quién es (como el router).
      if (next.isLoading && !next.hasValue) return;
      _enqueue(() => _onUser(next.value));
      if (!_initialHandled) {
        _initialHandled = true;
        if (_isAdmin(next.value)) unawaited(_openInitial());
      }
    }, fireImmediately: true);
    final repository = _repository;
    _subscriptions.addAll([
      repository.onRegistered.listen(
        (fid) => _enqueue(() => _registerFid(fid)),
      ),
      repository.onNoticeOpened.listen(open),
      repository.onForegroundNotice.listen((notice) {
        if (_isAdmin(_user)) _foreground.add(notice);
      }),
    ]);
  }

  /// Los avisos que llegan con la app abierta y la sesión de la admin: la
  /// puerta los muestra (RF-14).
  Stream<PushNotice> get foregroundNotices => _foreground.stream;

  /// Abre la agenda en el día del turno de [notice] (RF-12). Espera a saber
  /// quién tiene la sesión; si no es la admin o el día no vale, no hace nada
  /// (RF-13). Si la agenda no está arriba, la abre encima, para que "atrás"
  /// vuelva a donde estaba (plan D-10). Nunca lanza.
  Future<void> open(PushNotice notice) async {
    if (_isWeb) return;
    try {
      final user = await _sessionUser();
      final day = noticeDay(notice.data);
      if (!_isAdmin(user) || day == null) return;
      _ref.read(adminSelectedDateProvider.notifier).state = day;
      final router = _ref.read(goRouterProvider);
      // `push` deja la dirección como estaba y pone la página encima: lo que
      // cuenta es la página de arriba.
      final pages = router.routerDelegate.currentConfiguration;
      if (pages.isEmpty || pages.last.matchedLocation != '/admin') {
        unawaited(router.push('/admin'));
      }
    } catch (e) {
      debugPrint('No se pudo abrir el aviso: $e');
    }
  }

  /// Vuelve a leer el permiso y registra el dispositivo si toca: al volver a
  /// primer plano, por si se activó en los ajustes (RF-18).
  Future<void> sync() => _isWeb ? Future.value() : _enqueue(_sync);

  /// Tras la explicación: pide el permiso del sistema y, si se concede,
  /// registra el dispositivo (RF-15, RF-17, RF-18).
  Future<void> requestPermission() {
    if (!_isAdmin(_user)) return Future.value();
    return _enqueue(() async {
      _setPermission(await _repository.requestPermission());
      await _sync();
    });
  }

  /// Al cerrar sesión: borra el registro y da de baja el dispositivo en FCM.
  /// Si algo falla, deja la marca de baja pendiente (RF-20, RF-25, D-7).
  /// Nunca lanza. No espera a la fila: la sesión no debe esperar.
  Future<void> unregister() async {
    if (_isWeb) return;
    final repository = _repository;
    final owner = repository.registeredOwner;
    final user = _user;
    // Una clienta o un visitante nunca registraron nada (RF-16).
    if (owner == null && !_isAdmin(user)) return;
    try {
      final fid = _fid;
      final uid = owner ?? user!.uid;
      if (fid != null) await repository.unregisterDevice(uid, fid);
      await repository.unregister();
      _fid = null;
      await repository.setRegisteredOwner(null);
      await repository.setPendingUnregister(false);
    } catch (e) {
      debugPrint('No se pudo dar de baja el dispositivo: $e');
      await repository.setPendingUnregister(true);
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _foreground.close();
  }

  Future<void> _openInitial() async {
    try {
      final notice = await _repository.initialNotice();
      if (notice != null) await open(notice);
    } catch (e) {
      debugPrint('No se pudo leer el aviso que abrió la app: $e');
    }
  }

  /// La sesión, cuando se sabe (como mucho [sessionTimeout]).
  Future<UserModel?> _sessionUser() async {
    final current = _ref.read(currentUserProvider);
    if (!current.isLoading || current.hasValue) return current.value;
    return _ref.read(currentUserProvider.future).timeout(sessionTimeout);
  }

  Future<void> _enqueue(Future<void> Function() task) {
    return _queue = _queue.then((_) async {
      try {
        await task();
      } catch (e) {
        debugPrint('Avisos push: $e');
      }
    });
  }

  /// Cambió la sesión: repite la baja pendiente si ya no es de admin (D-7)
  /// y registra el dispositivo si lo es.
  Future<void> _onUser(UserModel? user) async {
    final repository = _repository;
    if (shouldRetryUnregister(
      pendingUnregister: repository.pendingUnregister,
      user: user,
    )) {
      await repository.unregister();
      await repository.setRegisteredOwner(null);
      await repository.setPendingUnregister(false);
    }
    await _sync();
  }

  Future<void> _sync() async {
    final user = _user;
    if (!_isAdmin(user)) return;
    _setPermission(await _repository.permission());
    if (!_shouldRegister(user)) return;
    final fid = await _repository.register();
    if (fid != null) await _registerFid(fid);
  }

  bool _shouldRegister(UserModel? user) => shouldRegisterDevice(
    isWeb: _isWeb,
    user: user,
    permission: _ref.read(pushPermissionProvider),
  );

  /// Guarda [fid] como dispositivo de la admin, si no lo estaba ya (RF-19,
  /// RF-21).
  Future<void> _registerFid(String fid) async {
    final user = _user;
    if (user == null || !_shouldRegister(user)) return;
    final repository = _repository;
    if (fid == _fid && repository.registeredOwner == user.uid) return;
    await repository.registerDevice(user.uid, fid, _platform);
    _fid = fid;
    await repository.setRegisteredOwner(user.uid);
    await repository.setPendingUnregister(false);
  }

  void _setPermission(PushPermission permission) {
    _ref.read(pushPermissionProvider.notifier).state = permission;
  }
}
