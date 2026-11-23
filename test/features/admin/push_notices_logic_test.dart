import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/logic/push_notices.dart';

/// Lógica pura de los avisos push en la app (spec 011, plan § 4, T3).
UserModel user(String role) => UserModel(
  uid: role,
  email: '$role@example.com',
  displayName: role,
  role: role,
);

final admin = user('admin');
final client = user('cliente');

void main() {
  group('explicar el permiso, registrar y avisar del rechazo '
      '(RF-15 a RF-18)', () {
    // Lo que cada función devuelve para la admin en Android/iOS con cada
    // permiso; en todos los demás casos, false.
    const forAdmin = {
      PushPermission.notAsked: (explain: true, register: false, off: false),
      PushPermission.granted: (explain: false, register: true, off: false),
      PushPermission.denied: (explain: false, register: false, off: true),
    };

    for (final MapEntry(key: permission, value: expected) in forAdmin.entries) {
      test('la admin en Android/iOS con $permission', () {
        expect(
          shouldExplainPush(isWeb: false, user: admin, permission: permission),
          expected.explain,
        );
        expect(
          shouldRegisterDevice(
            isWeb: false,
            user: admin,
            permission: permission,
          ),
          expected.register,
        );
        expect(
          showPushDisabled(isWeb: false, user: admin, permission: permission),
          expected.off,
        );
      });

      test('en Web, nada, ni a la admin ($permission)', () {
        expect(
          shouldExplainPush(isWeb: true, user: admin, permission: permission),
          isFalse,
        );
        expect(
          shouldRegisterDevice(
            isWeb: true,
            user: admin,
            permission: permission,
          ),
          isFalse,
        );
        expect(
          showPushDisabled(isWeb: true, user: admin, permission: permission),
          isFalse,
        );
      });

      for (final (label, someone) in [
        ('una clienta', client),
        ('un visitante', null),
      ]) {
        test('a $label, nada: ni permiso ni registro (RF-16, $permission)', () {
          expect(
            shouldExplainPush(
              isWeb: false,
              user: someone,
              permission: permission,
            ),
            isFalse,
          );
          expect(
            shouldRegisterDevice(
              isWeb: false,
              user: someone,
              permission: permission,
            ),
            isFalse,
          );
          expect(
            showPushDisabled(
              isWeb: false,
              user: someone,
              permission: permission,
            ),
            isFalse,
          );
        });
      }
    }

    test('sin saber aún el permiso, nada', () {
      expect(
        shouldExplainPush(isWeb: false, user: admin, permission: null),
        isFalse,
      );
      expect(
        shouldRegisterDevice(isWeb: false, user: admin, permission: null),
        isFalse,
      );
      expect(
        showPushDisabled(isWeb: false, user: admin, permission: null),
        isFalse,
      );
    });
  });

  group('repetir la baja que quedó pendiente (RF-20, plan D-7, D-15)', () {
    test('con la marca y sin sesión de admin, se repite', () {
      expect(
        shouldRetryUnregister(pendingUnregister: true, user: null),
        isTrue,
      );
      expect(
        shouldRetryUnregister(pendingUnregister: true, user: client),
        isTrue,
      );
    });

    test('con la marca y la admin con sesión, no: se vuelve a registrar', () {
      expect(
        shouldRetryUnregister(pendingUnregister: true, user: admin),
        isFalse,
      );
    });

    test('sin la marca, nunca', () {
      for (final someone in [null, client, admin]) {
        expect(
          shouldRetryUnregister(pendingUnregister: false, user: someone),
          isFalse,
        );
      }
    });
  });

  group('el día del aviso (RF-12)', () {
    test('YYYY-MM-DD válido: ese día del salón', () {
      expect(
        noticeDay({'day': '2026-11-21', 'kind': 'created'}),
        DateTime.utc(2026, 11, 21),
      );
      expect(noticeDay({'day': '2027-01-05'}), DateTime.utc(2027, 1, 5));
    });

    test('es un día del salón: DateTime.utc a las 0:00', () {
      final day = noticeDay({'day': '2026-12-30'})!;
      expect(day.isUtc, isTrue);
      expect((day.hour, day.minute), (0, 0));
    });

    test('sin day, null', () {
      expect(noticeDay({}), isNull);
      expect(noticeDay({'kind': 'created'}), isNull);
    });

    test('con otro formato, null', () {
      for (final value in [
        '',
        '21/11/2026',
        '2026-11-21T10:00',
        '2026-1-5',
        ' 2026-11-21',
        'mañana',
      ]) {
        expect(noticeDay({'day': value}), isNull, reason: value);
      }
    });

    test('una fecha imposible, null', () {
      for (final value in ['2026-02-30', '2026-13-01', '2026-00-10']) {
        expect(noticeDay({'day': value}), isNull, reason: value);
      }
    });
  });

  group('el aviso como lo ve la app (PushNotice)', () {
    test('título, texto y datos como texto', () {
      final notice = PushNotice.fromParts(
        title: 'Turno nuevo',
        body: 'Ana Herrera · sábado 21 de noviembre, 10:00',
        data: {'kind': 'created', 'day': '2026-11-21', 'extra': 3},
      );
      expect(notice.title, 'Turno nuevo');
      expect(notice.body, 'Ana Herrera · sábado 21 de noviembre, 10:00');
      expect(notice.data, {
        'kind': 'created',
        'day': '2026-11-21',
        'extra': '3',
      });
    });

    test('sin título ni texto, vacíos; un dato nulo no se copia', () {
      final notice = PushNotice.fromParts(data: {'day': null});
      expect(notice.title, '');
      expect(notice.body, '');
      expect(notice.data, isEmpty);
    });

    test('su día se lee de sus datos con noticeDay', () {
      expect(
        noticeDay(PushNotice.fromParts(data: {'day': '2026-11-21'}).data),
        DateTime.utc(2026, 11, 21),
      );
      expect(noticeDay(PushNotice.fromParts().data), isNull);
    });
  });
}
