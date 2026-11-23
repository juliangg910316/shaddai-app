import 'dart:async';

import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/repositories/push_repository.dart';

/// Un dispositivo registrado en el fake.
typedef FakePushDevice = ({String uid, String fid, String platform});

/// Repositorio de push en memoria (spec 011, plan D-11, D-15): nunca toca
/// `firebase_messaging` ni Firestore. Los helpers de los tests lo ponen por
/// defecto, con el permiso concedido, así que ningún test ve la explicación
/// del permiso sin pedirlo.
///
/// Registra cada llamada en [calls], puede fallar ([registerError],
/// [registerDeviceError], [unregisterError], [unregisterDeviceError]) o
/// esperar a una puerta ([unregisterDeviceGate]), y emite a mano los avisos
/// ([openNotice], [receiveNotice]) y los FID nuevos ([emitRegistered]).
class FakePushRepository implements PushRepository {
  FakePushRepository({
    this.currentPermission = PushPermission.granted,
    this.answer = PushPermission.granted,
    this.fid = 'fid-1',
    this.initial,
    bool permissionAsked = false,
    this._pendingUnregister = false,
    String? registeredOwner,
  }) : _asked = permissionAsked,
       _owner = registeredOwner;

  /// Lo que devuelve [permission].
  PushPermission currentPermission;

  /// Lo que la persona contesta al diálogo del sistema ([requestPermission]).
  PushPermission answer;

  /// El FID que da [register]; `null` si FCM no lo da a tiempo.
  String? fid;

  /// El aviso que abrió la app ([initialNotice]).
  PushNotice? initial;

  /// Cada llamada, por su nombre (`register`, `registerDevice`,
  /// `unregister`, `unregisterDevice`…).
  final calls = <String>[];

  /// Los dispositivos registrados, como en `users/{uid}/pushDevices`.
  final devices = <FakePushDevice>[];

  /// Si está alta en FCM (entre [register] y [unregister]).
  bool registeredInFcm = false;

  Object? registerError;
  Object? registerDeviceError;
  Object? unregisterError;
  Object? unregisterDeviceError;

  /// Si está, [unregisterDevice] espera a que se complete.
  Completer<void>? unregisterDeviceGate;

  bool _asked;
  bool _pendingUnregister;
  String? _owner;

  final _registered = StreamController<String>.broadcast();
  final _opened = StreamController<PushNotice>.broadcast();
  final _foreground = StreamController<PushNotice>.broadcast();

  /// FCM da otro FID al dispositivo (RF-21).
  void emitRegistered(String newFid) {
    fid = newFid;
    _registered.add(newFid);
  }

  /// La admin toca un aviso con la app en segundo plano.
  void openNotice(PushNotice notice) => _opened.add(notice);

  /// Llega un aviso con la app en primer plano.
  void receiveNotice(PushNotice notice) => _foreground.add(notice);

  Future<void> dispose() async {
    await _registered.close();
    await _opened.close();
    await _foreground.close();
  }

  @override
  Future<PushPermission> permission() async {
    calls.add('permission');
    return currentPermission;
  }

  @override
  Future<PushPermission> requestPermission() async {
    calls.add('requestPermission');
    _asked = true;
    currentPermission = answer;
    return answer;
  }

  @override
  bool get permissionAsked => _asked;

  @override
  Future<void> markPermissionAsked() async => _asked = true;

  @override
  Future<String?> register() async {
    calls.add('register');
    if (registerError != null) throw registerError!;
    registeredInFcm = true;
    return fid;
  }

  @override
  Stream<String> get onRegistered => _registered.stream;

  @override
  Future<void> unregister() async {
    calls.add('unregister');
    if (unregisterError != null) throw unregisterError!;
    registeredInFcm = false;
  }

  @override
  Future<void> registerDevice(String uid, String fid, String platform) async {
    calls.add('registerDevice');
    if (registerDeviceError != null) throw registerDeviceError!;
    devices.removeWhere((d) => d.uid == uid && d.fid == fid);
    devices.add((uid: uid, fid: fid, platform: platform));
  }

  @override
  Future<void> unregisterDevice(String uid, String fid) async {
    calls.add('unregisterDevice');
    await unregisterDeviceGate?.future;
    if (unregisterDeviceError != null) throw unregisterDeviceError!;
    devices.removeWhere((d) => d.uid == uid && d.fid == fid);
  }

  @override
  bool get pendingUnregister => _pendingUnregister;

  @override
  Future<void> setPendingUnregister(bool value) async =>
      _pendingUnregister = value;

  @override
  String? get registeredOwner => _owner;

  @override
  Future<void> setRegisteredOwner(String? uid) async => _owner = uid;

  @override
  Future<PushNotice?> initialNotice() async {
    calls.add('initialNotice');
    final notice = initial;
    initial = null;
    return notice;
  }

  @override
  Stream<PushNotice> get onNoticeOpened => _opened.stream;

  @override
  Stream<PushNotice> get onForegroundNotice => _foreground.stream;
}
