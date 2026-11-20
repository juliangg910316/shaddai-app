import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/repositories/push_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/throwing_preferences.dart';

/// Lo que el repositorio de push guarda en el dispositivo y cómo traduce el
/// permiso del sistema (spec 011, plan D-7, D-8, T4). Sin Firebase: el
/// repositorio no toca `FirebaseMessaging` ni Firestore hasta que se usan.
Future<PushRepository> repositoryWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  return PushRepository(store: await SharedPreferences.getInstance());
}

void main() {
  group('la marca de que ya se preguntó (RF-15, plan D-8)', () {
    test('al empezar, no se ha preguntado', () async {
      final repository = await repositoryWith({});
      expect(repository.permissionAsked, isFalse);
    });

    test('se guarda y se lee en el dispositivo', () async {
      final repository = await repositoryWith({});
      await repository.markPermissionAsked();
      expect(repository.permissionAsked, isTrue);

      final again = PushRepository(
        store: await SharedPreferences.getInstance(),
      );
      expect(again.permissionAsked, isTrue);
    });
  });

  group('la marca de baja pendiente (RF-20, RF-25, plan D-7)', () {
    test('al empezar, no hay', () async {
      final repository = await repositoryWith({});
      expect(repository.pendingUnregister, isFalse);
    });

    test('se pone y se quita', () async {
      final repository = await repositoryWith({});
      await repository.setPendingUnregister(true);
      expect(repository.pendingUnregister, isTrue);
      expect(
        PushRepository(store: await SharedPreferences.getInstance())
            .pendingUnregister,
        isTrue,
      );
      await repository.setPendingUnregister(false);
      expect(repository.pendingUnregister, isFalse);
    });
  });

  group('la dueña del dispositivo registrado (plan § 6)', () {
    test('al empezar, nadie', () async {
      final repository = await repositoryWith({});
      expect(repository.registeredOwner, isNull);
    });

    test('se guarda y se borra', () async {
      final repository = await repositoryWith({});
      await repository.setRegisteredOwner('beidis');
      expect(repository.registeredOwner, 'beidis');
      await repository.setRegisteredOwner(null);
      expect(repository.registeredOwner, isNull);
    });
  });

  group('sin almacenamiento, nunca lanza (RF-25)', () {
    for (final (label, store) in [
      ('sin almacenamiento', null),
      ('con uno que falla', ThrowingPreferences()),
    ]) {
      test(label, () async {
        final repository = PushRepository(store: store);
        expect(repository.permissionAsked, isFalse);
        expect(repository.pendingUnregister, isFalse);
        expect(repository.registeredOwner, isNull);
        await repository.markPermissionAsked();
        await repository.setPendingUnregister(true);
        await repository.setRegisteredOwner('beidis');
      });
    }
  });

  group('el permiso de la app a partir del del sistema (plan D-8)', () {
    test('concedido o provisional: concedido, se haya preguntado o no', () {
      for (final status in [
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ]) {
        for (final asked in [false, true]) {
          expect(
            PushRepository.permissionFrom(status, asked: asked),
            PushPermission.granted,
          );
        }
      }
    });

    test('sin decidir (iOS): aún no se ha preguntado', () {
      for (final asked in [false, true]) {
        expect(
          PushRepository.permissionFrom(
            AuthorizationStatus.notDetermined,
            asked: asked,
          ),
          PushPermission.notAsked,
        );
      }
    });

    test('denegado sin la marca (Android 13 antes de preguntar): aún no', () {
      expect(
        PushRepository.permissionFrom(AuthorizationStatus.denied, asked: false),
        PushPermission.notAsked,
      );
    });

    test('denegado con la marca: denegado', () {
      expect(
        PushRepository.permissionFrom(AuthorizationStatus.denied, asked: true),
        PushPermission.denied,
      );
    });

    test('denegado para siempre: denegado, haya marca o no', () {
      for (final asked in [false, true]) {
        expect(
          PushRepository.permissionFrom(
            AuthorizationStatus.deniedPermanently,
            asked: asked,
          ),
          PushPermission.denied,
        );
      }
    });
  });

  group('el FID al darse de alta (plan D-15)', () {
    test('el primero que llega por onRegistered tras register()', () async {
      final registered = StreamController<String>.broadcast();
      addTearDown(registered.close);
      final fid = PushRepository.firstFid(
        registered: registered.stream,
        register: () async {
          // Llega durante la llamada: ya se estaba escuchando.
          registered.add('fid-1');
          registered.add('fid-2');
        },
      );
      expect(await fid, 'fid-1');
    });

    test('también si llega después de terminar register()', () async {
      final registered = StreamController<String>.broadcast();
      addTearDown(registered.close);
      final fid = PushRepository.firstFid(
        registered: registered.stream,
        register: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      registered.add('fid-1');
      expect(await fid, 'fid-1');
    });

    test('si no llega a tiempo, null', () async {
      final registered = StreamController<String>.broadcast();
      addTearDown(registered.close);
      final fid = await PushRepository.firstFid(
        registered: registered.stream,
        register: () async {},
        timeout: const Duration(milliseconds: 10),
      );
      expect(fid, isNull);
    });

    test(
      'si register() falla, lanza su error (lo recoge quien llama)',
      () async {
        final registered = StreamController<String>.broadcast();
        addTearDown(registered.close);
        await expectLater(
          PushRepository.firstFid(
            registered: registered.stream,
            register: () async => throw StateError('sin red'),
          ),
          throwsStateError,
        );
      },
    );
  });

  test('la plataforma que se guarda con el dispositivo', () {
    expect(PushRepository.platformName(TargetPlatform.android), 'android');
    expect(PushRepository.platformName(TargetPlatform.iOS), 'ios');
  });
}
