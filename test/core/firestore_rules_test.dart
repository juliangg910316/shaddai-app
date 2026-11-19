import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Estructura de `firestore.rules` (spec 004, RNF-2; spec 005, RNF-5; spec
/// 006, RNF-4; spec 007, RNF-5; spec 008, RNF-5; spec 009, RF-19, RF-28,
/// RF-42). Lo que permite cada regla se comprueba a mano en el simulador de
/// la consola (`rules-check.md` de las specs 004 a 009);
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

    test('la clienta no puede marcarlo como creado por la admin (spec 007, '
        'RF-25)', () {
      expect(
        allow(path, 'create'),
        contains("request.resource.data.get('createdByAdmin', false) == false"),
      );
    });

    test('la admin lo crea confirmado y marcado, para una persona sin cuenta '
        'o para una clienta sin bloquear que no es ella, con su turno '
        'ocupado en el mismo lote (spec 007, RF-2, RF-25)', () {
      final create = allow(path, 'create');
      final admin = create.substring(create.indexOf('|| (isAdmin()'));
      for (final check in [
        "request.resource.data.status == 'confirmed'",
        'request.resource.data.createdByAdmin == true',
        'request.resource.data.endTime > request.resource.data.startTime',
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.start == request.resource.data.startTime',
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.end == request.resource.data.endTime',
        'request.resource.data.clientId == null',
        'request.resource.data.clientId != request.auth.uid',
        'get(/databases/\$(database)/documents/users/'
            '\$(request.resource.data.clientId)).data.role == \'cliente\'',
        'get(/databases/\$(database)/documents/users/'
            '\$(request.resource.data.clientId)).data'
            ".get('isBlocked', false) == false",
      ]) {
        expect(admin, contains(check), reason: check);
      }
    });

    test('la clienta, al editar, no toca la marca de la admin (spec 007, '
        'RF-30)', () {
      final update = allow(path, 'update');
      // Solo la parte de la clienta: la edición de la admin sí la toca.
      final client = update.substring(
        update.indexOf('// La clienta edita'),
        update.indexOf('// La admin edita'),
      );
      expect(
        client,
        contains(".hasOnly(['startTime', 'endTime', 'booked', 'status'])"),
      );
      expect(client, isNot(contains('createdByAdmin')));
    });

    test('la admin edita un turno activo: la persona, las horas y lo '
        'reservado, siempre confirmado, sin quitar la marca, marcándolo si '
        'cambia la persona, para una persona válida y con su turno ocupado '
        'a la vez (spec 008, RF-43)', () {
      final update = allow(path, 'update');
      final start = update.indexOf('// La admin edita');
      expect(start, isNot(-1));
      final edit = update.substring(start);
      for (final check in [
        'isAdmin()',
        "resource.data.status in ['waiting_confirmation', 'confirmed']",
        'resource.data.endTime > request.time',
        'request.resource.data.diff(resource.data).affectedKeys()'
            ".hasOnly(['clientId', 'clientName', 'clientPhone', "
            "'clientPhotoUrl', 'startTime', 'endTime', 'booked', 'status', "
            "'createdByAdmin'])",
        "request.resource.data.status == 'confirmed'",
        'request.resource.data.endTime > request.resource.data.startTime',
        "request.resource.data.get('createdByAdmin', false) == true",
        ".affectedKeys().hasAny(['clientId', 'clientName', 'clientPhone', "
            "'clientPhotoUrl'])",
        'request.resource.data.clientId == null',
        'request.resource.data.clientId != request.auth.uid',
        'get(/databases/\$(database)/documents/users/'
            '\$(request.resource.data.clientId)).data.role == \'cliente\'',
        'get(/databases/\$(database)/documents/users/'
            '\$(request.resource.data.clientId)).data'
            ".get('isBlocked', false) == false",
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.start == request.resource.data.startTime',
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.end == request.resource.data.endTime',
      ]) {
        expect(edit, contains(check), reason: check);
      }
    });

    test('la admin solo cambia el estado, y nadie lo borra', () {
      final update = allow(path, 'update');
      expect(
        update,
        contains(
          "(isAdmin() && request.resource.data.diff(resource.data)"
          ".affectedKeys().hasOnly(['status']))",
        ),
      );
      expect(allow(path, 'delete'), contains('if false'));
    });

    test('la clienta edita su turno activo y editable: solo el inicio, el '
        'fin y lo reservado, vuelve a esperar confirmación y su turno '
        'ocupado cambia a la vez (spec 006, RF-24, RF-26)', () {
      final update = allow(path, 'update');
      for (final check in [
        'signedIn() && !isBlocked()',
        'resource.data.clientId == request.auth.uid',
        "resource.data.status in ['waiting_confirmation', 'confirmed']",
        'resource.data.startTime > request.time + '
            "duration.value(editMarginMinutes(), 'm')",
        'request.resource.data.diff(resource.data).affectedKeys()'
            ".hasOnly(['startTime', 'endTime', 'booked', 'status'])",
        "request.resource.data.status == 'waiting_confirmation'",
        'request.resource.data.startTime > request.time',
        'request.resource.data.endTime > request.resource.data.startTime',
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.start == request.resource.data.startTime',
        'getAfter(/databases/\$(database)/documents/busySlots/\$(id))'
            '.data.end == request.resource.data.endTime',
      ]) {
        expect(update, contains(check), reason: check);
      }
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

    test('la admin lo crea junto a cualquier turno, con las mismas horas: '
        'el que agenda (spec 007, RF-25) y el que edita, si un turno antiguo '
        'no lo tenía (spec 008, RF-43)', () {
      final create = allow(path, 'create');
      expect(
        create,
        contains(
          '(getAfter(/databases/\$(database)/documents/appointments/\$(id))'
          '.data.clientId == request.auth.uid\n          || isAdmin())',
        ),
      );
      expect(create, isNot(contains('createdByAdmin')));
    });

    test('la admin lo borra al cancelar', () {
      expect(allow(path, 'delete'), contains('isAdmin()'));
    });

    test('se cambia solo junto a la edición de su turno, que es de la '
        'clienta, con las mismas horas (spec 006, RF-24, RF-26)', () {
      final update = allow(path, 'update');
      expect(update, contains('signedIn()'));
      expect(
        update,
        contains("request.resource.data.keys().hasOnly(['start', 'end'])"),
      );
      expect(
        update,
        contains(
          'get(/databases/\$(database)/documents/appointments/\$(id))'
          '.data.clientId == request.auth.uid',
        ),
      );
      for (final check in [
        'data.startTime == request.resource.data.start',
        'data.endTime == request.resource.data.end',
      ]) {
        expect(
          update,
          contains(
            'getAfter(/databases/\$(database)/documents/appointments/'
            '\$(id)).$check',
          ),
          reason: check,
        );
      }
      expect(update, isNot(contains('if false')));
    });

    test('la admin lo cambia junto a la edición de cualquier turno, con las '
        'mismas horas (spec 008, RF-43)', () {
      final update = allow(path, 'update');
      expect(
        update,
        contains(
          '(get(/databases/\$(database)/documents/appointments/\$(id))'
          '.data.clientId == request.auth.uid\n          || isAdmin())',
        ),
      );
    });
  });

  group('closures (spec 008, RF-42)', () {
    const path = '/closures/{id}';

    test('los lee cualquiera con sesión', () {
      expect(allow(path, 'get, list'), contains('if signedIn();'));
    });

    test('solo la admin los crea, con solo inicio y fin, y el fin después '
        'del inicio', () {
      final create = allow(path, 'create');
      for (final check in [
        'isAdmin()',
        "request.resource.data.keys().hasOnly(['start', 'end'])",
        'request.resource.data.start is timestamp',
        'request.resource.data.end is timestamp',
        'request.resource.data.end > request.resource.data.start',
      ]) {
        expect(create, contains(check), reason: check);
      }
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

  test('la cabecera cita la spec 009 y su comprobación manual; la '
      'redirección ya no la cita', () {
    final header = rules().substring(0, rules().indexOf('service '));
    expect(header, contains('spec 009'));
    expect(header, contains('specs/009-perfil/rules-check.md'));
    expect(File('specs/009-perfil/rules-check.md').existsSync(), isTrue);
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
