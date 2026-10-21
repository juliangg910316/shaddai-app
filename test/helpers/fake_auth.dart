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
class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.stored, this.error});

  final UserModel? stored;
  final Object? error;
  final saved = <UserModel>[];

  @override
  Future<UserModel?> getUser(String uid) async {
    if (error != null) throw error!;
    return stored;
  }

  @override
  Future<void> saveUser(UserModel user) async => saved.add(user);

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
