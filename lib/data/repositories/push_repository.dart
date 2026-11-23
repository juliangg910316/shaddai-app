import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/push_notice.dart';

/// Los avisos push de la admin en este dispositivo (spec 011, plan D-1,
/// D-7, D-8, D-11, D-15): el permiso, el alta y la baja en FCM con el FID
/// (Firebase Installation ID), el registro del dispositivo en
/// `users/{uid}/pushDevices/{fid}` y los avisos recibidos.
///
/// Es la única parte de la app que toca `firebase_messaging`. No lo toca
/// hasta que se usa: construirlo en Web o en un test no inicia nada. Las
/// marcas que guarda en el dispositivo nunca lanzan: si el almacenamiento
/// falla, se leen vacías (RF-25).
class PushRepository {
  PushRepository({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    this._store,
  }) : _messagingOverride = messaging,
       _firestoreOverride = firestore;

  // Sin valor por defecto en el constructor: `.instance` se lee al usarlos.
  final FirebaseMessaging? _messagingOverride;
  final FirebaseFirestore? _firestoreOverride;

  /// El almacenamiento del dispositivo (se pasa como `store:`).
  final SharedPreferences? _store;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const _askedKey = 'pushPermissionAsked';
  static const _pendingUnregisterKey = 'pushPendingUnregister';
  static const _ownerKey = 'pushDeviceOwner';

  // Permiso -----------------------------------------------------------------

  /// El permiso de la app: junta el del sistema con la marca de que ya se
  /// preguntó, porque Android no distingue "nunca preguntado" de "denegado"
  /// (plan D-8).
  static PushPermission permissionFrom(
    AuthorizationStatus status, {
    required bool asked,
  }) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.notDetermined => PushPermission.notAsked,
    AuthorizationStatus.denied =>
      asked ? PushPermission.denied : PushPermission.notAsked,
    // El sistema ya no deja volver a preguntar: denegado aunque falte la
    // marca (por ejemplo, tras reinstalar la app).
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
  };

  /// El permiso de ahora.
  Future<PushPermission> permission() async {
    final settings = await _messaging.getNotificationSettings();
    return permissionFrom(settings.authorizationStatus, asked: permissionAsked);
  }

  /// Pide el permiso del sistema y lo devuelve; desde entonces consta que ya
  /// se preguntó (RF-15, RF-17).
  Future<PushPermission> requestPermission() async {
    await markPermissionAsked();
    final settings = await _messaging.requestPermission();
    return permissionFrom(settings.authorizationStatus, asked: true);
  }

  /// Si ya se pidió el permiso en este dispositivo.
  bool get permissionAsked => _readBool(_askedKey);

  Future<void> markPermissionAsked() => _write(_askedKey, true);

  // Alta, baja y registro -------------------------------------------------

  /// El nombre de [platform] que se guarda con el dispositivo.
  static String platformName(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Cuánto se espera a que FCM dé el FID tras darse de alta.
  static const registerTimeout = Duration(seconds: 20);

  /// El primer FID que llega por [registered] tras llamar a [register], o
  /// `null` si no llega en [timeout]. Escucha antes de llamar, para no perder
  /// uno que llegue durante la llamada; si [register] falla, lanza su error.
  static Future<String?> firstFid({
    required Stream<String> registered,
    required Future<void> Function() register,
    Duration timeout = registerTimeout,
  }) async {
    final first = registered.first.timeout(timeout);
    // Si [register] falla, nadie espera ya a [first]: que su error de tiempo
    // no quede sin atender.
    first.ignore();
    await register();
    try {
      return await first;
    } on TimeoutException {
      return null;
    } on StateError {
      return null; // El stream se cerró sin dar ninguno.
    }
  }

  /// Da de alta este dispositivo en FCM y devuelve su FID, o `null` si FCM
  /// no lo da a tiempo (RF-18, RF-25).
  Future<String?> register() => firstFid(
    registered: _messaging.onRegistered,
    register: _messaging.register,
  );

  /// El FID cada vez que FCM da de alta el dispositivo, también si cambia
  /// (RF-21).
  Stream<String> get onRegistered => _messaging.onRegistered;

  /// Da de baja el dispositivo en FCM: los avisos que se le envíen fallarán
  /// y el servidor borrará su registro (RF-20, plan D-5, D-7).
  Future<void> unregister() => _messaging.unregister();

  DocumentReference<Map<String, dynamic>> _device(String uid, String fid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('pushDevices')
          .doc(fid);

  /// Registra este dispositivo de [uid] para recibir avisos (RF-18, RF-19).
  /// Las reglas exigen que `updatedAt` sea la hora del servidor.
  Future<void> registerDevice(String uid, String fid, String platform) =>
      _device(uid, fid).set({
        'fid': fid,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Quita el registro de este dispositivo (RF-20).
  Future<void> unregisterDevice(String uid, String fid) =>
      _device(uid, fid).delete();

  /// Si queda una baja en FCM de un cierre de sesión que falló (D-7).
  bool get pendingUnregister => _readBool(_pendingUnregisterKey);

  Future<void> setPendingUnregister(bool value) =>
      _write(_pendingUnregisterKey, value);

  /// La admin cuyo registro tiene este dispositivo, si alguna.
  String? get registeredOwner {
    try {
      return _store?.getString(_ownerKey);
    } catch (e) {
      debugPrint('No se pudo leer "$_ownerKey": $e');
      return null;
    }
  }

  Future<void> setRegisteredOwner(String? uid) async {
    try {
      if (uid == null) {
        await _store?.remove(_ownerKey);
      } else {
        await _store?.setString(_ownerKey, uid);
      }
    } catch (e) {
      debugPrint('No se pudo guardar "$_ownerKey": $e');
    }
  }

  // Avisos ------------------------------------------------------------------

  static PushNotice _notice(RemoteMessage message) => PushNotice.fromParts(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );

  /// El aviso que abrió la app estando cerrada, si fue uno (RF-12).
  Future<PushNotice?> initialNotice() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _notice(message);
  }

  /// Los avisos que se tocan con la app en segundo plano (RF-12).
  Stream<PushNotice> get onNoticeOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_notice);

  /// Los avisos que llegan con la app en primer plano (RF-14).
  Stream<PushNotice> get onForegroundNotice =>
      FirebaseMessaging.onMessage.map(_notice);

  // Almacenamiento ----------------------------------------------------------

  bool _readBool(String key) {
    try {
      return _store?.getBool(key) ?? false;
    } catch (e) {
      debugPrint('No se pudo leer "$key": $e');
      return false;
    }
  }

  Future<void> _write(String key, bool value) async {
    try {
      await _store?.setBool(key, value);
    } catch (e) {
      debugPrint('No se pudo guardar "$key": $e');
    }
  }
}
