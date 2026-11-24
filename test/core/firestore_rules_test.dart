import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Estructura de `firestore.rules` (spec 004, RNF-2; spec 005, RNF-5; spec
/// 006, RNF-4; spec 007, RNF-5; spec 008, RNF-5; spec 009, RF-19, RF-28,
/// RF-42; spec 011, RF-23; spec 012, D-7). Lo que permite cada regla se comprueba a mano en
/// el simulador de la consola (`rules-check.md` de las specs 004 a 012);
/// aquí se fija qué cubre cada `match` para que un cambio no lo rompa sin
/// querer.
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
    // El bloqueo lo comprueban las funciones al reservar (spec 012).
    expect(text, isNot(contains('function isBlocked()')));
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

    test('nadie lo crea desde la app: solo las funciones de la agenda '
        '(spec 012, RF-1, RF-4, D-7)', () {
      expect(allow(path, 'create'), 'allow create: if false;');
    });

    test('sin las ramas de edición de la clienta (spec 006) ni de la admin '
        '(spec 008): ahora editan las funciones (spec 012, RF-2, D-7)', () {
      final update = allow(path, 'update');
      expect(update, isNot(contains('// La clienta edita')));
      expect(update, isNot(contains('// La admin edita')));
      for (final field in ["'startTime'", "'endTime'", "'booked'"]) {
        expect(update, isNot(contains(field)), reason: field);
      }
      expect(update, isNot(contains('busySlots/\$(id)).data.start')));
    });

    test(
      'la admin solo cambia el estado, de un turno activo a confirmado o '
      'cancelado: no reactiva uno cancelado (spec 012, RF-1, RF-14, D-7)',
      () {
        final update = allow(path, 'update');
        final start = update.indexOf('// La admin confirma o cancela');
        expect(start, isNot(-1));
        final admin = update.substring(
          start,
          update.indexOf('\n        // ', start + 1),
        );
        for (final check in [
          'isAdmin()',
          "resource.data.status in ['waiting_confirmation', 'confirmed']",
          'request.resource.data.diff(resource.data).affectedKeys()'
              ".hasOnly(['status'])",
          "request.resource.data.status in ['confirmed', 'cancelled']",
        ]) {
          expect(admin, contains(check), reason: check);
        }
      },
    );

    test('nadie lo borra', () {
      expect(allow(path, 'delete'), contains('if false'));
    });
  });

  group('spec 009: la clienta cancela y copia su WhatsApp', () {
    const path = '/appointments/{id}';

    /// La rama de `allow update` que empieza en el comentario [marker],
    /// hasta la siguiente rama comentada o el final.
    String branch(String marker) {
      final update = allow(path, 'update');
      final start = update.indexOf(marker);
      expect(start, isNot(-1), reason: marker);
      final next = update.indexOf('\n        // ', start + marker.length);
      return update.substring(start, next < 0 ? update.length : next);
    }

    test('cancela su turno activo fuera del margen: solo el estado y quién '
        'lo canceló, y su turno ocupado se borra en el mismo lote (RF-19)', () {
      final cancel = branch('// La clienta cancela su turno (spec 009');
      for (final check in [
        'signedIn()',
        'resource.data.clientId == request.auth.uid',
        "resource.data.status in ['waiting_confirmation', 'confirmed']",
        'resource.data.startTime > request.time + '
            "duration.value(editMarginMinutes(), 'm')",
        'request.resource.data.diff(resource.data).affectedKeys()'
            ".hasOnly(['status', 'cancelledBy'])",
        "request.resource.data.status == 'cancelled'",
        "request.resource.data.cancelledBy == 'client'",
        '!existsAfter(/databases/\$(database)/documents/busySlots/\$(id))',
      ]) {
        expect(cancel, contains(check), reason: check);
      }
      // La bloqueada también cancela (D-5).
      expect(cancel, isNot(contains('isBlocked()')));
    });

    test('copia a su turno activo el WhatsApp que deja en su ficha en el '
        'mismo lote, y nada más (RF-28)', () {
      final copy = branch('// La clienta copia su WhatsApp (spec 009');
      for (final check in [
        'signedIn()',
        'resource.data.clientId == request.auth.uid',
        "resource.data.status in ['waiting_confirmation', 'confirmed']",
        'resource.data.endTime > request.time',
        'request.resource.data.diff(resource.data).affectedKeys()'
            ".hasOnly(['clientPhone'])",
        'request.resource.data.clientPhone == getAfter(/databases/'
            '\$(database)/documents/users/\$(request.auth.uid))'
            '.data.phoneNumber',
      ]) {
        expect(copy, contains(check), reason: check);
      }
    });

    test('la dueña borra el turno ocupado de su turno al cancelarlo; la '
        'admin, siempre (RF-11, RF-19)', () {
      final delete = allow('/busySlots/{id}', 'delete');
      expect(delete, contains('isAdmin()'));
      expect(
        delete,
        contains(
          'get(/databases/\$(database)/documents/appointments/\$(id))'
          '.data.clientId == request.auth.uid',
        ),
      );
      expect(
        delete,
        contains(
          'getAfter(/databases/\$(database)/documents/appointments/\$(id))'
          ".data.status == 'cancelled'",
        ),
      );
    });

    test('las fichas siguen sin poder borrarse desde la app: solo la función '
        'deleteAccount (RF-42)', () {
      expect(allow('/users/{userId}', 'delete'), contains('if false;'));
      expect(allow(path, 'delete'), contains('if false;'));
    });
  });

  test('el margen de edición: 0 si no hay documento o campo (spec 006, '
      'RF-21)', () {
    final text = rules();
    expect(text, contains('function editMarginMinutes()'));
    expect(
      text,
      contains(
        'let path = /databases/\$(database)/documents/settings/calendar;',
      ),
    );
    expect(
      text,
      contains(
        "return exists(path) ? get(path).data.get('editMarginMinutes', 0) "
        ': 0;',
      ),
    );
  });

  group('busySlots (RF-53, RF-56)', () {
    const path = '/busySlots/{id}';

    test('lo lee cualquiera con sesión', () {
      expect(allow(path, 'get, list'), contains('signedIn()'));
    });

    test('nadie lo crea desde la app: solo las funciones de la agenda '
        '(spec 012, D-7)', () {
      expect(allow(path, 'create'), 'allow create: if false;');
    });

    test('la admin lo borra al cancelar', () {
      expect(allow(path, 'delete'), contains('isAdmin()'));
    });

    test('nadie lo cambia desde la app (spec 012, D-7)', () {
      expect(allow(path, 'update'), 'allow update: if false;');
    });
  });

  group('closures (spec 008, RF-42)', () {
    const path = '/closures/{id}';

    test('los lee cualquiera con sesión', () {
      expect(allow(path, 'get, list'), contains('if signedIn();'));
    });

    test('nadie los crea desde la app: solo la función saveClosure (spec '
        '012, RF-5, D-7)', () {
      expect(allow(path, 'create'), 'allow create: if false;');
    });

    test('solo la admin los quita, y nadie los cambia', () {
      expect(allow(path, 'delete'), contains('if isAdmin();'));
      expect(allow(path, 'update'), contains('if false;'));
    });
  });

  group('el calendario (spec 006, RF-25; spec 008, RF-44)', () {
    const path = '/settings/calendar';

    test('lo lee cualquiera con sesión y solo lo escribe la admin', () {
      expect(allow(path, 'read'), contains('if signedIn();'));
      for (final action in ['create', 'update', 'delete']) {
        expect(allow(path, action), contains('isAdmin()'), reason: action);
      }
      expect(block(rules(), path), isNot(contains('allow write')));
      expect(rules(), isNot(contains('PROVISIONAL')));
    });

    test('el margen, si está, es un entero mayor o igual que 0', () {
      final text = rules();
      expect(text, contains('function validEditMargin()'));
      expect(
        text,
        contains(
          "!('editMarginMinutes' in data)\n"
          '        || (data.editMarginMinutes is int && '
          'data.editMarginMinutes >= 0)',
        ),
      );
      expect(allow(path, 'create'), contains('validEditMargin()'));
    });

    test('al cambiar el documento, el margen solo se valida si cambia: uno '
        'guardado a mano como double no impide guardar el horario (D-7)', () {
      expect(
        allow(path, 'update'),
        contains(
          "(!request.resource.data.diff(resource.data).affectedKeys()"
          ".hasAny(['editMarginMinutes'])\n          || validEditMargin())",
        ),
      );
    });
  });

  group('pushDevices (spec 011, RF-23)', () {
    const path = '/pushDevices/{fid}';

    test('va dentro de la ficha de cada usuaria', () {
      final users = block(rules(), '/users/{userId}');
      expect(users, contains('match $path {'));
    });

    test('nadie lo lee desde la app: solo la función, con el SDK de '
        'administración', () {
      expect(allow(path, 'read'), 'allow read: if false;');
    });

    test('solo la admin lo crea o cambia, en su ficha, con el FID como id, '
        'su plataforma y la hora del servidor', () {
      final write = allow(path, 'create, update');
      for (final condition in [
        'signedIn()',
        'request.auth.uid == userId',
        'isAdmin()',
        "request.resource.data.keys().hasOnly(['fid', 'platform', "
            "'updatedAt'])",
        'request.resource.data.fid == fid',
        "request.resource.data.platform in ['android', 'ios']",
        'request.resource.data.updatedAt == request.time',
      ]) {
        expect(write, contains(condition), reason: condition);
      }
    });

    test('la dueña lo borra, aunque ya no sea admin', () {
      final delete = allow(path, 'delete');
      expect(delete, contains('request.auth.uid == userId'));
      expect(delete, isNot(contains('isAdmin()')));
    });
  });

  test('la cabecera cita la spec 012 y su comprobación manual; la '
      'redirección no cita la 009', () {
    final header = rules().substring(0, rules().indexOf('service '));
    expect(header, contains('spec 011'));
    expect(header, contains('spec 012'));
    expect(header, contains('specs/009-perfil/rules-check.md'));
    expect(header, contains('specs/011-push/rules-check.md'));
    expect(header, contains('specs/012-reglas/rules-check.md'));
    expect(File('specs/009-perfil/rules-check.md').existsSync(), isTrue);
    expect(File('specs/011-push/rules-check.md').existsSync(), isTrue);
    expect(File('specs/012-reglas/rules-check.md').existsSync(), isTrue);
    expect(
      File('lib/core/router/redirect_logic.dart').readAsStringSync(),
      isNot(contains('spec 009')),
    );
  });

  test('el candado de la agenda no tiene reglas: solo lo usan las funciones '
      '(spec 012, D-3)', () {
    expect(rules(), isNot(contains('match /locks')));
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
