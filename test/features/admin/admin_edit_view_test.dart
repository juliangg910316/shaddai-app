import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_edit_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/admin_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La vista de edición de la admin (spec 008, RF-19, RF-22, RF-27, RF-28,
/// RF-34, RF-35).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón. El turno de Ana es
/// el viernes 20, de 10:00 a 10:45, con el spa de manos (45 minutos).
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
);
final bea = UserModel(
  uid: 'bea',
  email: 'bea@example.com',
  displayName: 'Beatriz',
  phoneNumber: '+55 41 99222-0000',
);

AppointmentModel anaAppointment() => AppointmentModel(
  id: 't1',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(at(20, 10)),
  endTime: fromSalon(at(20, 10, 45)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 'spa',
    name: BilingualText(es: 'Spa de manos', pt: 'Spa das mãos'),
    priceCents: 5500,
    durationMinutes: 45,
  ),
);

Future<void> settle(WidgetTester tester) => settleWeb(tester);

void main() {
  late FakeBookingRepository bookings;

  setUp(() {
    bookings = FakeBookingRepository(
      active: [anaAppointment()],
      busy: [
        BusySlot(
          id: 't1',
          start: fromSalon(at(20, 10)),
          end: fromSalon(at(20, 10, 45)),
        ),
      ],
    );
  });

  List<Override> overrides({int margin = 0}) => [
    ...bookingScheduleOverrides(
      bookings: bookings,
      settings: CalendarSettingsModel(
        openingHours: CalendarSettingsModel.defaultSettings().openingHours,
        globalSlotDurationMinutes: 30,
        blockedDates: const [],
        editMarginMinutes: margin,
      ),
    ),
    adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
    adminAppointmentsProvider.overrideWith(
      (ref) => Stream.value([anaAppointment()]),
    ),
  ];

  /// La edición del turno [id], abierta desde su dirección.
  Future<void> open(
    WidgetTester tester, {
    String id = 't1',
    bool web = false,
    int margin = 0,
    String language = 'es',
  }) async {
    final location = '/admin/appointments/$id/edit';
    final users = FakeUserRepository(users: [ana, bea, testAdmin]);
    if (web) {
      await pumpWebApp(
        tester,
        location: location,
        user: testAdmin,
        userRepository: users,
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
        stored: {'language': language},
        height: 2400,
        overrides: overrides(margin: margin),
      );
    } else {
      await pumpMobileApp(
        tester,
        location: location,
        user: testAdmin,
        userRepository: users,
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
        stored: {'language': language},
        height: 2400,
        overrides: overrides(margin: margin),
      );
    }
    await settle(tester);
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(AlertDialog), matching: finder);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> saveChanges(WidgetTester tester) =>
      tap(tester, find.text('GUARDAR CAMBIOS'));

  testWidgets('se abre desde la agenda con todo cargado, con "Guardar '
      'cambios" y "Cancelar" (RF-19)', (tester) async {
    await pumpMobileApp(
      tester,
      location: '/admin',
      user: testAdmin,
      userRepository: FakeUserRepository(users: [ana, bea, testAdmin]),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      height: 2400,
      overrides: overrides(),
    );
    await settle(tester);
    await tap(tester, find.text('EDITAR'));

    expect(find.byType(AdminAppointmentEditView), findsOneWidget);
    final c = appContainer(tester);
    expect(c.read(adminEditProvider), 't1');
    expect(c.read(bookingSelectionProvider).selection.start, at(20, 10));
    expect(find.text('Ana Souza'), findsWidgets);
    expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
    expect(find.text('CANCELAR'), findsOneWidget);
  });

  testWidgets('sin cambios: lo avisa y no abre el diálogo (RF-26)', (
    tester,
  ) async {
    await open(tester);
    await saveChanges(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('No cambiaste nada.'), findsOneWidget);
    expect(bookings.adminEdits, isEmpty);
  });

  group('el diálogo (RF-27)', () {
    testWidgets('el antes y el después de la persona, "quedará confirmado" '
        'y el aviso del margen con una clienta con cuenta', (tester) async {
      // Un margen de 20 días: el turno del viernes 20 ya está dentro.
      await open(tester, margin: 20 * 24 * 60);
      appContainer(tester)
          .read(bookingRecipientProvider.notifier)
          .restore(AccountRecipient.of(bea));
      await settle(tester);
      await saveChanges(tester);

      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Para quién, cambia. Antes: Ana Souza. Después: Beatriz.',
        ),
        findsOneWidget,
      );
      expect(
        inDialog(find.text('El turno quedará confirmado.')),
        findsOneWidget,
      );
      expect(
        inDialog(find.textContaining('Beatriz no podrá cambiar este turno')),
        findsOneWidget,
      );
      expect(inDialog(find.textContaining('volverá a esperar')), findsNothing);
    });

    testWidgets('sin cuenta, sin el aviso del margen', (tester) async {
      await open(tester, margin: 20 * 24 * 60);
      appContainer(tester)
          .read(bookingRecipientProvider.notifier)
          .restore(
            const GuestRecipient(
              name: 'Rosa Lima',
              phone: '41 99333-0000',
              consent: true,
            ),
          );
      await settle(tester);
      await saveChanges(tester);

      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);
      expect(
        inDialog(find.textContaining('no podrá cambiar este turno')),
        findsNothing,
      );
    });

    testWidgets('al cambiar de idioma con el diálogo abierto, cambia', (
      tester,
    ) async {
      await open(tester);
      await tap(tester, find.text('11:00'));
      await saveChanges(tester);
      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);

      await appContainer(tester)
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await settle(tester);

      expect(inDialog(find.text('Confirmar alterações')), findsOneWidget);
      expect(
        inDialog(find.text('O horário ficará confirmado.')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Para quem: Ana Souza'), findsOneWidget);
    });
  });

  for (final web in [false, true]) {
    final platform = web ? 'Web' : 'Android/iOS';

    testWidgets('al guardar, vuelve a la agenda en el día del turno con el '
        'aviso ($platform, RF-28)', (tester) async {
      await open(tester, web: web);
      await tap(tester, find.text('11:00'));
      await saveChanges(tester);
      await tap(tester, inDialog(find.text('CONFIRMAR')));

      expect(bookings.adminEdits.single.start, fromSalon(at(20, 11)));
      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(find.byType(AdminAppointmentEditView), findsNothing);
      expect(find.text('Turno de Ana Souza guardado.'), findsOneWidget);
      final c = appContainer(tester);
      expect(c.read(adminSelectedDateProvider), DateTime.utc(2026, 11, 20));
      expect(c.read(adminEditProvider), isNull);
      if (web) expect(webLocation(tester).path, '/admin');
    });

    testWidgets('"Cancelar" sale sin cambiar nada ($platform, RF-35)', (
      tester,
    ) async {
      await open(tester, web: web);
      await tap(tester, find.text('11:00'));
      await tap(tester, find.text('CANCELAR'));

      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(bookings.adminEdits, isEmpty);
      final c = appContainer(tester);
      expect(c.read(adminEditProvider), isNull);
      expect(c.read(editTargetProvider), isNull);
    });

    testWidgets('un turno que no existe: el aviso y "Volver a la agenda" '
        '($platform)', (tester) async {
      await open(tester, id: 'nada', web: web);
      expect(find.text('No se encontró ese turno.'), findsOneWidget);
      await tap(tester, find.text('VOLVER A LA AGENDA'));
      expect(find.byType(AdminDashboardView), findsOneWidget);
    });
  }

  testWidgets('el botón atrás sale sin cambiar nada (RF-35)', (tester) async {
    await pumpMobileApp(
      tester,
      location: '/admin',
      user: testAdmin,
      userRepository: FakeUserRepository(users: [ana, bea, testAdmin]),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      height: 2400,
      overrides: overrides(),
    );
    await settle(tester);
    await tap(tester, find.text('EDITAR'));
    await tap(tester, find.text('11:00'));

    await tester.tap(find.byType(BackButton));
    await settle(tester);

    expect(find.byType(AdminDashboardView), findsOneWidget);
    expect(bookings.adminEdits, isEmpty);
    expect(appContainer(tester).read(adminEditProvider), isNull);
  });

  testWidgets('la ventana es la de la admin, 365 días; y guarda un día a más '
      'de 60 (RF-20)', (tester) async {
    await open(tester);
    final calendar = tester.widget<TableCalendar<dynamic>>(
      find.byType(TableCalendar),
    );
    expect(calendar.lastDay, DateTime.utc(2027, 11, 10));
    // Viernes 28/5/2027, a 199 días: se puede elegir.
    expect(calendar.enabledDayPredicate!(DateTime.utc(2027, 5, 28)), isTrue);

    final c = appContainer(tester);
    final selection = c.read(bookingSelectionProvider).selection;
    c
        .read(bookingSelectionProvider.notifier)
        .restore(
          BookingSelection(
            day: DateTime.utc(2027, 5, 28),
            start: DateTime.utc(2027, 5, 28, 11),
            item: selection.item,
            addonIds: selection.addonIds,
          ),
        );
    await settle(tester);
    await saveChanges(tester);
    await tap(tester, inDialog(find.text('CONFIRMAR')));

    expect(
      bookings.adminEdits.single.start,
      fromSalon(DateTime.utc(2027, 5, 28, 11)),
    );
  });

  group('"Para quién" en la edición (RF-23, RF-24)', () {
    Future<void> change(WidgetTester tester) =>
        tap(tester, find.text('CAMBIAR'));

    Future<void> confirm(WidgetTester tester) async {
      await saveChanges(tester);
      await tap(tester, inDialog(find.text('CONFIRMAR')));
    }

    testWidgets('cambia a otra clienta con cuenta con el buscador', (
      tester,
    ) async {
      await open(tester);
      await change(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre o WhatsApp de la clienta'),
        'beat',
      );
      await settle(tester);
      await tap(tester, find.text('Beatriz'));
      await confirm(tester);

      final person = bookings.adminEdits.single.person!;
      expect(person.clientId, 'bea');
      expect(person.clientName, 'Beatriz');
    });

    testWidgets('cambia a una persona sin cuenta, con su nombre, su WhatsApp '
        'y la casilla', (tester) async {
      await open(tester);
      await change(tester);
      await tap(tester, find.text('PERSONA SIN CUENTA'));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Carla Lima');
      await tester.enterText(fields.at(1), '41 99333-0000');
      await settle(tester);
      await tap(
        tester,
        find.text(
          'La persona acepta dar su nombre y su WhatsApp para este turno.',
        ),
      );
      await confirm(tester);

      final person = bookings.adminEdits.single.person!;
      expect(person.clientId, isNull);
      expect(person.clientName, 'Carla Lima');
    });

    testWidgets('el turno de una persona sin cuenta llega con la casilla '
        'marcada, y se corrige su nombre', (tester) async {
      final guest = AppointmentModel(
        id: 'g1',
        clientId: null,
        clientName: 'Dora Reis',
        clientPhone: '+55 41 99444-0000',
        startTime: fromSalon(at(20, 10)),
        endTime: fromSalon(at(20, 10, 45)),
        status: 'confirmed',
        createdAt: DateTime.utc(2026, 11, 1),
        createdByAdmin: true,
        booked: anaAppointment().booked,
      );
      bookings
        ..active = [guest]
        ..busy = [
          BusySlot(
            id: 'g1',
            start: fromSalon(at(20, 10)),
            end: fromSalon(at(20, 10, 45)),
          ),
        ];
      await open(tester, id: 'g1');

      final consent = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(
            'La persona acepta dar su nombre y su WhatsApp para este turno.',
          ),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(consent.value, isTrue);
      final name = find.byType(TextField).first;
      expect(tester.widget<TextField>(name).controller!.text, 'Dora Reis');
      await tester.enterText(name, 'Dora Reis Lima');
      // Sale del campo, como al agendar (spec 007).
      await tester.tap(find.byType(TextField).at(1));
      await settle(tester);
      await confirm(tester);

      final person = bookings.adminEdits.single.person!;
      expect(person.clientId, isNull);
      expect(person.clientName, 'Dora Reis Lima');
    });
  });

  testWidgets('si el turno se cancela mientras se edita, lo avisa y vuelve a '
      'la agenda (RF-30)', (tester) async {
    await open(tester);
    bookings.emitAppointment('t1', null);
    await settle(tester);

    expect(
      find.text('Ese turno ya no está activo: se canceló o terminó.'),
      findsOneWidget,
    );
    expect(find.byType(AdminDashboardView), findsOneWidget);
  });
}
