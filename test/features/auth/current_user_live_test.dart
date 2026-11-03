import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';

/// Sesión que el test abre y cierra.
class _SessionAuthRepository extends FakeAuthRepository {
  final sessions = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => sessions.stream;
}

/// Fichas en vivo: el test cambia la ficha y la envía con [change].
class _LiveUserRepository extends FakeUserRepository {
  final _changes = StreamController<UserModel?>.broadcast();
  final watched = <String>[];
  UserModel? current;

  void change(UserModel? user) {
    current = user;
    _changes.add(user);
  }

  @override
  Stream<UserModel?> watchUser(String uid) async* {
    watched.add(uid);
    yield current;
    yield* _changes.stream;
  }
}

final ana = UserModel(
  uid: 'u1',
  email: 'ana@example.com',
  displayName: 'Ana Herrera',
  phoneNumber: '+55 41 99999-0000',
);

void main() {
  late _SessionAuthRepository auth;
  late _LiveUserRepository users;
  late ProviderContainer container;

  setUp(() {
    auth = _SessionAuthRepository();
    users = _LiveUserRepository()..current = ana;
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    container.listen(currentUserProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    auth.sessions.close();
  });

  /// Deja llegar los avisos: la sesión pasa por `authStateProvider` y la
  /// ficha por su stream, cada uno con sus propias vueltas del bucle.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('con sesión, escucha la ficha de esa cuenta', () async {
    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();

    expect(users.watched, ['u1']);
    expect(container.read(currentUserProvider).value?.uid, 'u1');
  });

  test('un bloqueo llega sin volver a leer el provider (RF-38)', () async {
    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();
    expect(container.read(currentUserProvider).value?.isBlocked, isFalse);

    users.change(ana.copyWith(isBlocked: true));
    await settle();

    expect(container.read(currentUserProvider).value?.isBlocked, isTrue);
    expect(users.watched, ['u1'], reason: 'sin volver a suscribirse');
  });

  test('un cambio de rol también llega en vivo', () async {
    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();

    users.change(ana.copyWith(role: 'admin'));
    await settle();

    expect(container.read(currentUserProvider).value?.role, 'admin');
  });

  test('la ficha que se crea después de iniciar sesión llega sola', () async {
    users.current = null;
    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();
    expect(container.read(currentUserProvider).value, isNull);

    users.change(ana);
    await settle();

    expect(container.read(currentUserProvider).value?.uid, 'u1');
  });

  test('al cerrar la sesión vuelve a null', () async {
    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();

    auth.sessions.add(null);
    await settle();

    expect(container.read(currentUserProvider).value, isNull);
  });

  test('un error al leer la ficha llega como error', () async {
    final failing = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(error: Exception('permission-denied')),
        ),
      ],
    );
    addTearDown(failing.dispose);
    failing.listen(currentUserProvider, (_, _) {});

    auth.sessions.add(FakeFirebaseUser('u1'));
    await settle();

    expect(failing.read(currentUserProvider).hasError, isTrue);
  });
}
