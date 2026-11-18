import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/presentation/admin_closure_form_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/features/admin/presentation/admin_closures_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La pantalla de cierres de la admin (spec 008, RF-1, RF-2, RF-7, RF-8,
/// RF-10).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón (bookingTestNow).
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

ClosureModel closure(String id, DateTime start, DateTime end) =>
    ClosureModel(id: id, start: fromSalon(start), end: fromSalon(end));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeConfigRepository config;

  setUp(() => config = FakeConfigRepository());

  List<Override> overrides() => [
    configRepositoryProvider.overrideWithValue(config),
    clockProvider.overrideWithValue(() => bookingTestNow),
    salonNowProvider.overrideWith(
      (ref) => Stream.value(toSalon(bookingTestNow)),
    ),
  ];

  Future<void> pump(WidgetTester tester, {String language = 'es'}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminClosuresView(),
      overrides: overrides(),
    );
    await settle(tester);
  }

  void blocked(List<String> dates) => config.settings = CalendarSettingsModel(
    openingHours: CalendarSettingsModel.defaultSettings().openingHours,
    globalSlotDurationMinutes: 30,
    blockedDates: dates,
  );

  /// La tarjeta del cierre [id] o de la fecha bloqueada [id].
  Finder card(String id) => find.byKey(ValueKey('closure-$id'));

  Finder inCard(String id, String text) =>
      find.descendant(of: card(id), matching: find.text(text));

  testWidgets('la lista ordenada, con sus fechas, sus horas o "Todo el '
      'día", y las fechas bloqueadas (RF-1, RF-8)', (tester) async {
    config.closures = [
      closure('dias', dayOf(20), dayOf(23)),
      closure('franja', at(11, 13), at(11, 14, 30)),
    ];
    blocked(['2026-11-15', '2026-11-01']);
    await pump(tester);

    expect(find.text('Cierres'), findsOneWidget);
    expect(
      inCard('franja', 'Miércoles, 11 de noviembre de 2026'),
      findsOneWidget,
    );
    expect(inCard('franja', '13:00 – 14:30'), findsOneWidget);
    expect(
      inCard('2026-11-15', 'Domingo, 15 de noviembre de 2026'),
      findsOneWidget,
    );
    expect(inCard('2026-11-15', 'Todo el día'), findsOneWidget);
    expect(
      inCard(
        'dias',
        'Del viernes, 20 de noviembre de 2026 al domingo, 22 de noviembre '
            'de 2026',
      ),
      findsOneWidget,
    );
    expect(inCard('dias', 'Todo el día'), findsOneWidget);
    // La fecha bloqueada pasada no sale.
    expect(card('2026-11-01'), findsNothing);

    final ys = [
      for (final id in ['franja', '2026-11-15', 'dias'])
        tester.getTopLeft(card(id)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('NUEVO CIERRE'), findsOneWidget);
  });

  testWidgets('en portugués', (tester) async {
    config.closures = [closure('franja', at(11, 13), at(11, 14, 30))];
    await pump(tester, language: 'pt');
    expect(find.text('Fechamentos'), findsOneWidget);
    expect(find.text('NOVO FECHAMENTO'), findsOneWidget);
    expect(inCard('franja', '13:00 – 14:30'), findsOneWidget);
  });

  testWidgets('sin cierres: el texto y "Nuevo cierre" (RF-2)', (tester) async {
    await pump(tester);
    expect(find.text('No hay cierres próximos.'), findsOneWidget);
    expect(find.text('NUEVO CIERRE'), findsOneWidget);
  });

  testWidgets('con un error: el aviso y "Reintentar", sin "Nuevo cierre"; '
      'al reintentar, vuelven a pedirse (RF-10)', (tester) async {
    await pump(tester);
    config.failClosures(Exception('sin red'));
    await settle(tester);

    expect(find.text('No se pudieron cargar los cierres.'), findsOneWidget);
    expect(find.text('NUEVO CIERRE'), findsNothing);
    expect(find.textContaining('sin red'), findsNothing);

    final requests = config.closureRequests.length;
    await tester.tap(find.text('REINTENTAR'));
    await settle(tester);
    expect(find.text('No se pudieron cargar los cierres.'), findsNothing);
    expect(config.closureRequests.length, greaterThan(requests));
  });

  group('"Quitar" (RF-7, RF-8, RF-11)', () {
    Future<void> tapRemove(WidgetTester tester, String id) async {
      await tester.tap(
        find.descendant(of: card(id), matching: find.byType(IconButton)),
      );
      await settle(tester);
    }

    testWidgets('pide confirmación; al cancelar, no hace nada', (tester) async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      await pump(tester);

      await tapRemove(tester, 'c1');
      expect(find.text('¿Quitar este cierre?'), findsOneWidget);
      expect(
        find.text('Esas horas volverán a estar libres para reservar.'),
        findsOneWidget,
      );
      await tester.tap(find.text('CANCELAR'));
      await settle(tester);

      expect(config.deleted, isEmpty);
      expect(card('c1'), findsOneWidget);
    });

    testWidgets('al confirmar, lo quita y avisa', (tester) async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      await pump(tester);

      await tapRemove(tester, 'c1');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('QUITAR'),
        ),
      );
      await settle(tester);

      expect(config.deleted, ['c1']);
      expect(find.text('Cierre quitado.'), findsOneWidget);
    });

    testWidgets('una fecha bloqueada se quita de la lista de fechas', (
      tester,
    ) async {
      blocked(['2026-11-15']);
      await pump(tester);

      await tapRemove(tester, '2026-11-15');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('QUITAR'),
        ),
      );
      await settle(tester);
      expect(config.removedBlockedDates, ['2026-11-15']);
    });

    testWidgets('si falla, avisa y el cierre sigue', (tester) async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      await pump(tester);
      config.saveError = Exception('sin red');

      await tapRemove(tester, 'c1');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('QUITAR'),
        ),
      );
      await settle(tester);

      expect(
        find.text('No se pudo quitar el cierre. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(card('c1'), findsOneWidget);
    });

    testWidgets('el botón mide 48 px', (tester) async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      await pump(tester);
      final size = tester.getSize(
        find.descendant(of: card('c1'), matching: find.byType(IconButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('el botón "Cierres" del panel (RF-1)', () {
    List<Override> panel() => [
      ...overrides(),
      adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
    ];

    for (final web in [false, true]) {
      testWidgets('abre la pantalla (${web ? 'Web' : 'Android/iOS'}), con '
          '48 px y tooltip', (tester) async {
        if (web) {
          await pumpWebApp(
            tester,
            location: '/admin',
            user: testAdmin,
            overrides: panel(),
          );
        } else {
          await pumpMobileApp(
            tester,
            location: '/admin',
            user: testAdmin,
            overrides: panel(),
          );
        }
        await settleWeb(tester);

        final button = find.ancestor(
          of: find.byTooltip('Cierres'),
          matching: find.byType(IconButton),
        );
        expect(button, findsOneWidget);
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));

        await tester.tap(button);
        await settleWeb(tester);
        expect(find.byType(AdminClosuresView), findsOneWidget);
        expect(find.text('No hay cierres próximos.'), findsOneWidget);
      });
    }
  });

  group('nuevo cierre (RF-3 a RF-6, RF-11)', () {
    late FakeBookingRepository bookings;
    late GoRouter router;

    setUp(() => bookings = FakeBookingRepository());

    /// Un turno de Ana el martes 10 de 9:30 a 10:15, que choca con la franja
    /// por defecto (de 9:00 a 10:00 de hoy).
    final ana = AppointmentModel(
      id: 'a1',
      clientId: 'ana',
      clientName: 'Ana Souza',
      clientPhone: '41 99111-0000',
      startTime: fromSalon(at(10, 9, 30)),
      endTime: fromSalon(at(10, 10, 15)),
      status: 'confirmed',
      createdAt: DateTime.utc(2026, 11, 1),
      booked: const BookedServiceModel(
        kind: BookedKind.service,
        id: 's1',
        name: BilingualText(es: 'Manicura', pt: 'Manicure'),
        priceCents: 3000,
        durationMinutes: 45,
      ),
    );

    /// La lista de cierres, con "Nuevo cierre" ya abierto.
    Future<void> open(WidgetTester tester, {bool web = false}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 2000);
      addTearDown(tester.view.reset);
      router = GoRouter(
        initialLocation: '/admin/closures',
        routes: [
          GoRoute(
            path: '/admin/closures',
            builder: (context, state) => const AdminClosuresView(),
          ),
          GoRoute(
            path: '/admin/closures/new',
            builder: (context, state) => const AdminClosureFormView(),
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
        stored: const {'language': 'es'},
        router: router,
        overrides: [
          ...overrides(),
          bookingRepositoryProvider.overrideWithValue(bookings),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          isWebProvider.overrideWithValue(web),
        ],
      );
      await settle(tester);
      await tester.tap(find.text('NUEVO CIERRE'));
      await settle(tester);
      expect(find.byType(AdminClosureFormView), findsOneWidget);
    }

    Finder field(String name) => find.byKey(ValueKey('closure-field-$name'));

    Finder inField(String name, String text) =>
        find.descendant(of: field(name), matching: find.text(text));

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('GUARDAR'));
      await tester.tap(find.text('GUARDAR'));
      await settle(tester);
    }

    /// Elige el día [day] de noviembre en el selector del campo [name].
    Future<void> pickDay(WidgetTester tester, String name, int day) async {
      await tester.tap(
        find.descendant(of: field(name), matching: find.byType(OutlinedButton)),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('$day'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await settle(tester);
    }

    Future<void> chooseKind(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await settle(tester);
    }

    testWidgets('"Unas horas" pide la fecha y las horas; "Días enteros", el '
        'primer y el último día (RF-3)', (tester) async {
      await open(tester);

      expect(find.text('Nuevo cierre'), findsOneWidget);
      expect(
        inField('date', 'Martes, 10 de noviembre de 2026'),
        findsOneWidget,
      );
      expect(inField('from', '9:00'), findsOneWidget);
      expect(inField('to', '10:00'), findsOneWidget);
      expect(field('first'), findsNothing);

      await chooseKind(tester, 'Días enteros');
      expect(field('from'), findsNothing);
      expect(
        inField('first', 'Martes, 10 de noviembre de 2026'),
        findsOneWidget,
      );
      expect(
        inField('last', 'Martes, 10 de noviembre de 2026'),
        findsOneWidget,
      );
    });

    testWidgets('las horas van de 0:00 a 23:45 en pasos de 15 minutos '
        '(RF-3)', (tester) async {
      await open(tester);
      for (final name in ['from', 'to']) {
        final dropdown = tester.widget<DropdownButton<int>>(
          find.descendant(
            of: field(name),
            matching: find.byType(DropdownButton<int>),
          ),
        );
        final values = [for (final item in dropdown.items!) item.value!];
        expect(values, [for (var m = 0; m < 24 * 60; m += 15) m]);
      }
    });

    testWidgets('las fechas se eligen de hoy a hoy + 365 días (RF-3, RF-4)', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.descendant(
          of: field('date'),
          matching: find.byType(OutlinedButton),
        ),
      );
      await settle(tester);
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 11, 10));
      expect(picker.lastDate, DateTime(2027, 11, 10));
    });

    testWidgets('cada error sale bajo su campo y no se guarda (RF-4)', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.descendant(of: field('to'), matching: find.text('10:00')),
      );
      await settle(tester);
      await tester.tap(find.text('9:00').last);
      await settle(tester);
      await save(tester);

      expect(
        inField('to', 'La hora de fin debe ser posterior a la de inicio.'),
        findsOneWidget,
      );
      expect(config.created, isEmpty);
      expect(bookings.activeFetches, isEmpty);

      await chooseKind(tester, 'Días enteros');
      await pickDay(tester, 'first', 20);
      await pickDay(tester, 'last', 12);
      await save(tester);
      expect(
        inField('last', 'El último día no puede ser anterior al primero.'),
        findsOneWidget,
      );
      expect(config.created, isEmpty);
    });

    testWidgets('sin choques: guarda, avisa "Cierre guardado" y vuelve a la '
        'lista (RF-6)', (tester) async {
      await open(tester);
      await chooseKind(tester, 'Días enteros');
      await pickDay(tester, 'first', 20);
      await pickDay(tester, 'last', 22);
      await save(tester);

      final saved = config.created.single;
      expect(saved.start, fromSalon(dayOf(20)));
      expect(saved.end, fromSalon(dayOf(23)));
      expect(find.text('Cierre guardado.'), findsOneWidget);
      expect(find.byType(AdminClosureFormView), findsNothing);
      expect(find.byType(AdminClosuresView), findsOneWidget);
    });

    testWidgets('si falla, avisa y conserva lo elegido (RF-11)', (
      tester,
    ) async {
      config.saveError = Exception('sin red');
      await open(tester);
      await chooseKind(tester, 'Días enteros');
      await pickDay(tester, 'first', 20);
      await pickDay(tester, 'last', 22);
      await save(tester);

      expect(
        find.text('No se pudo guardar el cierre. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(AdminClosureFormView), findsOneWidget);
      expect(
        inField('first', 'Viernes, 20 de noviembre de 2026'),
        findsOneWidget,
      );
    });

    testWidgets('con choques: no guarda y lista los turnos con fecha, hora, '
        'persona y lo reservado (RF-5)', (tester) async {
      bookings.active = [ana];
      await open(tester);
      await save(tester);

      expect(config.created, isEmpty);
      expect(find.text('Hay turnos en ese tiempo'), findsOneWidget);
      expect(
        find.text('Muévelos o cancélalos y vuelve a guardar el cierre.'),
        findsOneWidget,
      );
      final conflict = find.byKey(const ValueKey('closure-conflict-a1'));
      for (final text in [
        'Martes, 10 de noviembre de 2026',
        '9:30 – 10:15',
        'Ana Souza',
        'Manicura',
        'EDITAR',
        'CANCELAR',
      ]) {
        expect(
          find.descendant(of: conflict, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('"Cancelar" pide confirmación y cancela; luego "Guardar" '
        'vuelve a comprobar y guarda (RF-5, RF-6)', (tester) async {
      bookings.active = [ana];
      await open(tester);
      await save(tester);
      final conflict = find.byKey(const ValueKey('closure-conflict-a1'));

      await tester.ensureVisible(conflict);
      await tester.tap(
        find.descendant(of: conflict, matching: find.text('CANCELAR')),
      );
      await settle(tester);
      expect(find.text('¿Cancelar el turno de Ana Souza?'), findsOneWidget);
      expect(find.text('La hora quedará libre.'), findsOneWidget);
      await tester.tap(find.text('VOLVER'));
      await settle(tester);
      expect(bookings.statusChanges, isEmpty);

      await tester.tap(
        find.descendant(of: conflict, matching: find.text('CANCELAR')),
      );
      await settle(tester);
      await tester.tap(find.text('CANCELAR TURNO'));
      await settle(tester);
      expect(bookings.statusChanges, [(id: 'a1', status: 'cancelled')]);
      expect(conflict, findsNothing);

      // En el servidor ya está cancelado.
      bookings.active = const [];
      await save(tester);
      expect(bookings.activeFetches, hasLength(2));
      expect(config.created, hasLength(1));
      expect(find.text('Cierre guardado.'), findsOneWidget);
    });

    for (final web in [false, true]) {
      testWidgets('"Editar" abre la edición del turno '
          '(${web ? 'Web' : 'Android/iOS'})', (tester) async {
        bookings.active = [ana];
        await open(tester, web: web);
        await save(tester);
        final conflict = find.byKey(const ValueKey('closure-conflict-a1'));
        await tester.ensureVisible(conflict);
        await tester.tap(
          find.descendant(of: conflict, matching: find.text('EDITAR')),
        );
        await settle(tester);

        // En Android/iOS con `push`: la página de arriba es la edición.
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/admin/appointments/a1/edit',
        );
        if (web) {
          // En Web con `go`: la dirección cambia (plan D-5).
          expect(
            router.routeInformationProvider.value.uri.path,
            '/admin/appointments/a1/edit',
          );
        }
        expect(find.text('editar a1'), findsOneWidget);
      });
    }
  });
}
