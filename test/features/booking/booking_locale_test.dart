import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/booking_steps.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba.
DateTime at(int hour) => DateTime.utc(2026, 11, 10, hour);

BusySlot busy(DateTime start, DateTime end) =>
    BusySlot(id: 'x', start: fromSalon(start), end: fromSalon(end));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Lo reservado, sus avisos y sus diálogos abiertos cambian de idioma al
/// cambiar el de la interfaz (spec 005, RF-50).
void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const BookingView(),
      overrides: bookingDataOverrides(bookings: bookings),
    );
    await settle(tester);
  }

  Future<void> toPortuguese(WidgetTester tester) async {
    await appContainer(tester)
        .read(languagePreferenceProvider.notifier)
        .select(AppLanguage.pt);
    await settle(tester);
  }

  testWidgets('el diálogo de confirmación abierto', (tester) async {
    await pump(tester);
    await openBookingConfirmation(tester, settle: () => settle(tester));
    expect(find.text('Confirmar turno'), findsOneWidget);

    await toPortuguese(tester);
    expect(find.text('Confirmar horário'), findsOneWidget);
    expect(
      find.text('O horário ficará aguardando a confirmação da Beidis.'),
      findsOneWidget,
    );
  });

  testWidgets('el aviso al guardar', (tester) async {
    await pump(tester);
    bookings.checkData = (
      busy: [busy(at(10), at(11))],
      mine: const <AppointmentModel>[],
    );
    await openBookingConfirmation(tester, settle: () => settle(tester));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await settle(tester);
    expect(
      find.text('Esa hora acaba de ocuparse. Elige otra.'),
      findsOneWidget,
    );

    await toPortuguese(tester);
    expect(
      find.text('Esse horário acabou de ser ocupado. Escolha outro.'),
      findsOneWidget,
    );
  });

  testWidgets('el aviso de lo elegido', (tester) async {
    await pump(tester);
    await tester.tap(find.text('10:00'));
    await settle(tester);
    bookings.emitBusy([busy(at(10), at(11))]);
    await settle(tester);
    expect(
      find.text('La hora elegida ya no está disponible. Elige otra.'),
      findsOneWidget,
    );

    await toPortuguese(tester);
    expect(
      find.text('O horário escolhido não está mais disponível. Escolha outro.'),
      findsOneWidget,
    );
  });

  testWidgets('el aviso de éxito', (tester) async {
    await pump(tester);
    await openBookingConfirmation(tester, settle: () => settle(tester));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await settle(tester);

    await toPortuguese(tester);
    expect(
      find.text(
        'Reserva criada com sucesso! Aguardando confirmação da '
        'administradora.',
      ),
      findsOneWidget,
    );
  });
}
