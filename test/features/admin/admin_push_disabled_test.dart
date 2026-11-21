import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_push.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// El aviso de "Avisos desactivados" en el panel y volver a leer el permiso
/// al volver a primer plano (spec 011, RF-17, RF-18; plan D-8, § 6; T8).
final admin = UserModel(
  uid: 'beidis',
  email: 'beidis@example.com',
  displayName: 'Beidis',
  role: 'admin',
  phoneNumber: '+5541999990000',
);

/// La agenda, sin turnos ni cierres: estos tests no los miran.
List<Override> get emptyAgenda => [
  ...bookingScheduleOverrides(bookings: FakeBookingRepository()),
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
];

const esTitle = 'Avisos desactivados';
const esBody =
    'Este teléfono no muestra los avisos de turnos. Para recibirlos, activa '
    'las notificaciones de la app en los ajustes del teléfono.';
const ptTitle = 'Avisos desativados';
const ptBody =
    'Este celular não mostra os avisos de horários. Para recebê-los, ative '
    'as notificações do app nos ajustes do celular.';

final card = find.byKey(const Key('admin-push-disabled'));

Future<FakePushRepository> pumpPanel(
  WidgetTester tester, {
  PushPermission permission = PushPermission.denied,
  Map<String, Object> stored = const {'language': 'es'},
}) async {
  final push = FakePushRepository(currentPermission: permission);
  await pumpMobileApp(
    tester,
    location: '/admin',
    user: admin,
    stored: stored,
    pushRepository: push,
    overrides: emptyAgenda,
  );
  await settleWeb(tester);
  return push;
}

/// La app pasa a segundo plano y vuelve.
Future<void> backToForeground(WidgetTester tester) async {
  final binding = tester.binding;
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
  await settleWeb(tester);
}

void main() {
  testWidgets('con el permiso denegado, el aviso sale arriba de la agenda '
      '(RF-17)', (tester) async {
    final push = await pumpPanel(tester);

    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(esTitle)), findsOne);
    expect(find.descendant(of: card, matching: find.text(esBody)), findsOne);
    // Arriba de la agenda: entre la cabecera verde y la lista.
    final header = find.byKey(const ValueKey('agenda-header'));
    final agenda = find.byKey(const ValueKey('agenda-body'));
    expect(
      tester.getTopLeft(card).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(header).dy),
    );
    expect(
      tester.getBottomLeft(card).dy,
      lessThanOrEqualTo(tester.getTopLeft(agenda).dy),
    );
    // No vuelve a pedir el permiso.
    expect(push.calls, isNot(contains('requestPermission')));
  });

  testWidgets('se lee como una frase (RF-17)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(tester);
    expect(find.bySemanticsLabel('$esTitle\n$esBody'), findsOneWidget);
    semantics.dispose();
  });

  for (final permission in [PushPermission.granted, PushPermission.notAsked]) {
    testWidgets('no sale con $permission', (tester) async {
      await pumpPanel(tester, permission: permission);
      expect(card, findsNothing);
      expect(find.text(esTitle), findsNothing);
    });
  }

  testWidgets('no sale en Web', (tester) async {
    await pumpWebApp(
      tester,
      location: '/admin',
      user: admin,
      pushRepository: FakePushRepository(
        currentPermission: PushPermission.denied,
      ),
      overrides: emptyAgenda,
    );
    await settleWeb(tester);
    expect(card, findsNothing);
  });

  testWidgets('al volver a primer plano con el permiso activado en los '
      'ajustes, desaparece y se registra el dispositivo (RF-18)', (
    tester,
  ) async {
    final push = await pumpPanel(tester);
    expect(card, findsOneWidget);
    expect(push.devices, isEmpty);

    push.currentPermission = PushPermission.granted;
    await backToForeground(tester);

    expect(card, findsNothing);
    expect(push.devices.single.uid, 'beidis');
  });

  testWidgets('al volver a primer plano sin activarlo, sigue', (tester) async {
    final push = await pumpPanel(tester);
    await backToForeground(tester);
    expect(card, findsOneWidget);
    expect(push.devices, isEmpty);
  });

  testWidgets('si se desactiva en los ajustes, aparece al volver', (
    tester,
  ) async {
    final push = await pumpPanel(tester, permission: PushPermission.granted);
    expect(card, findsNothing);

    push.currentPermission = PushPermission.denied;
    await backToForeground(tester);
    expect(card, findsOneWidget);
  });

  testWidgets('en portugués', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(tester, stored: const {'language': 'pt'});
    expect(find.descendant(of: card, matching: find.text(ptTitle)), findsOne);
    expect(find.descendant(of: card, matching: find.text(ptBody)), findsOne);
    expect(find.bySemanticsLabel('$ptTitle\n$ptBody'), findsOneWidget);
    semantics.dispose();
  });
}
