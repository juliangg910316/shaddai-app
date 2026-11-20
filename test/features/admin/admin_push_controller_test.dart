import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_push_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_push.dart';

/// El controlador de los avisos push: registrar el dispositivo de la admin,
/// volver a registrarlo y darlo de baja (spec 011, plan D-7, D-15, § 6, T5).
/// Sin Firebase: [FakePushRepository].
final admin = UserModel(
  uid: 'beidis',
  email: 'beidis@example.com',
  displayName: 'Beidis',
  role: 'admin',
);

final client = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana',
);

/// Deja correr las suscripciones y los `Future` encadenados.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class Harness {
  Harness({
    this.isWeb = false,
    PushPermission permission = PushPermission.granted,
    bool pendingUnregister = false,
    String? registeredOwner,
  }) : push = FakePushRepository(
         currentPermission: permission,
         pendingUnregister: pendingUnregister,
         registeredOwner: registeredOwner,
       ) {
    container = ProviderContainer(
      overrides: [
        isWebProvider.overrideWithValue(isWeb),
        pushRepositoryProvider.overrideWithValue(push),
        currentUserProvider.overrideWith((ref) => users.stream),
      ],
    );
    addTearDown(container.dispose);
    // Como en la app, alguien lo escucha (la puerta, T6): sin oyentes,
    // Riverpod pausa el provider y lo que escucha.
    container.listen(adminPushControllerProvider, (_, _) {});
    addTearDown(users.close);
    addTearDown(push.dispose);
  }

  final bool isWeb;
  final FakePushRepository push;
  final users = StreamController<UserModel?>.broadcast();
  late final ProviderContainer container;

  AdminPushController get controller =>
      container.read(adminPushControllerProvider);

  /// Arranca el controlador con [user] como sesión.
  Future<void> startWith(UserModel? user) async {
    controller.start();
    await settle();
    users.add(user);
    await settle();
  }
}

void main() {
  group('registrar el dispositivo (RF-18, RF-19)', () {
    test('admin con el permiso concedido: alta en FCM y registro con su '
        'FID, y guarda la dueña', () async {
      final h = Harness();
      await h.startWith(admin);

      expect(h.push.registeredInFcm, isTrue);
      expect(h.push.devices, [
        (uid: 'beidis', fid: 'fid-1', platform: 'android'),
      ]);
      expect(h.push.registeredOwner, 'beidis');
      expect(h.container.read(pushPermissionProvider), PushPermission.granted);
    });

    test('start() dos veces no registra dos veces', () async {
      final h = Harness();
      h.controller.start();
      await h.startWith(admin);
      expect(h.push.calls.where((c) => c == 'registerDevice'), hasLength(1));
    });

    for (final permission in [PushPermission.notAsked, PushPermission.denied]) {
      test('admin con $permission: no se registra, pero se sabe el '
          'permiso', () async {
        final h = Harness(permission: permission);
        await h.startWith(admin);
        expect(h.push.devices, isEmpty);
        expect(h.push.registeredInFcm, isFalse);
        expect(h.container.read(pushPermissionProvider), permission);
      });
    }

    test('la admin entra después de arrancar la app sin sesión', () async {
      final h = Harness();
      await h.startWith(null);
      expect(h.push.devices, isEmpty);

      h.users.add(admin);
      await settle();
      expect(h.push.devices.single.uid, 'beidis');
    });
  });

  group('nada para clientas, visitantes ni Web (RF-16)', () {
    for (final (label, user) in [
      ('una clienta', client),
      ('sin sesión', null),
    ]) {
      test(label, () async {
        final h = Harness();
        await h.startWith(user);
        await h.controller.sync();
        await settle();
        expect(h.push.calls, isEmpty);
        expect(h.container.read(pushPermissionProvider), isNull);
      });
    }

    test('en Web, ni con la admin', () async {
      final h = Harness(isWeb: true);
      await h.startWith(admin);
      await h.controller.sync();
      await h.controller.unregister();
      await settle();
      expect(h.push.calls, isEmpty);
    });
  });

  group('volver a registrar (RF-18, RF-21)', () {
    test('cuando FCM da otro FID, se registra el nuevo', () async {
      final h = Harness();
      await h.startWith(admin);

      h.push.emitRegistered('fid-2');
      await settle();
      expect(h.push.devices.map((d) => d.fid), contains('fid-2'));
    });

    test('un FID nuevo con la sesión de una clienta no se registra', () async {
      final h = Harness();
      await h.startWith(client);
      h.push.emitRegistered('fid-2');
      await settle();
      expect(h.push.devices, isEmpty);
    });

    test('sync() al volver a primer plano: si se activó el permiso en los '
        'ajustes, se registra', () async {
      final h = Harness(permission: PushPermission.denied);
      await h.startWith(admin);
      expect(h.push.devices, isEmpty);

      h.push.currentPermission = PushPermission.granted;
      await h.controller.sync();
      expect(h.push.devices.single.fid, 'fid-1');
      expect(h.container.read(pushPermissionProvider), PushPermission.granted);
    });

    test('requestPermission() marca que se preguntó, pide el permiso y '
        'registra si se concede', () async {
      final h = Harness(permission: PushPermission.notAsked);
      await h.startWith(admin);

      await h.controller.requestPermission();
      expect(h.push.permissionAsked, isTrue);
      expect(h.push.calls, contains('requestPermission'));
      expect(h.push.devices.single.uid, 'beidis');
      expect(h.container.read(pushPermissionProvider), PushPermission.granted);
    });

    test('requestPermission() denegado: no registra y lo deja dicho', () async {
      final h = Harness(permission: PushPermission.notAsked)
        ..push.answer = PushPermission.denied;
      await h.startWith(admin);

      await h.controller.requestPermission();
      expect(h.push.devices, isEmpty);
      expect(h.container.read(pushPermissionProvider), PushPermission.denied);
    });
  });

  group('si algo falla, no sale y se reintenta (RF-25)', () {
    test('falla el registro: sin error, y el siguiente sync() lo '
        'consigue', () async {
      final h = Harness()..push.registerDeviceError = StateError('sin red');
      await h.startWith(admin);
      expect(h.push.devices, isEmpty);

      h.push.registerDeviceError = null;
      await h.controller.sync();
      expect(h.push.devices.single.uid, 'beidis');
    });

    test('falla el alta en FCM: sin error ni registro', () async {
      final h = Harness()..push.registerError = StateError('sin red');
      await h.startWith(admin);
      expect(h.push.devices, isEmpty);
    });

    test('FCM no da el FID a tiempo: sin error ni registro', () async {
      final h = Harness()..push.fid = null;
      await h.startWith(admin);
      expect(h.push.devices, isEmpty);
      expect(h.push.registeredOwner, isNull);
    });
  });

  group('dar de baja al cerrar sesión (RF-20, plan D-7)', () {
    test('borra el registro y da de baja en FCM', () async {
      final h = Harness();
      await h.startWith(admin);

      await h.controller.unregister();
      expect(h.push.devices, isEmpty);
      expect(h.push.registeredInFcm, isFalse);
      expect(h.push.registeredOwner, isNull);
      expect(h.push.pendingUnregister, isFalse);
      expect(h.push.calls.sublist(h.push.calls.indexOf('unregisterDevice')), [
        'unregisterDevice',
        'unregister',
      ]);
    });

    test('una clienta que cierra sesión no toca nada (RF-16)', () async {
      final h = Harness();
      await h.startWith(client);
      await h.controller.unregister();
      expect(h.push.calls, isEmpty);
    });

    for (final (label, fail) in [
      (
        'sin borrar el registro',
        (FakePushRepository p) {
          p.unregisterDeviceError = StateError('sin red');
        },
      ),
      (
        'sin la baja en FCM',
        (FakePushRepository p) {
          p.unregisterError = StateError('sin red');
        },
      ),
    ]) {
      test('si falla ($label), no lanza y deja la marca', () async {
        final h = Harness();
        await h.startWith(admin);
        fail(h.push);

        await h.controller.unregister();
        expect(h.push.pendingUnregister, isTrue);
      });
    }

    test('con la marca, el siguiente arranque sin admin repite la baja y '
        'la quita', () async {
      final h = Harness(pendingUnregister: true, registeredOwner: 'beidis');
      await h.startWith(null);
      expect(h.push.calls, contains('unregister'));
      expect(h.push.pendingUnregister, isFalse);
    });

    test('con la marca y una clienta en el teléfono, también', () async {
      final h = Harness(pendingUnregister: true, registeredOwner: 'beidis');
      await h.startWith(client);
      expect(h.push.calls, contains('unregister'));
      expect(h.push.pendingUnregister, isFalse);
      expect(h.push.devices, isEmpty);
    });

    test('si vuelve a fallar, la marca sigue', () async {
      final h = Harness(pendingUnregister: true, registeredOwner: 'beidis')
        ..push.unregisterError = StateError('sin red');
      await h.startWith(null);
      expect(h.push.pendingUnregister, isTrue);
    });

    test('con la marca y la admin otra vez dentro, no se da de baja: se '
        'registra y la marca se quita', () async {
      final h = Harness(pendingUnregister: true, registeredOwner: 'beidis');
      await h.startWith(admin);
      expect(h.push.calls, isNot(contains('unregister')));
      expect(h.push.devices.single.uid, 'beidis');
      expect(h.push.pendingUnregister, isFalse);
    });

    test('tras la baja, otra admin que entra se registra de nuevo', () async {
      final h = Harness();
      await h.startWith(admin);
      await h.controller.unregister();
      h.users.add(null);
      await settle();

      final other = UserModel(
        uid: 'otra',
        email: 'otra@example.com',
        displayName: 'Otra',
        role: 'admin',
      );
      h.users.add(other);
      await settle();
      expect(h.push.devices.single.uid, 'otra');
    });
  });
}
