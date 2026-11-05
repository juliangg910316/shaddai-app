import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/core/utils/capitalize.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_notices.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/landing/landing_content.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_link_launcher.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

/// Turno de [testClient] del viernes 20 de 9:00 a 10:30: un combo con un
/// adicional, R$ 80 en total.
AppointmentModel active({
  String status = 'waiting_confirmation',
  DateTime? end,
}) => AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(20, 9)),
  endTime: fromSalon(end ?? at(20, 10, 30)),
  status: status,
  createdAt: bookingTestNow,
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: BilingualText(es: 'Manicura rusa', pt: 'Manicure russa'),
    priceCents: 7000,
    durationMinutes: 90,
    addons: [
      BookedAddonModel(
        id: 'a1',
        name: BilingualText(es: 'Decoración', pt: 'Decoração'),
        priceCents: 1000,
      ),
    ],
  ),
);

final blocked = testClient.copyWith(isBlocked: true);
final admin = testClient.copyWith(role: 'admin');

/// Deja llegar los streams: sesión, turnos y "ahora".
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;
  late RecordingLinkLauncher links;

  setUp(() {
    bookings = FakeBookingRepository();
    links = RecordingLinkLauncher();
  });

  Future<void> pump(
    WidgetTester tester, {
    UserModel? user,
    Stream<UserModel?> Function()? userStream,
    Stream<DateTime> Function()? nowStream,
    String language = 'es',
  }) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const BookingView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          user: user,
          userStream: userStream,
          nowStream: nowStream,
        ),
        links.override,
      ],
    );
    await settle(tester);
  }

  group('turno activo (RF-33, RF-34, RF-46)', () {
    testWidgets('muestra lo reservado, las horas, el total, el estado y '
        '"solo uno"', (tester) async {
      bookings.mine = [active()];
      await pump(tester);

      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('Tu turno'), findsOneWidget);
      expect(find.text('Manicura rusa'), findsOneWidget);
      expect(find.textContaining('Decoración'), findsOneWidget);
      final day = capitalizeFirst(
        DateFormat.yMMMMEEEEd('es').format(at(20, 0)),
      );
      expect(find.text(day), findsOneWidget);
      final hm = DateFormat.Hm('es');
      expect(
        find.text('${hm.format(at(20, 9))} – ${hm.format(at(20, 10, 30))}'),
        findsOneWidget,
      );
      expect(find.text('R\$ 80'), findsOneWidget);
      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(
        find.textContaining('Solo puedes tener un turno pendiente'),
        findsOneWidget,
      );
    });

    testWidgets('confirmado, en portugués', (tester) async {
      bookings.mine = [active(status: 'confirmed')];
      await pump(tester, language: 'pt');

      expect(find.text('Seu horário'), findsOneWidget);
      expect(find.text('Manicure russa'), findsOneWidget);
      expect(find.textContaining('Decoração'), findsOneWidget);
      expect(find.text('CONFIRMADA'), findsOneWidget);
    });

    testWidgets('desaparece al cancelarse', (tester) async {
      bookings.mine = [active()];
      await pump(tester);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);

      bookings.emitMine([active(status: 'cancelled')]);
      await settle(tester);
      expect(find.byType(ActiveAppointmentView), findsNothing);
    });

    testWidgets('desaparece al terminar (RF-35)', (tester) async {
      final now = StreamController<DateTime>.broadcast();
      addTearDown(now.close);
      bookings.mine = [active(end: at(10, 8))];
      await pump(
        tester,
        nowStream: () async* {
          yield at(10, 7);
          yield* now.stream;
        },
      );
      expect(find.byType(ActiveAppointmentView), findsOneWidget);

      now.add(at(10, 8));
      await settle(tester);
      expect(find.byType(ActiveAppointmentView), findsNothing);
    });
  });

  group('bloqueo (RF-37, RF-38)', () {
    testWidgets('sin turno, ve el aviso con WhatsApp', (tester) async {
      await pump(tester, user: blocked);

      expect(find.byType(BookingBlockedNotice), findsOneWidget);
      expect(
        find.textContaining('Tu cuenta no puede reservar turnos'),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('WHATSAPP'));
      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });

    testWidgets('con turno, ve el turno y el aviso', (tester) async {
      bookings.mine = [active()];
      await pump(tester, user: blocked);

      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.byType(BookingBlockedNotice), findsOneWidget);
    });

    testWidgets('el bloqueo con la sesión abierta cambia la vista sin cerrar '
        'la sesión', (tester) async {
      final users = StreamController<UserModel?>.broadcast();
      addTearDown(users.close);
      await pump(
        tester,
        userStream: () async* {
          yield testClient;
          yield* users.stream;
        },
      );
      expect(find.byType(BookingBlockedNotice), findsNothing);

      users.add(blocked);
      await settle(tester);
      expect(find.byType(BookingBlockedNotice), findsOneWidget);
      expect(find.text('Inicia sesión para reservar'), findsNothing);
    });
  });

  testWidgets('la admin ve su texto (RF-39)', (tester) async {
    await pump(tester, user: admin);

    expect(find.byType(BookingAdminNotice), findsOneWidget);
    expect(
      find.text(
        'Con la cuenta de administración no se reservan turnos a tu nombre.',
      ),
      findsOneWidget,
    );
  });

  group('error de carga (RF-49)', () {
    testWidgets('de la ficha: "Reintentar" vuelve a cargarla', (tester) async {
      var calls = 0;
      await pump(
        tester,
        userStream: () => ++calls == 1
            ? Stream<UserModel?>.error(Exception('unavailable'))
            : Stream.value(admin),
      );

      expect(find.byType(BookingLoadErrorNotice), findsOneWidget);
      expect(find.text('No se pudo cargar la agenda.'), findsOneWidget);
      expect(find.textContaining('unavailable'), findsNothing);

      await tester.tap(find.text('REINTENTAR'));
      await settle(tester);
      expect(find.byType(BookingLoadErrorNotice), findsNothing);
      expect(find.byType(BookingAdminNotice), findsOneWidget);
    });

    testWidgets('de los turnos: "Reintentar" vuelve a pedirlos', (
      tester,
    ) async {
      bookings.mine = [active()];
      await pump(tester);
      bookings.failMine(Exception('permission-denied'));
      await settle(tester);
      expect(find.byType(BookingLoadErrorNotice), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      await settle(tester);
      expect(find.byType(BookingLoadErrorNotice), findsNothing);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(bookings.clientRequests, hasLength(2));
    });
  });
}
