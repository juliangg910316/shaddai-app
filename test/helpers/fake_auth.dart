import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/auth_repository.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';
import 'package:shaddai/data/repositories/user_repository.dart';

/// Usuario de Firebase Auth falso: solo los campos que lee la app.
class FakeFirebaseUser implements User {
  FakeFirebaseUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => 'ana@example.com';

  @override
  String? get displayName => 'Ana Herrera';

  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Inicio de sesión con Google falso. [credential] es lo que devuelve; `null`
/// es lo que devuelve el repositorio real cuando se cancela.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.credential});

  final UserCredential? credential;
  int signOutCalls = 0;

  @override
  Future<UserCredential?> signInWithGoogle() async => credential;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Usuarias en memoria. Si [error] no es nulo, `getUser` lo lanza.
///
/// Para la admin (spec 007): [users] son todas las fichas, en vivo
/// ([emitUsers], [failUsers]); `fetchUser` lee de [serverUsers] (por
/// defecto, [users]) o lanza [fetchError].
class FakeUserRepository implements UserRepository {
  FakeUserRepository({
    this.stored,
    this.error,
    this.users = const [],
    this.serverUsers,
  });

  final UserModel? stored;
  final Object? error;
  final saved = <UserModel>[];

  /// La ficha que envía [watchUser] ahora: empieza en [stored] y cambia con
  /// [updateWhatsApp] (spec 009).
  late UserModel? live = stored;
  final _userListeners = <StreamController<UserModel?>>[];

  /// Cambios de WhatsApp guardados con [updateWhatsApp], en orden.
  final whatsAppUpdates =
      <({String uid, String phone, String? activeAppointmentId})>[];

  /// Si está, [updateWhatsApp] lo lanza sin cambiar nada.
  Object? whatsAppError;

  /// Si está, [updateWhatsApp] espera a que termine antes de guardar.
  Future<void>? whatsAppGate;

  List<UserModel> users;
  List<UserModel>? serverUsers;
  Object? fetchError;
  final fetchRequests = <String>[];
  final _usersListeners = <StreamController<List<UserModel>>>[];

  void emitUsers(List<UserModel> value) {
    users = value;
    for (final listener in List.of(_usersListeners)) {
      listener.add(value);
    }
  }

  void failUsers(Object error) {
    for (final listener in List.of(_usersListeners)) {
      listener.addError(error);
    }
  }

  @override
  Stream<List<UserModel>> getAllUsers() {
    late final StreamController<List<UserModel>> controller;
    controller = StreamController<List<UserModel>>(
      onListen: () => controller.add(users),
      onCancel: () => _usersListeners.remove(controller),
    );
    _usersListeners.add(controller);
    return controller.stream;
  }

  @override
  Future<UserModel?> fetchUser(String uid) async {
    fetchRequests.add(uid);
    final error = fetchError;
    if (error != null) throw error;
    return (serverUsers ?? users).where((u) => u.uid == uid).firstOrNull;
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    if (error != null) throw error!;
    return stored;
  }

  /// La ficha en vivo: [live] y cada cambio, o [error].
  @override
  Stream<UserModel?> watchUser(String uid) {
    if (error != null) return Stream.error(error!);
    late final StreamController<UserModel?> controller;
    controller = StreamController<UserModel?>(
      onListen: () => controller.add(live),
      onCancel: () => _userListeners.remove(controller),
    );
    _userListeners.add(controller);
    return controller.stream;
  }

  @override
  Future<void> updateWhatsApp({
    required String uid,
    required String phone,
    String? activeAppointmentId,
  }) async {
    final gate = whatsAppGate;
    if (gate != null) await gate;
    final failure = whatsAppError;
    if (failure != null) throw failure;
    whatsAppUpdates.add((
      uid: uid,
      phone: phone,
      activeAppointmentId: activeAppointmentId,
    ));
    final user = live;
    if (user != null) {
      live = user.copyWith(phoneNumber: phone);
      for (final listener in List.of(_userListeners)) {
        listener.add(live);
      }
    }
  }

  @override
  Future<void> saveUser(UserModel user) async => saved.add(user);

  /// Números guardados con [updatePhoneNumber], en orden.
  final phoneUpdates = <({String uid, String phone})>[];

  @override
  Future<void> updatePhoneNumber(String uid, String phoneNumber) async =>
      phoneUpdates.add((uid: uid, phone: phoneNumber));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reservas que siempre fallan al crearse, con un error técnico.
class FailingBookingRepository implements BookingRepository {
  @override
  Future<void> createAppointment(AppointmentModel appointment) async =>
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reservas en memoria: guarda las que se crean.
class RecordingBookingRepository implements BookingRepository {
  final created = <AppointmentModel>[];

  @override
  Future<void> createAppointment(AppointmentModel appointment) async =>
      created.add(appointment);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
