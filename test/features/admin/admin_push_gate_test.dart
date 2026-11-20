import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_push.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La puerta de los avisos push en la app: la explicación del permiso
/// (spec 011, RF-15, RF-16; plan D-8, § 6; T6) y los avisos con la app
/// abierta y al tocarlos (RF-12 a RF-14; plan D-9, D-10; T7).
final admin = UserModel(
  uid: 'beidis',
  email: 'beidis@example.com',
  displayName: 'Beidis',
  role: 'admin',
  phoneNumber: '+5541999990000',
);

final client = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana',
  phoneNumber: '+5541988880000',
);

final dialog = find.byKey(const Key('admin-push-dialog'));

/// La agenda, sin turnos ni cierres: estos tests no los miran.
List<Override> get emptyAgenda => [
  ...bookingScheduleOverrides(bookings: FakeBookingRepository()),
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
];

/// La página de arriba: con `push`, la dirección no cambia.
String topLocation(WidgetTester tester) =>
    webRouter(tester).routerDelegate.currentConfiguration.last.matchedLocation;

Finder inDialog(Finder finder) => find.descendant(of: dialog, matching: finder);

void main() {
  group('la explicación del permiso (RF-15)', () {
    testWidgets('a la admin sin preguntar le explica los avisos', (
      tester,
    ) async {
      final push = FakePushRepository(
        currentPermission: PushPermission.notAsked,
      );
      await pumpMobileApp(tester, user: admin, pushRepository: push);

      expect(dialog, findsOneWidget);
      expect(inDialog(find.text('Avisos de turnos')), findsOneWidget);
      expect(
        inDialog(
          find.textContaining(
            'Te avisaremos en este teléfono cuando una clienta reserve',
          ),
        ),
        findsOneWidget,
      );
      expect(inDialog(find.text('Continuar')), findsOneWidget);
      // Aún no se ha pedido nada al sistema.
      expect(push.calls, isNot(contains('requestPermission')));
    });

    testWidgets('no se cierra tocando fuera ni con "atrás"', (tester) async {
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: FakePushRepository(
          currentPermission: PushPermission.notAsked,
        ),
      );

      await tester.tapAt(const Offset(4, 4));
      await settleWeb(tester);
      expect(dialog, findsOneWidget);

      await tester.binding.handlePopRoute();
      await settleWeb(tester);
      expect(dialog, findsOneWidget);
    });

    testWidgets('"Continuar" pide el permiso y registra el dispositivo; no '
        'vuelve a salir', (tester) async {
      final push = FakePushRepository(
        currentPermission: PushPermission.notAsked,
      );
      await pumpMobileApp(tester, user: admin, pushRepository: push);

      await tester.tap(inDialog(find.text('Continuar')));
      await settleWeb(tester);

      expect(dialog, findsNothing);
      expect(push.calls, contains('requestPermission'));
      expect(push.permissionAsked, isTrue);
      expect(push.devices.single.uid, 'beidis');

      // Otra vuelta de la sesión no la vuelve a mostrar.
      await settleWeb(tester);
      expect(dialog, findsNothing);
    });

    testWidgets('si la admin deniega el permiso, tampoco vuelve a salir', (
      tester,
    ) async {
      final push = FakePushRepository(
        currentPermission: PushPermission.notAsked,
        answer: PushPermission.denied,
      );
      await pumpMobileApp(tester, user: admin, pushRepository: push);

      await tester.tap(inDialog(find.text('Continuar')));
      await settleWeb(tester);
      await settleWeb(tester);

      expect(dialog, findsNothing);
      expect(push.devices, isEmpty);
      expect(push.calls.where((c) => c == 'requestPermission'), hasLength(1));
    });

    testWidgets('sale cuando la admin inicia sesión con la app abierta', (
      tester,
    ) async {
      final session = await pumpMobileApp(
        tester,
        pushRepository: FakePushRepository(
          currentPermission: PushPermission.notAsked,
        ),
      );
      expect(dialog, findsNothing);

      session.signIn(admin);
      await settleWeb(tester);
      expect(dialog, findsOneWidget);
    });

    testWidgets('en portugués', (tester) async {
      await pumpMobileApp(
        tester,
        user: admin,
        stored: const {'language': 'pt'},
        pushRepository: FakePushRepository(
          currentPermission: PushPermission.notAsked,
        ),
      );
      expect(inDialog(find.text('Avisos de horários')), findsOneWidget);
      expect(
        inDialog(
          find.textContaining(
            'Vamos avisar neste celular quando uma cliente agendar',
          ),
        ),
        findsOneWidget,
      );
      expect(inDialog(find.text('Continuar')), findsOneWidget);
    });

    testWidgets('al cambiar de idioma con la explicación abierta, cambia '
        '(RC-1)', (tester) async {
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: FakePushRepository(
          currentPermission: PushPermission.notAsked,
        ),
      );
      expect(inDialog(find.text('Avisos de turnos')), findsOneWidget);

      await appContainer(tester)
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await settleWeb(tester);
      expect(inDialog(find.text('Avisos de horários')), findsOneWidget);
    });
  });

  group('a nadie más (RF-16)', () {
    for (final (label, user, permission) in [
      ('a una clienta', client, PushPermission.notAsked),
      ('a un visitante', null, PushPermission.notAsked),
      ('a la admin con el permiso concedido', admin, PushPermission.granted),
      ('a la admin con el permiso denegado', admin, PushPermission.denied),
    ]) {
      testWidgets('no sale $label', (tester) async {
        final push = FakePushRepository(currentPermission: permission);
        await pumpMobileApp(tester, user: user, pushRepository: push);
        expect(dialog, findsNothing);
        expect(push.calls, isNot(contains('requestPermission')));
      });
    }

    testWidgets('a una clienta no le toca el repositorio', (tester) async {
      final push = FakePushRepository(
        currentPermission: PushPermission.notAsked,
      );
      await pumpMobileApp(tester, user: client, pushRepository: push);
      expect(push.calls, isEmpty);
    });

    testWidgets('en Web, ni a la admin, y no toca el repositorio', (
      tester,
    ) async {
      final push = FakePushRepository(
        currentPermission: PushPermission.notAsked,
      );
      await pumpWebApp(
        tester,
        overrides: emptyAgenda,
        location: '/admin',
        user: admin,
        pushRepository: push,
      );
      expect(dialog, findsNothing);
      expect(push.calls, isEmpty);
    });
  });

  testWidgets('la puerta arranca el controlador: con el permiso concedido, '
      'registra el dispositivo una vez', (tester) async {
    final push = FakePushRepository();
    await pumpMobileApp(tester, user: admin, pushRepository: push);
    await settleWeb(tester);
    expect(push.devices.single.uid, 'beidis');
    expect(push.calls.where((c) => c == 'registerDevice'), hasLength(1));
  });

  group('los avisos con la app abierta y al tocarlos (RF-12 a RF-14)', () {
    final notice = PushNotice.fromParts(
      title: 'Turno nuevo',
      body:
          'Ana Herrera · sábado 21 de noviembre, 10:00 · Manicura. '
          'Espera tu confirmación.',
      data: {'kind': 'created', 'appointmentId': 't1', 'day': '2026-11-21'},
    );

    DateTime agendaDayOf(WidgetTester tester) =>
        appContainer(tester).read(adminSelectedDateProvider);

    final viewButton = find.widgetWithText(TextButton, 'Ver');

    testWidgets('con la app abierta: el título, el texto y "Ver", sin '
        'moverse de donde está (RF-14)', (tester) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        overrides: emptyAgenda,
        location: '/profile',
        user: admin,
        pushRepository: push,
      );

      push.receiveNotice(notice);
      await settleWeb(tester);

      expect(find.text('Turno nuevo'), findsOneWidget);
      expect(
        find.text(
          'Ana Herrera · sábado 21 de noviembre, 10:00 · Manicura. '
          'Espera tu confirmación.',
        ),
        findsOneWidget,
      );
      expect(viewButton, findsOneWidget);
      expect(topLocation(tester), '/profile');
    });

    testWidgets('también sobre el panel', (tester) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        overrides: emptyAgenda,
        location: '/admin',
        user: admin,
        pushRepository: push,
      );
      push.receiveNotice(notice);
      await settleWeb(tester);
      expect(find.text('Turno nuevo'), findsOneWidget);
    });

    testWidgets('"Ver" abre la agenda en el día del turno (RF-12, RF-14)', (
      tester,
    ) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: push,
        overrides: emptyAgenda,
      );

      push.receiveNotice(notice);
      await settleWeb(tester);
      await tester.tap(viewButton);
      await settleWeb(tester);

      expect(topLocation(tester), '/admin');
      expect(agendaDayOf(tester), DateTime.utc(2026, 11, 21));
      expect(find.text('Turno nuevo'), findsNothing);
      // "Atrás" vuelve a donde estaba.
      expect(webRouter(tester).canPop(), isTrue);
    });

    testWidgets('el aviso que abrió la app cerrada abre la agenda de ese día '
        '(RF-12)', (tester) async {
      final push = FakePushRepository(initial: notice);
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: push,
        overrides: emptyAgenda,
      );
      await settleWeb(tester);

      expect(topLocation(tester), '/admin');
      expect(agendaDayOf(tester), DateTime.utc(2026, 11, 21));
    });

    testWidgets('el aviso tocado con la app en segundo plano, también '
        '(RF-12)', (tester) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: push,
        overrides: emptyAgenda,
      );

      push.openNotice(notice);
      await settleWeb(tester);

      expect(topLocation(tester), '/admin');
      expect(agendaDayOf(tester), DateTime.utc(2026, 11, 21));
    });

    testWidgets('con la agenda ya abierta, solo cambia el día', (tester) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        overrides: emptyAgenda,
        location: '/admin',
        user: admin,
        pushRepository: push,
      );
      expect(webRouter(tester).canPop(), isFalse);

      push.openNotice(notice);
      await settleWeb(tester);

      expect(topLocation(tester), '/admin');
      expect(agendaDayOf(tester), DateTime.utc(2026, 11, 21));
      expect(webRouter(tester).canPop(), isFalse);
    });

    testWidgets('un aviso tocado sin sesión no se guarda para después: '
        'iniciar sesión como admin no abre la agenda (RF-13)', (tester) async {
      final push = FakePushRepository(initial: notice);
      final session = await pumpMobileApp(
        tester,
        pushRepository: push,
        overrides: emptyAgenda,
      );
      expect(topLocation(tester), '/home');

      session.signIn(admin);
      await settleWeb(tester);
      expect(topLocation(tester), '/home');
    });

    for (final (label, user) in [('una clienta', client), ('nadie', null)]) {
      testWidgets('con la sesión de $label, ni se muestra ni navega '
          '(RF-13)', (tester) async {
        final push = FakePushRepository(initial: notice);
        await pumpMobileApp(
          tester,
          user: user,
          pushRepository: push,
          overrides: emptyAgenda,
        );
        await settleWeb(tester);
        expect(topLocation(tester), '/home');

        push.receiveNotice(notice);
        push.openNotice(notice);
        await settleWeb(tester);
        expect(find.text('Turno nuevo'), findsNothing);
        expect(topLocation(tester), '/home');
      });
    }

    testWidgets('un aviso sin día válido no navega', (tester) async {
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: push,
        overrides: emptyAgenda,
      );

      push.openNotice(PushNotice.fromParts(data: {'day': '2026-02-30'}));
      await settleWeb(tester);
      expect(topLocation(tester), '/home');
    });

    testWidgets('"Ver" tiene nombre para el lector de pantalla', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        user: admin,
        pushRepository: push,
        overrides: emptyAgenda,
      );
      push.receiveNotice(notice);
      await settleWeb(tester);

      expect(find.bySemanticsLabel('Ver la agenda de ese día'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('en portugués: "Ver" y su nombre (el aviso viene en '
        'español, RF-7)', (tester) async {
      final semantics = tester.ensureSemantics();
      final push = FakePushRepository();
      await pumpMobileApp(
        tester,
        overrides: emptyAgenda,
        user: admin,
        stored: const {'language': 'pt'},
        pushRepository: push,
      );
      push.receiveNotice(notice);
      await settleWeb(tester);

      expect(find.text('Turno nuevo'), findsOneWidget);
      expect(viewButton, findsOneWidget);
      expect(find.bySemanticsLabel('Ver a agenda desse dia'), findsOneWidget);
      semantics.dispose();
    });
  });
}
