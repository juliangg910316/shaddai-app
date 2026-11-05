import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/pump_app.dart';

/// Un turno de las 9:00 a las 10:30 (o de [start] a [end]), con lo
/// reservado si [booked].
AppointmentModel appointment({
  bool booked = true,
  DateTime? start,
  DateTime? end,
}) => AppointmentModel(
  id: 't1',
  clientId: 'u1',
  clientName: 'Ana Herrera',
  clientPhone: '+55 41 99999-0000',
  startTime: start ?? DateTime(2026, 11, 20, 9),
  endTime: end ?? DateTime(2026, 11, 20, 10, 30),
  status: 'waiting_confirmation',
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

/// El panel no lee ni guarda ajustes en estos tests.
class _UnusedConfigRepository implements ConfigRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

  Future<void> pump(
    WidgetTester tester,
    AppointmentModel shown, {
    String language = 'es',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        configRepositoryProvider.overrideWithValue(_UnusedConfigRepository()),
        adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
        adminAppointmentsProvider.overrideWith((ref) => Stream.value([shown])),
      ],
    );
    await tester.pumpAndSettle();
  }

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

    expect(bookings.statusChanges, [(id: 't1', status: 'cancelled')]);
  });
}
