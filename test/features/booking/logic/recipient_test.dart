import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';

/// Para quién y la búsqueda de clientas (spec 007, RF-2 a RF-5, RF-7 a
/// RF-11, RF-15; RNF-1; plan § 4.2).
void main() {
  UserModel user(
    String uid,
    String name, {
    String? phone = '41 99999-0000',
    String role = 'cliente',
    bool blocked = false,
  }) => UserModel(
    uid: uid,
    email: '$uid@example.com',
    displayName: name,
    phoneNumber: phone,
    role: role,
    isBlocked: blocked,
  );

  group('foldText', () {
    const cases = <(String, String)>[
      ('ANA', 'ana'),
      ('María José', 'maria jose'),
      ('João Conceição', 'joao conceicao'),
      ('Nuñez', 'nunez'),
      ('Ângela Brandão', 'angela brandao'),
      ('Inês Lúcia Pérez', 'ines lucia perez'),
      ('Müller Ömer', 'muller omer'),
      ('Àlex Èric Ìris Òscar Ùrsula', 'alex eric iris oscar ursula'),
    ];
    for (final (raw, expected) in cases) {
      test('"$raw" → "$expected"', () => expect(foldText(raw), expected));
    }
  });

  group('isBookableClient (RF-4)', () {
    test('clienta sin bloquear y con WhatsApp: sí', () {
      expect(isBookableClient(user('u1', 'Ana')), isTrue);
    });
    test('bloqueada, admin, sin WhatsApp o con uno sin dígitos: no', () {
      expect(isBookableClient(user('u1', 'Ana', blocked: true)), isFalse);
      expect(isBookableClient(user('u1', 'Ana', role: 'admin')), isFalse);
      expect(isBookableClient(user('u1', 'Ana', phone: null)), isFalse);
      expect(isBookableClient(user('u1', 'Ana', phone: '')), isFalse);
      expect(isBookableClient(user('u1', 'Ana', phone: 'no tengo')), isFalse);
    });
  });

  group('searchClients (RF-3, RF-4)', () {
    final users = [
      user('u1', 'María José', phone: '+55 41 98888-1111'),
      user('u2', 'Mariana', phone: '(41) 97777-2222'),
      user('u3', 'Ana Maria', phone: '41 96666-3333'),
      user('u4', 'Marta Bloqueada', phone: '41 95555-4444', blocked: true),
      user('u5', 'Mario Admin', phone: '41 94444-5555', role: 'admin'),
      user('u6', 'Marisa Sin WhatsApp', phone: null),
      user('u7', 'Beatriz', phone: '41 93333-6666'),
    ];
    List<String> uids(String query, {int limit = 20}) => [
      for (final u in searchClients(users, query, limit: limit)) u.uid,
    ];

    test('menos de 2 caracteres, tras quitar espacios: nada', () {
      expect(uids(''), isEmpty);
      expect(uids('m'), isEmpty);
      expect(uids(' m  '), isEmpty);
      expect(uids('9'), isEmpty);
    });

    test('nombre sin mayúsculas ni acentos, en orden alfabético', () {
      expect(uids('MARI'), ['u3', 'u1', 'u2']);
      expect(uids('maría'), ['u3', 'u1', 'u2']);
      expect(uids('jose'), ['u1']);
    });

    test('sin bloqueadas, admins ni cuentas sin WhatsApp', () {
      expect(uids('mar'), ['u3', 'u1', 'u2']);
    });

    test('por los dígitos del WhatsApp normalizado', () {
      expect(uids('98888'), ['u1']);
      expect(uids('41 9'), ['u3', 'u7', 'u1', 'u2']);
      expect(uids('(41) 97777-2222'), ['u2']);
      expect(uids('+55 41 98888-1111'), ['u1']);
    });

    test('un texto con letras no busca por sus dígitos', () {
      // "Ana 2" no es un número: no debe dar todas las que tienen un 2.
      expect(uids('Ana 2'), isEmpty);
      expect(uids('ana maria'), ['u3']);
    });

    test('sin coincidencias: nada', () {
      expect(uids('zz'), isEmpty);
      expect(uids('12345678'), isEmpty);
    });

    test('como mucho 20, los primeros en orden alfabético', () {
      final many = [
        for (var i = 25; i >= 1; i--)
          user('c$i', 'Clienta ${i.toString().padLeft(2, '0')}'),
      ];
      final found = searchClients(many, 'clienta');
      expect(found, hasLength(20));
      expect(found.first.displayName, 'Clienta 01');
      expect(found.last.displayName, 'Clienta 20');
      expect(searchClients(many, 'clienta', limit: 5), hasLength(5));
    });
  });

  group('accountWithPhone (RF-10, RF-11)', () {
    test('la clienta con el mismo WhatsApp normalizado', () {
      final users = [
        user('u1', 'Ana', phone: '+55 41 99999-0000'),
        user('u2', 'Bea', phone: '41 98888-0000'),
      ];
      expect(accountWithPhone(users, '(41) 99999-0000')?.uid, 'u1');
      expect(accountWithPhone(users, '5541988880000')?.uid, 'u2');
    });

    test('también una bloqueada, para avisar de RF-11', () {
      final users = [user('u1', 'Ana', blocked: true)];
      expect(accountWithPhone(users, '41 99999-0000')?.isBlocked, isTrue);
    });

    test('con dos cuentas con el mismo número, manda la bloqueada', () {
      final users = [user('u1', 'Ana'), user('u2', 'Ana otra', blocked: true)];
      expect(accountWithPhone(users, '41 99999-0000')?.uid, 'u2');
    });

    test('una admin no cuenta; sin coincidencias ni número: null', () {
      final users = [user('u1', 'Admin', role: 'admin'), user('u2', 'Bea')];
      expect(accountWithPhone([users.first], '41 99999-0000'), isNull);
      expect(accountWithPhone(users, '41 91111-0000'), isNull);
      expect(accountWithPhone(users, ''), isNull);
    });
  });

  group('guestErrors (RF-7 a RF-9)', () {
    const ok = GuestRecipient(
      name: 'Rosa',
      phone: '41 99999-0000',
      consent: true,
    );
    final cases = <(GuestRecipient, Set<GuestField>, String)>[
      (ok, {}, 'todo bien'),
      (
        const GuestRecipient(name: '  ', phone: '41 99999-0000', consent: true),
        {GuestField.name},
        'nombre en blanco',
      ),
      (
        GuestRecipient(name: 'a' * 80, phone: '41 99999-0000', consent: true),
        {},
        'nombre de 80 caracteres',
      ),
      (
        GuestRecipient(name: 'a' * 81, phone: '41 99999-0000', consent: true),
        {GuestField.name},
        'nombre de 81 caracteres',
      ),
      (
        GuestRecipient(
          name: '  ${'a' * 80}  ',
          phone: '41 99999-0000',
          consent: true,
        ),
        {},
        '80 caracteres con espacios alrededor',
      ),
      (
        GuestRecipient(name: 'ã' * 80, phone: '41 99999-0000', consent: true),
        {},
        '80 letras con acento',
      ),
      (
        const GuestRecipient(name: 'Rosa', phone: '1234567', consent: true),
        {GuestField.phone},
        'WhatsApp de 7 dígitos',
      ),
      (
        const GuestRecipient(name: 'Rosa', phone: '', consent: true),
        {GuestField.phone},
        'sin WhatsApp',
      ),
      (
        const GuestRecipient(
          name: 'Rosa',
          phone: '41 99999-0000',
          consent: false,
        ),
        {GuestField.consent},
        'sin la casilla',
      ),
      (
        const GuestRecipient(name: '', phone: 'x', consent: false),
        {GuestField.name, GuestField.phone, GuestField.consent},
        'todo mal',
      ),
    ];
    for (final (guest, expected, why) in cases) {
      test(why, () => expect(guestErrors(guest), expected));
    }

    test('la persona sin cuenta vacía tiene los tres errores', () {
      expect(guestErrors(GuestRecipient.empty), {
        GuestField.name,
        GuestField.phone,
        GuestField.consent,
      });
    });
  });

  group('reconcileRecipient (RF-15)', () {
    const ana = AccountRecipient(
      uid: 'u1',
      name: 'Ana',
      phone: '41 99999-0000',
    );

    test('sin para quién o sin la lista de fichas: sin cambios', () {
      expect(reconcileRecipient(null, [user('u1', 'Ana')]), (
        recipient: null,
        blocked: false,
      ));
      expect(reconcileRecipient(ana, null), (recipient: ana, blocked: false));
    });

    test('la clienta sigue igual: sin aviso', () {
      expect(reconcileRecipient(ana, [user('u1', 'Ana')]), (
        recipient: ana,
        blocked: false,
      ));
    });

    test('la bloquean, la borran o deja de ser clienta: se quita y avisa', () {
      for (final users in [
        [user('u1', 'Ana', blocked: true)],
        <UserModel>[],
        [user('u1', 'Ana', role: 'admin')],
      ]) {
        expect(reconcileRecipient(ana, users), (
          recipient: null,
          blocked: true,
        ), reason: '$users');
      }
    });

    test('la persona sin cuenta no cambia', () {
      const guest = GuestRecipient(
        name: 'Rosa',
        phone: '41 99999-0000',
        consent: true,
      );
      expect(reconcileRecipient(guest, [user('u1', 'Ana', blocked: true)]), (
        recipient: guest,
        blocked: false,
      ));
    });
  });

  test('AccountRecipient.of copia los datos de la ficha', () {
    final recipient = AccountRecipient.of(
      user(
        'u1',
        'Ana',
        phone: '41 99999-0000',
      ).copyWith(photoUrl: 'https://example.com/ana.png'),
    );
    expect(recipient.uid, 'u1');
    expect(recipient.name, 'Ana');
    expect(recipient.phone, '41 99999-0000');
    expect(recipient.photoUrl, 'https://example.com/ana.png');
  });

  test('no importa Flutter ni Firebase (RNF-1)', () {
    final source = File('lib/features/booking/logic/recipient.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('cloud_firestore')));
  });
}
