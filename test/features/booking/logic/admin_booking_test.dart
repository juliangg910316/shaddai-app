import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/admin_booking.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// Turno activo de una persona y comprobación antes de guardar el turno que
/// agenda la admin (spec 007, RF-11, RF-14, RF-15, RF-18; RNF-1; plan § 4.3).
void main() {
  // Horas de pared del salón. 2026-11-10 es martes.
  DateTime at(int hour, [int minute = 0, int day = 10]) =>
      DateTime.utc(2026, 11, day, hour, minute);

  /// El martes abre de 8:00 a 12:00.
  final settings = CalendarSettingsModel(
    openingHours: {
      'tuesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
    },
    globalSlotDurationMinutes: 60,
    blockedDates: const [],
  );

  AppointmentModel appt(
    String id, {
    String? clientId,
    String phone = '41 90000-0000',
    required DateTime start,
    required DateTime end,
    String status = 'confirmed',
  }) => AppointmentModel(
    id: id,
    clientId: clientId,
    clientName: id,
    clientPhone: phone,
    startTime: fromSalon(start),
    endTime: fromSalon(end),
    status: status,
    createdAt: fromSalon(at(7, 0, 1)),
  );

  UserModel user(
    String uid, {
    String phone = '41 99999-0000',
    String role = 'cliente',
    bool blocked = false,
  }) => UserModel(
    uid: uid,
    email: '$uid@example.com',
    displayName: uid,
    phoneNumber: phone,
    role: role,
    isBlocked: blocked,
  );

  group('activeAppointmentOfPerson (RF-14)', () {
    final now = fromSalon(at(10));
    final ana = appt(
      'ana',
      clientId: 'u1',
      phone: '+55 41 99999-0000',
      start: at(11),
      end: at(12),
    );
    final guestSamePhone = appt(
      'sin-cuenta',
      phone: '(41) 99999-0000',
      start: at(9, 0, 20),
      end: at(10, 0, 20),
    );
    final other = appt(
      'otra',
      clientId: 'u2',
      phone: '41 98888-0000',
      start: at(11),
      end: at(12),
    );

    final cases =
        <
          String,
          ({
            List<AppointmentModel> appointments,
            String? uid,
            String phone,
            String? expected,
          })
        >{
          'por su cuenta': (
            appointments: [other, ana],
            uid: 'u1',
            phone: '41 77777-0000',
            expected: 'ana',
          ),
          'una persona sin cuenta, por su WhatsApp': (
            appointments: [other, guestSamePhone],
            uid: null,
            phone: '+55 41 99999-0000',
            expected: 'sin-cuenta',
          ),
          'una clienta con cuenta con un turno sin cuenta a su WhatsApp': (
            appointments: [other, guestSamePhone],
            uid: 'u1',
            phone: '41 99999-0000',
            expected: 'sin-cuenta',
          ),
          'una persona sin cuenta con el WhatsApp de una clienta': (
            appointments: [ana],
            uid: null,
            phone: '41 99999-0000',
            expected: 'ana',
          ),
          'con dos, el que empieza antes': (
            appointments: [guestSamePhone, ana],
            uid: 'u1',
            phone: '41 99999-0000',
            expected: 'ana',
          ),
          'en curso sigue activo': (
            appointments: [
              appt('curso', clientId: 'u1', start: at(9, 30), end: at(10, 30)),
            ],
            uid: 'u1',
            phone: '',
            expected: 'curso',
          ),
          'terminado no cuenta': (
            appointments: [
              appt('fin', clientId: 'u1', start: at(9), end: at(10)),
            ],
            uid: 'u1',
            phone: '',
            expected: null,
          ),
          'cancelado no cuenta': (
            appointments: [
              appt(
                'cancelado',
                clientId: 'u1',
                start: at(11),
                end: at(12),
                status: 'cancelled',
              ),
            ],
            uid: 'u1',
            phone: '',
            expected: null,
          ),
          'esperando confirmación cuenta': (
            appointments: [
              appt(
                'espera',
                clientId: 'u1',
                start: at(11),
                end: at(12),
                status: 'waiting_confirmation',
              ),
            ],
            uid: 'u1',
            phone: '',
            expected: 'espera',
          ),
          'de otra persona no cuenta': (
            appointments: [other],
            uid: 'u1',
            phone: '41 99999-0000',
            expected: null,
          ),
          'sin WhatsApp no coincide con turnos sin número': (
            appointments: [
              appt('vacío', phone: '', start: at(11), end: at(12)),
            ],
            uid: null,
            phone: '',
            expected: null,
          ),
        };
    cases.forEach((name, c) {
      test(name, () {
        expect(
          activeAppointmentOfPerson(
            c.appointments,
            uid: c.uid,
            phone: c.phone,
            now: now,
          )?.id,
          c.expected,
        );
      });
    });
  });

  group('checkAdminBeforeSave (RF-11, RF-14, RF-15, RF-18)', () {
    final nowSalon = at(7);
    BusyRange busy(DateTime start, DateTime end) => (start: start, end: end);
    const ana = AccountRecipient(
      uid: 'u1',
      name: 'Ana',
      phone: '41 99999-0000',
    );
    const rosa = GuestRecipient(
      name: 'Rosa',
      phone: '41 95555-0000',
      consent: true,
    );
    final anaActive = appt(
      'ana-activo',
      clientId: 'u1',
      start: at(11, 0, 20),
      end: at(12, 0, 20),
    );

    AdminBookingCheck check({
      DateTime? start,
      int duration = 60,
      List<BusyRange> busyRanges = const [],
      List<AppointmentModel> active = const [],
      Recipient recipient = ana,
      UserModel? recipientUser,
      bool noRecipientUser = false,
      List<UserModel> users = const [],
    }) => checkAdminBeforeSave(
      start: start ?? at(9),
      durationMinutes: duration,
      settings: settings,
      busy: busyRanges,
      active: active,
      recipient: recipient,
      recipientUser: noRecipientUser ? null : recipientUser ?? user('u1'),
      users: users,
      nowSalon: nowSalon,
    );

    test('todo bien, con cuenta y sin cuenta', () {
      expect(check(), isA<AdminCheckOk>());
      expect(
        check(recipient: rosa, noRecipientUser: true),
        isA<AdminCheckOk>(),
      );
    });

    test('una persona sin cuenta con el WhatsApp de una clienta sin '
        'bloquear se agenda igual (RF-10)', () {
      expect(
        check(
          recipient: rosa,
          noRecipientUser: true,
          users: [user('u9', phone: '+55 41 95555-0000')],
        ),
        isA<AdminCheckOk>(),
      );
    });

    test('la clienta está bloqueada, ya no existe o no es clienta (RF-15)', () {
      expect(
        check(recipientUser: user('u1', blocked: true)),
        isA<AdminCheckRecipientBlocked>(),
      );
      expect(check(noRecipientUser: true), isA<AdminCheckRecipientBlocked>());
      expect(
        check(recipientUser: user('u1', role: 'admin')),
        isA<AdminCheckRecipientBlocked>(),
      );
    });

    test(
      'la persona sin cuenta tiene el WhatsApp de una bloqueada (RF-11)',
      () {
        expect(
          check(
            recipient: rosa,
            noRecipientUser: true,
            users: [user('u9', phone: '(41) 95555-0000', blocked: true)],
          ),
          isA<AdminCheckRecipientBlocked>(),
        );
      },
    );

    test('la persona ya tiene un turno activo, con ese turno (RF-14)', () {
      final result = check(active: [anaActive]);
      expect(result, isA<AdminCheckPersonActive>());
      expect((result as AdminCheckPersonActive).appointment.id, 'ana-activo');
    });

    test('por el WhatsApp actual de su ficha, aunque cambiara al elegirla', () {
      final guestWithNewPhone = appt(
        'nuevo',
        phone: '41 91111-0000',
        start: at(11, 0, 20),
        end: at(12, 0, 20),
      );
      expect(
        check(
          active: [guestWithNewPhone],
          recipientUser: user('u1', phone: '41 91111-0000'),
        ),
        isA<AdminCheckPersonActive>(),
      );
    });

    test('la hora ya no está libre o el servicio no cabe (RF-18)', () {
      expect(
        check(busyRanges: [busy(at(9), at(10))]),
        isA<AdminCheckSlotTaken>(),
      );
      expect(check(start: at(9, 15)), isA<AdminCheckSlotTaken>());
      expect(check(start: at(6)), isA<AdminCheckSlotTaken>());
      expect(
        check(duration: 90, busyRanges: [busy(at(10), at(11))]),
        isA<AdminCheckDoesNotFit>(),
      );
      expect(check(start: at(11), duration: 90), isA<AdminCheckDoesNotFit>());
    });

    test('a más de 60 días también se comprueba la hora (RF-12)', () {
      // 2027-03-09 es martes, a 119 días.
      final far = DateTime.utc(2027, 3, 9, 9);
      expect(check(start: far), isA<AdminCheckOk>());
      expect(
        check(
          start: far,
          busyRanges: [busy(far, far.add(const Duration(hours: 1)))],
        ),
        isA<AdminCheckSlotTaken>(),
      );
    });

    test('orden: bloqueada, turno activo, hora ocupada y no cabe', () {
      expect(
        check(
          recipientUser: user('u1', blocked: true),
          active: [anaActive],
          busyRanges: [busy(at(9), at(10))],
        ),
        isA<AdminCheckRecipientBlocked>(),
      );
      expect(
        check(active: [anaActive], busyRanges: [busy(at(9), at(10))]),
        isA<AdminCheckPersonActive>(),
      );
      expect(
        check(duration: 300, busyRanges: [busy(at(9), at(10))]),
        isA<AdminCheckSlotTaken>(),
      );
    });
  });

  test('no importa Flutter ni Firebase (RNF-1)', () {
    final source = File('lib/features/booking/logic/admin_booking.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('cloud_firestore')));
  });

  group('checkAdminBeforeSave con cierres (spec 008, RF-12, RF-14)', () {
    final nowSalon = at(7);
    const ana = AccountRecipient(
      uid: 'u1',
      name: 'Ana',
      phone: '41 99999-0000',
    );

    AdminBookingCheck check(int duration, List<BusyRange> closures) =>
        checkAdminBeforeSave(
          start: at(9),
          durationMinutes: duration,
          settings: settings,
          busy: const [],
          closures: closures,
          active: const [],
          recipient: ana,
          recipientUser: user('u1'),
          users: const [],
          nowSalon: nowSalon,
        );

    test('una hora dentro de un cierre → hora ocupada', () {
      expect(
        check(30, [(start: at(9), end: at(10))]),
        isA<AdminCheckSlotTaken>(),
      );
    });

    test('un servicio que no cabe antes del cierre → no cabe', () {
      expect(
        check(60, [(start: at(9, 30), end: at(10))]),
        isA<AdminCheckDoesNotFit>(),
      );
    });
  });
}
