import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';

/// Firebase Auth avisa de la sesión en cuanto se inicia, antes de que la app
/// cree la ficha en Firestore.
class _SessionAuthRepository extends FakeAuthRepository {
  _SessionAuthRepository(User user)
    : super(credential: FakeUserCredential(user));

  final sessions = StreamController<User?>.broadcast();

  /// Lo que pasa en la app entre el aviso de sesión y el final del inicio.
  Future<void> Function() whileSigningIn = () async {};

  @override
  Stream<User?> get authStateChanges => sessions.stream;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    sessions.add(credential!.user);
    await whileSigningIn();
    return credential;
  }
}

/// Fichas en memoria: `getUser` devuelve lo que se ha guardado.
class _MemoryUserRepository extends FakeUserRepository {
  final docs = <String, UserModel>{};

  @override
  Future<UserModel?> getUser(String uid) async => docs[uid];

  @override
  Future<void> saveUser(UserModel user) async => docs[user.uid] = user;
}

void main() {
  test('la primera vez que entra una cuenta, se lee la ficha recién creada '
      'y se le pide el WhatsApp', () async {
    final auth = _SessionAuthRepository(FakeFirebaseUser('u-nueva'));
    final users = _MemoryUserRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.sessions.close);
    container.listen(currentUserProvider, (_, _) {});
    // La app lee la ficha, que aún no existe, antes de que se cree.
    auth.whileSigningIn = () async {
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(currentUserProvider.future), isNull);
    };

    await container.read(authControllerProvider.notifier).signInWithGoogle();

    final user = await container.read(currentUserProvider.future);
    expect(user?.uid, 'u-nueva');
    expect(user?.phoneNumber, isNull);
  });
}
