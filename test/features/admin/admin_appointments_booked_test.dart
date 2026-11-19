import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_link_launcher.dart';

/// Un turno de las 9:00 a las 10:30 (o de [start] a [end]), con lo
/// reservado si [booked].
AppointmentModel appointment({
  String id = 't1',
  String status = 'waiting_confirmation',
  bool booked = true,
  DateTime? start,
  DateTime? end,
  String? clientId = 'u1',
  String name = 'Ana Herrera',
  String phone = '+55 41 99999-0000',
  bool createdByAdmin = false,
}) => AppointmentModel(
  id: id,
  clientId: clientId,
  clientName: name,
  clientPhone: phone,
  createdByAdmin: createdByAdmin,
  startTime: start ?? DateTime(2026, 11, 20, 9),
  endTime: end ?? DateTime(2026, 11, 20, 10, 30),
  status: status,
  createdAt: DateTime(2026, 11, 10),
  booked: booked
      ? const BookedServiceModel(
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
            BookedAddonModel(
              id: 'a2',
              name: BilingualText(es: 'Brillo', pt: 'Brilho'),
              priceCents: 500,
            ),
          ],
        )
      : null,
);

/// Hora de pared del salón del viernes 20/11/2026 (o del día [day]).
DateTime at(int hour, [int minute = 0, int day = 20]) =>
    DateTime.utc(2026, 11, day, hour, minute);

/// Un turno de [start] a [end] (horas de pared del salón).
AppointmentModel timed(
  String id,
  DateTime start,
  DateTime end, {
  String status = 'confirmed',
}) => appointment(
  id: id,
  status: status,
  name: 'Clienta $id',
  start: fromSalon(start),
  end: fromSalon(end),
);

ClosureModel closure(String id, DateTime start, DateTime end) =>
    ClosureModel(id: id, start: fromSalon(start), end: fromSalon(end));

void main() {
  late FakeBookingRepository bookings;
  late FakeConfigRepository config;
  late RecordingLinkLauncher links;
  late GoRouter router;

  setUp(() {
    bookings = FakeBookingRepository();
    config = FakeConfigRepository();
    links = RecordingLinkLauncher();
  });

  /// La agenda del viernes 20 con [shown] (o los turnos [all]) y "ahora"
  /// [now] (por defecto, el martes 10 a las 7:00 del salón).
  Future<void> pump(
    WidgetTester tester,
    AppointmentModel? shown, {
    List<AppointmentModel>? all,
    String language = 'es',
    DateTime? now,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final instant = now ?? bookingTestNow;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AdminDashboardView(),
        ),
        GoRoute(
          path: '/admin/appointments/:id/edit',
          builder: (context, state) =>
              Text('editar ${state.pathParameters['id']}'),
        ),
      ],
    );
    await pumpApp(
      tester,
      stored: {'language': language},
      router: router,
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        configRepositoryProvider.overrideWithValue(config),
        clockProvider.overrideWithValue(() => instant),
        salonNowProvider.overrideWith((ref) => Stream.value(toSalon(instant))),
        adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
        adminAppointmentsProvider.overrideWith(
          (ref) => Stream.value(all ?? [?shown]),
        ),
        links.override,
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder appointmentCard(String id) =>
      find.byKey(ValueKey('agenda-appointment-$id'));
  Finder closureCard(String id) => find.byKey(ValueKey('agenda-closure-$id'));

  group('los cierres del día (RF-9, RF-10)', () {
    testWidgets('salen entre los turnos, en orden de hora, con "CERRADO" y '
        'sus horas', (tester) async {
      config.closures = [closure('c1', at(12), at(13))];
      await pump(
        tester,
        null,
        all: [timed('t2', at(15), at(16)), timed('t1', at(9), at(10))],
      );

      expect(
        find.descendant(of: closureCard('c1'), matching: find.text('CERRADO')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: closureCard('c1'),
          matching: find.text('12:00 – 13:00'),
        ),
        findsOneWidget,
      );
      final ys = [
        tester.getTopLeft(appointmentCard('t1')).dy,
        tester.getTopLeft(closureCard('c1')).dy,
        tester.getTopLeft(appointmentCard('t2')).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('sin turnos, el cierre se ve en lugar de "No hay reservas"', (
      tester,
    ) async {
      config.closures = [closure('c1', at(12), at(13))];
      await pump(tester, null);
      expect(closureCard('c1'), findsOneWidget);
      expect(find.text('No hay reservas para este día.'), findsNothing);
    });

    testWidgets('un cierre de varios días sale en cada uno, como "Todo el '
        'día"', (tester) async {
      config.closures = [closure('d', at(0, 0, 19), at(0, 0, 22))];
      await pump(tester, null);
      expect(
        find.descendant(
          of: closureCard('d'),
          matching: find.text('Todo el día'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(closureCard('d'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(closureCard('d'), findsNothing);
    });

    testWidgets('una fecha bloqueada del día también sale', (tester) async {
      config.settings = CalendarSettingsModel(
        openingHours: CalendarSettingsModel.defaultSettings().openingHours,
        globalSlotDurationMinutes: 30,
        blockedDates: const ['2026-11-20'],
      );
      await pump(tester, null);
      expect(closureCard('2026-11-20'), findsOneWidget);
    });

    testWidgets('si fallan, el aviso y "Reintentar", y los turnos siguen '
        '(RF-10)', (tester) async {
      await pump(tester, timed('t1', at(9), at(10)));
      config.failClosures(Exception('sin red'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar los cierres.'), findsOneWidget);
      expect(appointmentCard('t1'), findsOneWidget);

      final requests = config.closureRequests.length;
      await tester.tap(find.text('REINTENTAR'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar los cierres.'), findsNothing);
      expect(config.closureRequests.length, greaterThan(requests));
    });
  });

  group('"Editar" (RF-18)', () {
    Finder editIn(String id) =>
        find.descendant(of: appointmentCard(id), matching: find.text('EDITAR'));

    testWidgets('solo en los activos que no han terminado: también en uno en '
        'curso; nunca en uno cancelado ni en uno terminado', (tester) async {
      await pump(
        tester,
        null,
        now: fromSalon(at(9, 30)),
        all: [
          timed('terminado', at(8), at(9)),
          timed('en-curso', at(9), at(10)),
          timed('esperando', at(11), at(12), status: 'waiting_confirmation'),
          timed('cancelado', at(13), at(14), status: 'cancelled'),
        ],
      );

      expect(editIn('terminado'), findsNothing);
      expect(editIn('en-curso'), findsOneWidget);
      expect(editIn('esperando'), findsOneWidget);
      expect(editIn('cancelado'), findsNothing);
    });

    testWidgets('lleva a la edición del turno y mide 48 px', (tester) async {
      await pump(tester, timed('t1', at(9), at(10)));
      final button = find.ancestor(
        of: editIn('t1'),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));

      await tester.tap(editIn('t1'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/admin/appointments/t1/edit',
      );
      expect(find.text('editar t1'), findsOneWidget);
    });
  });

  for (final (language, line) in [
    ('es', 'Manicura rusa · Decoración, Brillo'),
    ('pt', 'Manicure russa · Decoração, Brilho'),
  ]) {
    testWidgets('la tarjeta muestra lo reservado y los adicionales, en '
        '$language (RF-52)', (tester) async {
      await pump(tester, appointment(), language: language);
      expect(find.text(line), findsOneWidget);
    });
  }

  testWidgets('las horas de la tarjeta son las del salón, también con el '
      'dispositivo en otra zona (spec 005, hora de Curitiba)', (tester) async {
    // 12:00–13:30 UTC son 9:00–10:30 en Curitiba, en cualquier zona.
    await pump(
      tester,
      appointment(
        start: DateTime.utc(2026, 11, 20, 12),
        end: DateTime.utc(2026, 11, 20, 13, 30),
      ),
    );
    expect(find.text('9:00 — 10:30'), findsOneWidget);
  });

  testWidgets('un turno sin lo reservado no muestra esa línea', (tester) async {
    await pump(tester, appointment(booked: false));
    expect(find.text('Ana Herrera'), findsOneWidget);
    expect(find.textContaining('Manicura'), findsNothing);
  });

  testWidgets('"Cancelar" llama a la cancelación, que libera la hora '
      '(RF-56)', (tester) async {
    await pump(tester, appointment());
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(bookings.adminCancelled, ['t1']);
  });

  group('turnos sin cuenta y agendados por la admin (RF-22 a RF-24)', () {
    final guest = appointment(
      clientId: null,
      name: 'Rosa Lima',
      phone: '(41) 99333-0000',
      createdByAdmin: true,
    );

    testWidgets('sin cuenta: su nombre, su WhatsApp, "Sin cuenta" y las '
        'iniciales sin foto (RF-22)', (tester) async {
      await pump(tester, guest);
      expect(find.text('Rosa Lima'), findsOneWidget);
      expect(find.text('(41) 99333-0000'), findsOneWidget);
      expect(find.text('SIN CUENTA'), findsOneWidget);
      expect(find.text('RL'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('el que creó la admin lo dice (RF-23)', (tester) async {
      await pump(tester, guest);
      expect(find.text('AGENDADO POR LA ADMIN'), findsOneWidget);
    });

    testWidgets('uno de una clienta, pedido por ella, no lleva ninguna de '
        'las dos marcas', (tester) async {
      await pump(tester, appointment());
      expect(find.text('SIN CUENTA'), findsNothing);
      expect(find.text('AGENDADO POR LA ADMIN'), findsNothing);
    });

    testWidgets('el botón de WhatsApp abre su chat; mide 48 px y tiene '
        'nombre (RF-22, D-6)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, guest);
      final button = find.byTooltip('Escribir a Rosa Lima por WhatsApp');
      expect(button, findsOneWidget);
      // El lector de pantalla lo lee como un botón con ese nombre.
      expect(
        tester.getSemantics(
          find.ancestor(
            of: find.byType(WhatsAppIcon),
            matching: find.byType(IconButton),
          ),
        ),
        isSemantics(
          tooltip: 'Escribir a Rosa Lima por WhatsApp',
          isButton: true,
          hasTapAction: true,
        ),
      );
      final size = tester.getSize(
        find.ancestor(
          of: find.byType(WhatsAppIcon),
          matching: find.byType(IconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://wa.me/5541993330000')]);
      semantics.dispose();
    });

    testWidgets('también en un turno con cuenta (D-6)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, appointment());
      await tester.tap(find.byTooltip('Escribir a Ana Herrera por WhatsApp'));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://wa.me/5541999990000')]);
      semantics.dispose();
    });

    testWidgets('en portugués', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, guest, language: 'pt');
      expect(find.text('SEM CONTA'), findsOneWidget);
      expect(find.text('AGENDADO PELA ADMIN'), findsOneWidget);
      expect(
        find.byTooltip('Escrever para Rosa Lima pelo WhatsApp'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('turnos cancelados por la clienta (spec 009, RF-18)', () {
    /// [base] cancelado; por la clienta si [byClient].
    AppointmentModel cancelled({bool byClient = true}) {
      final base = appointment(status: 'cancelled');
      return AppointmentModel(
        id: base.id,
        clientId: base.clientId,
        clientName: base.clientName,
        clientPhone: base.clientPhone,
        startTime: base.startTime,
        endTime: base.endTime,
        status: base.status,
        createdAt: base.createdAt,
        booked: base.booked,
        cancelledByClient: byClient,
      );
    }

    testWidgets('el que canceló la clienta lo dice', (tester) async {
      await pump(tester, cancelled());
      expect(find.text('CANCELADO'), findsOneWidget);
      expect(find.text('CANCELADO POR LA CLIENTA'), findsOneWidget);
    });

    testWidgets('en portugués', (tester) async {
      await pump(tester, cancelled(), language: 'pt');
      expect(find.text('CANCELADO PELA CLIENTE'), findsOneWidget);
    });

    testWidgets('uno cancelado sin cancelledBy (por el salón) no la lleva', (
      tester,
    ) async {
      await pump(tester, cancelled(byClient: false));
      expect(find.text('CANCELADO'), findsOneWidget);
      expect(find.text('CANCELADO POR LA CLIENTA'), findsNothing);
    });

    testWidgets('uno activo tampoco', (tester) async {
      await pump(tester, appointment());
      expect(find.text('CANCELADO POR LA CLIENTA'), findsNothing);
    });
  });

  group('turnos de una cuenta eliminada (spec 009, RF-35)', () {
    AppointmentModel deleted({String status = 'waiting_confirmation'}) {
      final base = appointment(status: status);
      return AppointmentModel(
        id: base.id,
        clientId: base.clientId,
        clientName: base.clientName,
        clientPhone: base.clientPhone,
        startTime: base.startTime,
        endTime: base.endTime,
        status: base.status,
        createdAt: base.createdAt,
        booked: base.booked,
        accountDeleted: true,
      );
    }

    testWidgets('lo dice, y conserva el nombre y el WhatsApp', (tester) async {
      await pump(tester, deleted());
      expect(find.text('CUENTA ELIMINADA'), findsOneWidget);
      expect(find.text('Ana Herrera'), findsOneWidget);
      expect(find.text('SIN CUENTA'), findsNothing);
    });

    testWidgets('también cancelado', (tester) async {
      await pump(tester, deleted(status: 'cancelled'));
      expect(find.text('CUENTA ELIMINADA'), findsOneWidget);
    });

    testWidgets('en portugués', (tester) async {
      await pump(tester, deleted(), language: 'pt');
      expect(find.text('CONTA EXCLUÍDA'), findsOneWidget);
    });

    testWidgets('uno de una cuenta que sigue no la lleva', (tester) async {
      await pump(tester, appointment());
      expect(find.text('CUENTA ELIMINADA'), findsNothing);
    });
  });
}
