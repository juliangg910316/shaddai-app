import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/repositories/account_repository.dart';

import '../helpers/fake_auth.dart';

/// Un `FirebaseFunctions` falso: registra las llamadas y responde con
/// [respond].
class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions(this.respond);

  final FutureOr<Object?> Function() respond;
  final calls = <String>[];
  final timeouts = <Duration?>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    calls.add(name);
    timeouts.add(options?.timeout);
    return _FakeCallable(respond);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this.respond);

  final FutureOr<Object?> Function() respond;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = await respond();
    return _Result<T>(data as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  _Result(this.data);

  @override
  final T data;
}

FirebaseFunctionsException _error(String code, {Object? details}) =>
    FirebaseFunctionsException(message: code, code: code, details: details);

/// Borrar la cuenta desde la app (spec 009, RF-37, RF-39, RF-40).
void main() {
  Future<AccountDeletionFailure?> delete(
    FutureOr<Object?> Function() respond, {
    _FakeFunctions? functions,
  }) =>
      AccountRepository(functions: functions ?? _FakeFunctions(respond))
          .deleteAccount();

  test('llama a la función deleteAccount; si va bien, no hay fallo', () async {
    final functions = _FakeFunctions(() => {'ok': true});
    expect(await delete(() => null, functions: functions), isNull);
    expect(functions.calls, ['deleteAccount']);
    // Puede tardar con muchos turnos: más margen que el de 60 s por defecto.
    expect(functions.timeouts.single, const Duration(seconds: 120));
  });

  test(
    'bloqueada: failed-precondition con el motivo blocked (RF-40)',
    () async {
      expect(
        await delete(
          () => throw _error(
            'failed-precondition',
            details: {'reason': 'blocked'},
          ),
        ),
        AccountDeletionFailure.blocked,
      );
    },
  );

  test('failed-precondition sin el motivo: failed', () async {
    expect(
      await delete(() => throw _error('failed-precondition')),
      AccountDeletionFailure.failed,
    );
  });

  test('la admin: permission-denied → notAllowed', () async {
    expect(
      await delete(() => throw _error('permission-denied')),
      AccountDeletionFailure.notAllowed,
    );
  });

  for (final code in ['internal', 'unavailable', 'deadline-exceeded']) {
    test('$code → failed (RF-39)', () async {
      expect(
        await delete(() => throw _error(code)),
        AccountDeletionFailure.failed,
      );
    });
  }

  test('sin conexión u otro error → failed (RF-39)', () async {
    expect(
      await delete(() => throw TimeoutException('sin red')),
      AccountDeletionFailure.failed,
    );
    expect(
      await delete(() => throw StateError('raro')),
      AccountDeletionFailure.failed,
    );
  });

  group('FakeAccountRepository', () {
    test('por defecto va bien y cuenta las llamadas', () async {
      final fake = FakeAccountRepository();
      expect(await fake.deleteAccount(), isNull);
      expect(await fake.deleteAccount(), isNull);
      expect(fake.calls, 2);
    });

    test('devuelve failure y espera a gate', () async {
      final gate = Completer<void>();
      final fake = FakeAccountRepository()
        ..failure = AccountDeletionFailure.blocked
        ..gate = gate.future;
      var done = false;
      final result = fake.deleteAccount().then((value) {
        done = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gate.complete();
      expect(await result, AccountDeletionFailure.blocked);
    });
  });
}
