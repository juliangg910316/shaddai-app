import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/admin/providers/admin_push_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_push.dart';

/// Cerrar sesión da de baja el dispositivo de la admin antes de salir, y sale
/// igual si eso falla o tarda (spec 011, RF-20, RF-25, plan D-7, T5).
/// Una sesión que registra el orden de las llamadas.
class _RecordingAuthRepository extends FakeAuthRepository {
  _RecordingAuthRepository(this.log);

  final List<String> log;

  @override
  Future<void> signOut() async {
    log.add('signOut');
    await super.signOut();
  }
}

void main() {
  test(
    'primero la baja del dispositivo y después el cierre de sesión',
    () async {
      final log = <String>[];
      final auth = _RecordingAuthRepository(log);
      final controller = AuthController(
        auth,
        FakeUserRepository(),
        beforeSignOut: () async => log.add('unregister'),
      );
      addTearDown(controller.dispose);

      await controller.signOut();
      expect(log, ['unregister', 'signOut']);
    },
  );

  test(
    'si la baja falla, la sesión se cierra igual y sin error (RF-25)',
    () async {
      final auth = FakeAuthRepository();
      final controller = AuthController(
        auth,
        FakeUserRepository(),
        beforeSignOut: () async => throw StateError('sin red'),
      );
      addTearDown(controller.dispose);

      await controller.signOut();
      expect(auth.signOutCalls, 1);
    },
  );

  test('si la baja tarda más de lo previsto, la sesión se cierra igual '
      '(RF-25)', () async {
    final auth = FakeAuthRepository();
    final never = Completer<void>();
    final controller = AuthController(
      auth,
      FakeUserRepository(),
      beforeSignOut: () => never.future,
      beforeSignOutTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.signOut();
    expect(auth.signOutCalls, 1);
  });

  test('lo previsto son 5 segundos', () {
    expect(
      AuthController.defaultBeforeSignOutTimeout,
      const Duration(seconds: 5),
    );
  });

  test('el provider da de baja el dispositivo de la admin al cerrar '
      'sesión', () async {
    final auth = FakeAuthRepository();
    // Un dispositivo que quedó registrado de una sesión anterior.
    final push = FakePushRepository(registeredOwner: 'beidis')
      ..registeredInFcm = true;
    addTearDown(push.dispose);
    final container = ProviderContainer(
      overrides: [
        isWebProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        pushRepositoryProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).signOut();
    expect(push.calls, contains('unregister'));
    expect(push.registeredInFcm, isFalse);
    expect(push.registeredOwner, isNull);
    expect(auth.signOutCalls, 1);
  });
}
