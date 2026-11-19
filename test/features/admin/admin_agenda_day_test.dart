import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';

/// Recorrer los días de la agenda (spec 010, T4): el día del salón, "Hoy"
/// y el calendario.
///
/// "Ahora" es el 21/11/2026 a la 1:30 UTC: en Curitiba aún es el viernes
/// 20/11 a las 22:30, y en UTC ya es sábado. La agenda debe abrir en el 20.
final now = DateTime.utc(2026, 11, 21, 1, 30);

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester, {
    String language = 'es',
    DateTime? shown,
  }) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => now),
        salonNowProvider.overrideWith((ref) => Stream.value(toSalon(now))),
        isWebProvider.overrideWithValue(false),
        if (shown != null)
          adminSelectedDateProvider.overrideWith((ref) => shown),
      ],
    );
    await settle(tester);
  }

  DateTime selected(WidgetTester tester) =>
      appContainer(tester).read(adminSelectedDateProvider);

  final today = find.text('HOY');
  final dateButton = find.byKey(const ValueKey('agenda-date'));

  group('el día del salón (RF-1, RF-2)', () {
    testWidgets('abre en hoy del salón, aunque en UTC ya sea mañana', (
      tester,
    ) async {
      await pump(tester);
      expect(selected(tester), DateTime.utc(2026, 11, 20));
      expect(find.text('Viernes, 20 de noviembre de 2026'), findsOneWidget);
    });

    testWidgets('pide los turnos de medianoche a medianoche del salón', (
      tester,
    ) async {
      await pump(tester);
      expect(bookings.dayRequests.last, (
        from: DateTime.utc(2026, 11, 20, 3),
        to: DateTime.utc(2026, 11, 21, 3),
      ));
    });

    testWidgets('una fecha local guardada antes se lee como día del salón', (
      tester,
    ) async {
      await pump(tester, shown: DateTime(2026, 11, 25, 18));
      expect(bookings.dayRequests.last.from, DateTime.utc(2026, 11, 25, 3));
    });
  });

  group('"Hoy" (RF-3)', () {
    testWidgets('no sale en hoy', (tester) async {
      await pump(tester);
      expect(today, findsNothing);
    });

    testWidgets('sale en otro día y vuelve a hoy', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Día siguiente'));
      await settle(tester);
      expect(selected(tester), DateTime.utc(2026, 11, 21));
      expect(today, findsOneWidget);

      await tester.tap(today);
      await settle(tester);
      expect(selected(tester), DateTime.utc(2026, 11, 20));
      expect(today, findsNothing);
    });

    testWidgets('es un botón con nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, shown: DateTime.utc(2026, 11, 2));
      expect(
        tester.getSemantics(today),
        isSemantics(label: 'HOY', isButton: true, isEnabled: true),
      );
      semantics.dispose();
    });
  });

  group('el calendario (RF-4)', () {
    DatePickerDialog picker(WidgetTester tester) =>
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

    testWidgets('la fecha es un botón con nombre que abre el calendario en '
        'el día, entre −365 y +365 días', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, shown: DateTime.utc(2026, 12, 3));
      expect(find.byTooltip('Elegir fecha'), findsOneWidget);
      expect(tester.getSemantics(dateButton), isSemantics(isButton: true));

      await tester.tap(dateButton);
      await settle(tester);
      final dialog = picker(tester);
      expect(dialog.initialDate, DateTime(2026, 12, 3));
      expect(dialog.firstDate, DateTime(2025, 11, 20));
      expect(dialog.lastDate, DateTime(2027, 11, 20));
      semantics.dispose();
    });

    testWidgets('fuera de los límites, abre en el más cercano', (tester) async {
      await pump(tester, shown: DateTime.utc(2024, 1, 1));
      await tester.tap(dateButton);
      await settle(tester);
      expect(picker(tester).initialDate, DateTime(2025, 11, 20));
    });

    testWidgets('elegir un día muestra su agenda', (tester) async {
      await pump(tester);
      await tester.tap(dateButton);
      await settle(tester);
      await tester.tap(find.text('25'));
      await settle(tester);
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(ok));
      await settle(tester);

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(selected(tester), DateTime.utc(2026, 11, 25));
      expect(bookings.dayRequests.last.from, DateTime.utc(2026, 11, 25, 3));
      expect(find.text('Miércoles, 25 de noviembre de 2026'), findsOneWidget);
    });

    testWidgets('cerrar el calendario no cambia el día', (tester) async {
      await pump(tester);
      await tester.tap(dateButton);
      await settle(tester);
      final cancel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).cancelButtonLabel;
      await tester.tap(find.text(cancel));
      await settle(tester);
      expect(selected(tester), DateTime.utc(2026, 11, 20));
    });
  });

  group('día anterior y siguiente (RF-5)', () {
    testWidgets('sin límite, también fuera del calendario', (tester) async {
      await pump(tester, shown: DateTime.utc(2027, 11, 20));
      await tester.tap(find.byTooltip('Día siguiente'));
      await settle(tester);
      expect(selected(tester), DateTime.utc(2027, 11, 21));

      appContainer(tester)
          .read(adminSelectedDateProvider.notifier)
          .state = DateTime.utc(
        2025,
        11,
        20,
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Día anterior'));
      await settle(tester);
      expect(selected(tester), DateTime.utc(2025, 11, 19));
    });

    testWidgets('cruzan el fin de mes', (tester) async {
      await pump(tester, shown: DateTime.utc(2026, 11, 30));
      await tester.tap(find.byTooltip('Día siguiente'));
      await settle(tester);
      expect(selected(tester), DateTime.utc(2026, 12, 1));
    });
  });

  testWidgets('en portugués', (tester) async {
    await pump(tester, language: 'pt', shown: DateTime.utc(2026, 11, 2));
    expect(find.text('HOJE'), findsOneWidget);
    expect(find.byTooltip('Escolher data'), findsOneWidget);
  });
}
