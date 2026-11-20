import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_users_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_link_launcher.dart';

/// La lista de clientas del panel (spec 010, T8).
UserModel user(
  String uid,
  String name, {
  String? phone = '+55 41 99999-0000',
  String role = 'cliente',
  bool blocked = false,
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: phone,
  role: role,
  isBlocked: blocked,
);

void main() {
  late FakeUserRepository users;
  late RecordingLinkLauncher links;

  setUp(() {
    users = FakeUserRepository(
      users: [
        user('admin', 'Beidis', role: 'admin'),
        user('c', 'Carla', phone: '+55 41 98888-1111'),
        user('a', 'Álvarez', blocked: true),
        user('b', 'ana', phone: null),
      ],
    );
    links = RecordingLinkLauncher();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, {String language = 'es'}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminUsersView(),
      overrides: [
        userRepositoryProvider.overrideWithValue(users),
        links.override,
      ],
    );
    await settle(tester);
  }

  Finder row(String uid) => find.byKey(ValueKey('client-$uid'));
  Finder inRow(String uid, Finder finder) =>
      find.descendant(of: row(uid), matching: finder);

  testWidgets('solo clientas, por nombre sin mayúsculas ni acentos '
      '(RF-19, RF-20)', (tester) async {
    await pump(tester);
    expect(find.text('Beidis'), findsNothing);
    final tops = [
      for (final name in ['Álvarez', 'ana', 'Carla'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('cada fila: avatar, nombre, WhatsApp o correo y estado '
      '(RF-21)', (tester) async {
    await pump(tester);
    expect(inRow('c', find.byType(InitialsAvatar)), findsOneWidget);
    expect(inRow('c', find.text('Carla')), findsOneWidget);
    expect(inRow('c', find.text('+55 41 98888-1111')), findsOneWidget);
    expect(inRow('c', find.text('ACTIVA')), findsOneWidget);
    expect(inRow('a', find.text('BLOQUEADA')), findsOneWidget);
    // Sin WhatsApp (ficha antigua): su correo.
    expect(inRow('b', find.text('b@example.com')), findsOneWidget);
  });

  group('WhatsApp (RF-22)', () {
    testWidgets('solo con número, y abre su conversación', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Escribir a ana por WhatsApp'), findsNothing);
      final carla = find.byTooltip('Escribir a Carla por WhatsApp');
      expect(carla, findsOneWidget);
      await tester.tap(carla);
      await settle(tester);
      expect(links.opened, [Uri.parse('https://wa.me/5541988881111')]);
    });

    testWidgets('es un botón de al menos 48 px', (tester) async {
      await pump(tester);
      final size = tester.getSize(
        find.byTooltip('Escribir a Carla por WhatsApp'),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('la lista cambia en vivo: registro, bloqueo y borrado '
      '(RF-23)', (tester) async {
    await pump(tester);
    users.emitUsers([
      user('c', 'Carla', blocked: true),
      user('a', 'Álvarez', blocked: true),
      user('d', 'Dora'),
    ]);
    await settle(tester);
    expect(inRow('c', find.text('BLOQUEADA')), findsOneWidget);
    expect(find.text('Dora'), findsOneWidget);
    expect(find.text('ana'), findsNothing);
  });

  testWidgets('si no carga, lo dice y "Reintentar" vuelve a cargar '
      '(RF-24)', (tester) async {
    await pump(tester);
    users.failUsers(StateError('permission-denied'));
    await settle(tester);
    expect(
      find.text('No pudimos cargar los clientes. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission'), findsNothing);

    await tester.tap(find.text('REINTENTAR'));
    await settle(tester);
    expect(find.text('Carla'), findsOneWidget);
  });

  testWidgets('la fila se lee como una frase (RNF-2)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('client-text-c')),
    );
    expect(node.label, contains('Carla'));
    expect(node.label, contains('+55 41 98888-1111'));
    expect(node.label, contains('ACTIVA'));
    semantics.dispose();
  });

  group('el interruptor de bloqueo (RF-25, RF-29, plan D-7)', () {
    testWidgets('tiene nombre y anuncia su estado', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(
        tester.getSemantics(inRow('a', find.byType(Switch))),
        isSemantics(
          label: 'Bloquear a Álvarez',
          hasToggledState: true,
          isToggled: true,
          isEnabled: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('al tocarlo no cambia: abre el diálogo', (tester) async {
      await pump(tester);
      await tester.tap(inRow('c', find.byType(Switch)));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<Switch>(inRow('c', find.byType(Switch))).value,
        isFalse,
      );
      expect(users.blocks, isEmpty);
      expect(users.unblocks, isEmpty);
    });
  });

  testWidgets('en portugués', (tester) async {
    await pump(tester, language: 'pt');
    expect(find.text('ATIVA'), findsWidgets);
    expect(find.byTooltip('Escrever para Carla pelo WhatsApp'), findsOneWidget);
  });
}
