import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Estructura de `firestore.rules` (spec 004, RNF-2; spec 005, RNF-5). Lo
/// que permite cada regla se comprueba a mano en el simulador de la consola
/// (`specs/004-servicios-firestore/rules-check.md` y
/// `specs/005-reservas/rules-check.md`); aquí se fija qué cubre cada `match`
/// para que un cambio no lo rompa sin querer.
void main() {
  final rulesFile = File('firestore.rules');
  String rules() => rulesFile.readAsStringSync();

  /// Cuerpo del bloque `match <path> { … }`, o `null` si no está.
  String? block(String rules, String path) {
    final header = 'match $path {';
    final start = rules.indexOf(header);
    if (start < 0) return null;
    // La llave que abre el bloque es la última de la cabecera, no la de un
    // comodín como `{userId}`.
    var depth = 0;
    for (var i = start + header.length - 1; i < rules.length; i++) {
      if (rules[i] == '{') depth++;
      if (rules[i] == '}' && --depth == 0) {
        return rules.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Las líneas del bloque [path] que empiezan por `allow <action>`, unidas
  /// hasta el `;` que las cierra.
  String allow(String path, String action) {
    final body = block(rules(), path);
    expect(body, isNotNull, reason: path);
    final start = body!.indexOf('allow $action');
    expect(start, isNot(-1), reason: '$path: allow $action');
    return body.substring(start, body.indexOf(';', start) + 1);
  }

  Map<String, dynamic> json(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('existe firestore.rules y firebase.json lo usa', () {
    expect(rulesFile.existsSync(), isTrue);
    expect(
      (json('firebase.json')['firestore'] as Map)['rules'],
      'firestore.rules',
    );
  });

  test('la lista de precios: lectura pública, escritura de la admin y sin '
      'borrado (RNF-2)', () {
    final priceList = block(rules(), '/settings/priceList');
    expect(priceList, isNotNull);
    expect(priceList, contains('allow read: if true;'));
    expect(priceList, contains('allow create, update: if isAdmin();'));
    expect(priceList, contains('allow delete: if false;'));
  });

  test('isAdmin lee el rol de la ficha de la usuaria con sesión', () {
    final text = rules();
    expect(text, contains('function isAdmin()'));
    expect(text, contains('request.auth != null'));
    expect(text, contains('function myProfile()'));
    expect(
      text,
      contains(
        "get(/databases/\$(database)/documents/users/\$(request.auth.uid))"
        '.data',
      ),
    );
    expect(text, contains("myProfile().role == 'admin'"));
    expect(text, contains("myProfile().get('isBlocked', false) == true"));
  });

  group('users (RF-57, RF-58)', () {
    const path = '/users/{userId}';

    test('cada una lee su ficha, y la admin todas', () {
      final read = allow(path, 'get, list');
      expect(read, contains('isAdmin()'));
      expect(read, contains('request.auth.uid == userId'));
    });

    test('se crea con su propio uid, como clienta y sin bloquear', () {
      final create = allow(path, 'create');
      expect(create, contains('request.auth.uid == userId'));
      expect(create, contains("get('role', 'cliente') == 'cliente'"));
      expect(create, contains("get('isBlocked', false) == false"));
    });

    test('la clienta no cambia su rol ni su bloqueo; la admin sí', () {
      final update = allow(path, 'update');
      expect(update, contains('isAdmin()'));
      expect(
        update,
        contains(
          "diff(resource.data).affectedKeys().hasAny(['role', 'isBlocked'])",
        ),
      );
      expect(allow(path, 'delete'), contains('if false'));
    });
  });

  group('appointments (RF-53 a RF-56)', () {
    const path = '/appointments/{id}';

    test('la clienta solo lee los suyos; la admin, todos', () {
      final read = allow(path, 'get, list');
      expect(read, contains('isAdmin()'));
      expect(read, contains('resource.data.clientId == request.auth.uid'));
    });

    test('se crea a su nombre, esperando confirmación, sin estar bloqueada '
        'y con su turno ocupado en el mismo lote', () {
      final create = allow(path, 'create');
      expect(create, contains('!isBlocked()'));
      expect(
        create,
        contains(
          'request.resource.data.clientId == '
          'request.auth.uid',
        ),
      );
      expect(create, contains("status == 'waiting_confirmation'"));
      expect(create, contains('endTime > request.resource.data.startTime'));
      expect(
        create,
        contains(
          'getAfter(/databases/\$(database)/documents/busySlots/'
          '\$(id)).data.start == request.resource.data.startTime',
        ),
      );
      expect(
        create,
        contains(
          'getAfter(/databases/\$(database)/documents/busySlots/'
          '\$(id)).data.end == request.resource.data.endTime',
        ),
      );
    });

    test('solo la admin cambia el estado, y nadie lo borra', () {
      final update = allow(path, 'update');
      expect(update, contains('isAdmin()'));
      expect(update, contains("affectedKeys().hasOnly(['status'])"));
      expect(allow(path, 'delete'), contains('if false'));
    });
  });

  group('busySlots (RF-53, RF-56)', () {
    const path = '/busySlots/{id}';

    test('lo lee cualquiera con sesión', () {
      expect(allow(path, 'get, list'), contains('signedIn()'));
    });

    test('se crea solo con inicio y fin, junto a un turno propio con las '
        'mismas horas', () {
      final create = allow(path, 'create');
      expect(create, contains("keys().hasOnly(['start', 'end'])"));
      for (final check in [
        'data.clientId == request.auth.uid',
        'data.startTime == request.resource.data.start',
        'data.endTime == request.resource.data.end',
      ]) {
        expect(
          create,
          contains(
            'getAfter(/databases/\$(database)/documents/appointments/'
            '\$(id)).$check',
          ),
          reason: check,
        );
      }
    });

    test('solo la admin lo borra, al cancelar, y nadie lo cambia', () {
      expect(allow(path, 'delete'), contains('isAdmin()'));
      expect(allow(path, 'update'), contains('if false'));
    });
  });

  test('el calendario sigue con la regla provisional, marcada para la spec '
      '012', () {
    final rule = block(rules(), '/settings/calendar');
    expect(rule, isNotNull);
    expect(rule, contains('allow read, write: if request.auth != null;'));
    expect(rule, contains('PROVISIONAL'));
    expect(rule, contains('spec 012'));
  });

  test('ya no se cita la spec 009 en las reglas ni en la redirección', () {
    expect(rules(), isNot(contains('spec 009')));
    expect(
      File('lib/core/router/redirect_logic.dart').readAsStringSync(),
      isNot(contains('spec 009')),
    );
  });

  test('no hay un comodín que abra la lista de precios a cualquier persona '
      'con sesión', () {
    final text = rules();
    expect(text, isNot(contains('{document=**}')));
    expect(text, isNot(contains('match /settings/{')));
  });

  test('firebase.json apunta a firestore.indexes.json (plan § 2)', () {
    expect(
      (json('firebase.json')['firestore'] as Map)['indexes'],
      'firestore.indexes.json',
    );
  });

  test('el índice de "mis turnos" está declarado: clientId y startTime '
      'descendente', () {
    final indexes = json('firestore.indexes.json')['indexes'] as List;
    final mine = indexes.cast<Map<String, dynamic>>().where(
      (index) =>
          index['collectionGroup'] == 'appointments' &&
          index['queryScope'] == 'COLLECTION',
    );
    expect(mine, hasLength(1));
    expect(mine.single['fields'], [
      {'fieldPath': 'clientId', 'order': 'ASCENDING'},
      {'fieldPath': 'startTime', 'order': 'DESCENDING'},
    ]);
  });
}
