import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// Cambiar el WhatsApp desde el perfil (spec 009, RF-25 a RF-30).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón; su turno activo es
/// hoy a las 9:00.
AppointmentModel appointment({String status = 'confirmed'}) {
  final start = fromSalon(DateTime.utc(2026, 11, 10, 9));
  return AppointmentModel(
    id: 't1',
    clientId: testClient.uid,
    clientName: testClient.displayName,
    clientPhone: testClient.phoneNumber!,
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: bookingTestNow,
  );
}

final dialog = find.byType(AlertDialog);
Finder inDialog(Finder finder) => find.descendant(of: dialog, matching: finder);
final change = find.byKey(const ValueKey('profile-whatsapp-change'));
final saveButton = inDialog(find.text('GUARDAR'));

void main() {
  late FakeUserRepository users;
  late FakeBookingRepository bookings;

  setUp(() {
    users = FakeUserRepository(stored: testClient);
    bookings = FakeBookingRepository(mine: [appointment()]);
  });

  Future<void> pump(WidgetTester tester, {String language = 'es'}) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const ProfileView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          userStream: () => users.watchUser(testClient.uid),
        ),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.ensureVisible(change);
    await tester.pumpAndSettle();
    await tester.tap(change);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String phone) async {
    await tester.enterText(inDialog(find.byType(TextField)), phone);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  testWidgets('el perfil muestra su WhatsApp con "Cambiar" (RF-25)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Tu cuenta'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-whatsapp')),
        matching: find.text('+55 41 99999-0000'),
      ),
      findsOneWidget,
    );
    expect(change, findsOneWidget);
    expect(find.text('CAMBIAR'), findsOneWidget);
  });

  testWidgets('el diálogo trae el número actual escrito y el consentimiento '
      '(RF-26)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    expect(inDialog(find.text('Cambiar WhatsApp')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(inDialog(find.byType(TextField)))
          .controller
          ?.text,
      '+55 41 99999-0000',
    );
    expect(
      inDialog(find.textContaining('Beidis te escribe por WhatsApp')),
      findsOneWidget,
    );
  });

  testWidgets('un número no válido: error junto al campo, no se guarda '
      '(RF-27)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await save(tester, '12345');
    expect(users.whatsAppUpdates, isEmpty);
    expect(dialog, findsOneWidget);
    expect(
      inDialog(
        find.text('Escribe un número de WhatsApp válido (de 8 a 15 dígitos).'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('con turno activo, guarda la ficha y ese turno, y el perfil '
      'muestra el número nuevo sin recargar (RF-28)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await save(tester, ' 41 98888-7777 ');

    expect(users.whatsAppUpdates, [
      (uid: testClient.uid, phone: '41 98888-7777', activeAppointmentId: 't1'),
    ]);
    expect(dialog, findsNothing);
    expect(find.text('Tu WhatsApp se actualizó.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-whatsapp')),
        matching: find.text('41 98888-7777'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sin turno activo, solo la ficha (RF-28)', (tester) async {
    bookings.mine = [appointment(status: 'cancelled')];
    await pump(tester);
    await openDialog(tester);
    await save(tester, '41 98888-7777');
    expect(users.whatsAppUpdates.single.activeAppointmentId, isNull);
  });

  testWidgets('"Cancelar" conserva el número (RF-29)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await tester.enterText(inDialog(find.byType(TextField)), '41 98888-7777');
    await tester.tap(inDialog(find.text('CANCELAR')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(users.whatsAppUpdates, isEmpty);
    expect(find.text('+55 41 99999-0000'), findsOneWidget);
  });

  testWidgets('si falla: avisa sin detalles, conserva el número y deja '
      'reintentar (RF-30)', (tester) async {
    users.whatsAppError = Exception('permission-denied');
    await pump(tester);
    await openDialog(tester);
    await save(tester, '41 98888-7777');

    expect(dialog, findsOneWidget);
    expect(
      inDialog(find.text('No se pudo guardar. Inténtalo de nuevo.')),
      findsOneWidget,
    );
    expect(find.textContaining('permission'), findsNothing);

    users.whatsAppError = null;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(users.whatsAppUpdates.single.phone, '41 98888-7777');
    expect(dialog, findsNothing);
  });

  testWidgets('mientras guarda, no se puede guardar dos veces', (tester) async {
    final gate = Completer<void>();
    users.whatsAppGate = gate.future;
    await pump(tester);
    await openDialog(tester);
    await tester.enterText(inDialog(find.byType(TextField)), '41 98888-7777');
    await tester.tap(saveButton);
    await tester.pump();
    expect(inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    await tester.tap(saveButton, warnIfMissed: false);
    gate.complete();
    await tester.pumpAndSettle();
    expect(users.whatsAppUpdates, hasLength(1));
  });

  testWidgets('en portugués', (tester) async {
    await pump(tester, language: 'pt');
    expect(find.text('Sua conta'), findsOneWidget);
    expect(find.text('ALTERAR'), findsOneWidget);
    await openDialog(tester);
    expect(inDialog(find.text('Alterar WhatsApp')), findsOneWidget);
    expect(inDialog(find.text('SALVAR')), findsOneWidget);
  });
}
