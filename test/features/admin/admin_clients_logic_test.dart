import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/logic/admin_clients.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// Lógica pura de la lista de clientas y del bloqueo (spec 010, plan § 4,
/// T2).
DateTime wall(int day, int hour) => DateTime.utc(2026, 11, day, hour);

UserModel user(
  String uid,
  String name, {
  String role = 'cliente',
  bool blocked = false,
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  role: role,
  isBlocked: blocked,
);

const manicura = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 45,
);

const pedicura = BookedServiceModel(
  kind: BookedKind.service,
  id: 's2',
  name: BilingualText(es: 'Pedicura', pt: 'Pedicure'),
  priceCents: 4000,
  durationMinutes: 45,
);

/// Un turno de 45 minutos que empieza a [hour] del 20/11 del salón.
AppointmentModel appointment(
  String id, {
  String? clientId = 'ana',
  String phone = '+55 41 99999-0000',
  int hour = 10,
  int day = 20,
  String status = 'confirmed',
  BookedServiceModel booked = manicura,
}) {
  final start = fromSalon(wall(day, hour));
  return AppointmentModel(
    id: id,
    clientId: clientId,
    clientName: 'Ana',
    clientPhone: phone,
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: fromSalon(wall(1, 9)),
    booked: booked,
  );
}

void main() {
  group('la lista de clientas (RF-19, RF-20)', () {
    List<String> names(List<UserModel> users) =>
        clientsForAdmin(users).map((u) => u.displayName).toList();

    test('sin admins', () {
      expect(
        names([
          user('a', 'Beidis', role: 'admin'),
          user('b', 'Carla'),
          user('c', 'Ana'),
        ]),
        ['Ana', 'Carla'],
      );
    });

    test('las bloqueadas siguen en la lista', () {
      expect(names([user('a', 'Zoe', blocked: true), user('b', 'Ana')]), [
        'Ana',
        'Zoe',
      ]);
    });

    test('por nombre sin distinguir mayúsculas ni acentos', () {
      expect(
        names([
          user('1', 'Óscar'),
          user('2', 'beatriz'),
          user('3', 'Álvarez'),
          user('4', 'Carla'),
          user('5', 'Ñandú'),
          user('6', 'Natalia'),
        ]),
        ['Álvarez', 'beatriz', 'Carla', 'Ñandú', 'Natalia', 'Óscar'],
      );
    });

    test('"Álvarez" junto a "alvarez": desempata el nombre y luego el uid', () {
      final sorted = clientsForAdmin([
        user('z', 'alvarez'),
        user('y', 'Álvarez'),
        user('x', 'Bruna'),
        user('w', 'Álvarez'),
      ]);
      expect(sorted.map((u) => u.displayName), [
        'alvarez',
        'Álvarez',
        'Álvarez',
        'Bruna',
      ]);
      // Mismo nombre: por uid, para que no salten al cambiar la lista.
      expect(sorted.skip(1).take(2).map((u) => u.uid), ['w', 'y']);
    });

    test('no cambia la lista recibida', () {
      final users = [user('b', 'Carla'), user('c', 'Ana')];
      clientsForAdmin(users);
      expect(users.map((u) => u.displayName), ['Carla', 'Ana']);
    });

    test('sin fichas, vacía', () {
      expect(clientsForAdmin(const []), isEmpty);
    });
  });

  group('el turno activo de una clienta (RF-26, plan D-6)', () {
    final now = fromSalon(wall(20, 9));

    test('el suyo, por su cuenta', () {
      final found = clientActiveAppointment(
        [appointment('otra', clientId: 'bea'), appointment('suyo')],
        uid: 'ana',
        now: now,
      );
      expect(found?.id, 'suyo');
    });

    test('uno sin cuenta con su WhatsApp no es suyo', () {
      final found = clientActiveAppointment(
        [appointment('invitada', clientId: null)],
        uid: 'ana',
        now: now,
      );
      expect(found, isNull);
    });

    test('terminado o cancelado no cuenta', () {
      expect(
        clientActiveAppointment(
          [
            appointment('ayer', day: 19),
            appointment('cancelado', status: 'cancelled'),
          ],
          uid: 'ana',
          now: now,
        ),
        isNull,
      );
    });

    test('en curso sí cuenta', () {
      expect(
        clientActiveAppointment(
          [appointment('ahora')],
          uid: 'ana',
          now: fromSalon(wall(20, 10)),
        )?.id,
        'ahora',
      );
    });

    test('con dos (datos antiguos), el que empieza antes', () {
      expect(
        clientActiveAppointment(
          [appointment('tarde', hour: 15), appointment('pronto', hour: 11)],
          uid: 'ana',
          now: now,
        )?.id,
        'pronto',
      );
    });
  });

  group('antes de bloquear (RF-28)', () {
    final shown = appointment('t1');

    test('sin turno antes ni ahora: ok', () {
      expect(checkBlockBeforeSave(shown: null, current: null), BlockCheck.ok);
    });

    test('el mismo turno: ok, aunque cambie su estado', () {
      expect(
        checkBlockBeforeSave(shown: shown, current: appointment('t1')),
        BlockCheck.ok,
      );
      expect(
        checkBlockBeforeSave(
          shown: shown,
          current: appointment('t1', status: 'waiting_confirmation'),
        ),
        BlockCheck.ok,
      );
    });

    test('reservó un turno con el diálogo abierto: changed', () {
      expect(
        checkBlockBeforeSave(shown: null, current: appointment('nuevo')),
        BlockCheck.changed,
      );
    });

    test('su turno dejó de estar activo: changed', () {
      expect(
        checkBlockBeforeSave(shown: shown, current: null),
        BlockCheck.changed,
      );
    });

    test('otro turno, otra hora u otro servicio: changed', () {
      expect(
        checkBlockBeforeSave(shown: shown, current: appointment('t2')),
        BlockCheck.changed,
      );
      expect(
        checkBlockBeforeSave(
          shown: shown,
          current: appointment('t1', hour: 11),
        ),
        BlockCheck.changed,
      );
      expect(
        checkBlockBeforeSave(
          shown: shown,
          current: appointment('t1', booked: pedicura),
        ),
        BlockCheck.changed,
      );
    });
  });
}
