import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/account_button.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

Finder _inBar(Finder finder) =>
    find.descendant(of: find.byType(WebTopBar), matching: finder);

/// Abre el menú de cuenta.
Future<void> _openMenu(
  WidgetTester tester, {
  String label = 'Menú de cuenta',
}) async {
  await tester.tap(find.byTooltip(label));
  await settleWeb(tester);
}

Finder _menuItem(String text) => find.widgetWithText(MenuItemButton, text);

/// El panel de admin lee sus turnos de Firestore: aquí, ninguno.
final _adminOverrides = [
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
];

void main() {
  group('sin sesión', () {
    for (final width in [360.0, 1280.0]) {
      testWidgets('muestra "Entrar" en la barra (${width.toInt()} px)', (
        tester,
      ) async {
        await pumpWebApp(tester, width: width);

        expect(_inBar(find.byType(AccountButton)), findsOneWidget);
        expect(_inBar(find.text('Entrar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Entrar" lleva al login y, tras la sesión, a la landing '
        '(RF-24)', (tester) async {
      final session = await pumpWebApp(tester);

      await tester.tap(_inBar(find.text('Entrar')));
      await settleWeb(tester);
      expect(webLocation(tester).path, '/login');

      session.signIn(testClient);
      await settleWeb(tester);

      expect(webLocation(tester).toString(), '/');
      expect(find.byType(LandingPage), findsOneWidget);
      expect(_inBar(find.text('Entrar')), findsNothing);
    });
  });

  group('con sesión (RF-25)', () {
    testWidgets('sin foto, muestra la inicial del nombre', (tester) async {
      await pumpWebApp(tester, user: testClient);

      expect(_inBar(find.text('A')), findsOneWidget);
      expect(_inBar(find.text('Entrar')), findsNothing);
    });

    testWidgets('con foto, la muestra', (tester) async {
      const photo = 'https://example.com/ana.jpg';
      await pumpWebApp(tester, user: testClient.copyWith(photoUrl: photo));

      final image = _inBar(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url == photo,
        ),
      );
      expect(image, findsOneWidget);
    });

    testWidgets('si la foto no carga, muestra la inicial', (tester) async {
      await pumpWebApp(
        tester,
        user: testClient.copyWith(photoUrl: 'https://example.com/rota.jpg'),
      );
      // En los tests, toda petición de red falla.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settleWeb(tester);

      expect(_inBar(find.text('A')), findsOneWidget);
    });
  });

  group('menú de clienta', () {
    testWidgets('tiene "Mis turnos" y "Cerrar sesión", sin panel (RF-27)', (
      tester,
    ) async {
      await pumpWebApp(tester, user: testClient);
      await _openMenu(tester);

      expect(_menuItem('Mis turnos'), findsOneWidget);
      expect(_menuItem('Cerrar sesión'), findsOneWidget);
      expect(_menuItem('Panel de administración'), findsNothing);
    });

    testWidgets('"Mis turnos" lleva al perfil (RF-26)', (tester) async {
      await pumpWebApp(tester, user: testClient);
      await _openMenu(tester);

      await tester.tap(_menuItem('Mis turnos'));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/profile');
      expect(find.byType(ProfileView), findsOneWidget);
    });

    testWidgets('"Cerrar sesión" cierra la sesión y lleva a la landing '
        '(RF-28)', (tester) async {
      await pumpWebApp(tester, location: '/profile', user: testClient);
      await _openMenu(tester);

      await tester.tap(_menuItem('Cerrar sesión'));
      await settleWeb(tester);

      expect(webLocation(tester).toString(), '/');
      expect(find.byType(LandingPage), findsOneWidget);
      expect(_inBar(find.text('Entrar')), findsOneWidget);
    });

    testWidgets('una clienta que abre el panel va a la landing', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/admin', user: testClient);

      expect(webLocation(tester).toString(), '/');
      expect(find.byType(AdminDashboardView), findsNothing);
    });
  });

  group('menú de admin', () {
    testWidgets('además, "Panel de administración" lleva al panel (RF-27)', (
      tester,
    ) async {
      await pumpWebApp(tester, user: testAdmin, overrides: _adminOverrides);
      await _openMenu(tester);

      expect(_menuItem('Mis turnos'), findsOneWidget);
      expect(_menuItem('Cerrar sesión'), findsOneWidget);
      await tester.tap(_menuItem('Panel de administración'));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/admin');
      expect(find.byType(AdminDashboardView), findsOneWidget);
    });
  });

  testWidgets('en portugués', (tester) async {
    await pumpWebApp(tester, user: testAdmin, stored: {'language': 'pt'});
    await _openMenu(tester, label: 'Menu da conta');

    for (final text in ['Meus horários', 'Painel de administração', 'Sair']) {
      expect(_menuItem(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('sin sesión, en portugués, muestra "Entrar"', (tester) async {
    await pumpWebApp(tester, stored: {'language': 'pt'});

    expect(_inBar(find.text('Entrar')), findsOneWidget);
  });

  testWidgets('el botón mide al menos 48 px y tiene etiqueta (RNF-2)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpWebApp(tester, user: testClient);

    final size = tester.getSize(find.byType(AccountButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
