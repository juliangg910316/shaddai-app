import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/features/admin/presentation/admin_closures_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

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
        find.descendant(of: card(id), matching: find.byTooltip('Quitar')),
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
        find.ancestor(
          of: find.descendant(
            of: card('c1'),
            matching: find.byTooltip('Quitar'),
          ),
          matching: find.byType(IconButton),
        ),
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
}
