import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_push.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La puerta de los avisos push en la app y la explicación del permiso
/// (spec 011, RF-15, RF-16; plan D-8, § 6; T6).
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
}
