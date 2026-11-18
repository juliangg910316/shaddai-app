import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/account_repository.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/profile/providers/account_deletion_provider.dart';
import 'package:shaddai/features/services/presentation/price_list_notices.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

/// "Eliminar mi cuenta" en el perfil (spec 009, RF-31 a RF-33, RF-36,
/// RF-38 a RF-40, RNF-4, RNF-5).
final deleteButton = find.byKey(const ValueKey('profile-delete-account'));
final dialog = find.byType(AlertDialog);
Finder inDialog(Finder finder) => find.descendant(of: dialog, matching: finder);
final wordField = inDialog(find.byType(TextField));
final confirmButton = inDialog(find.text('ELIMINAR MI CUENTA'));

void main() {
  late FakeAccountRepository accounts;
  late FakeBookingRepository bookings;
  late RecordingLinkLauncher links;

  setUp(() {
    accounts = FakeAccountRepository();
    bookings = FakeBookingRepository(mine: []);
    links = RecordingLinkLauncher();
  });

  Future<FakeWebSession> mobile(
    WidgetTester tester, {
    UserModel? user,
    String language = 'es',
  }) => pumpMobileApp(
    tester,
    location: '/profile',
    user: user ?? testClient,
    appointments: null,
    stored: {'language': language},
    overrides: [
      ...bookingScheduleOverrides(bookings: bookings),
      accountRepositoryProvider.overrideWithValue(accounts),
      links.override,
    ],
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Abre el diálogo y pasa al segundo paso.
  Future<void> toStep2(WidgetTester tester, {String next = 'CONTINUAR'}) async {
    await tap(tester, deleteButton);
    await tester.tap(inDialog(find.text(next)));
    await tester.pumpAndSettle();
  }

  bool confirmEnabled(WidgetTester tester) =>
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: confirmButton,
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .onPressed !=
      null;

  group('quién lo ve (RF-31, RF-40)', () {
    testWidgets('la clienta ve "Eliminar mi cuenta"', (tester) async {
      await mobile(tester);
      expect(deleteButton, findsOneWidget);
      expect(find.text('ELIMINAR MI CUENTA'), findsOneWidget);
    });

    testWidgets('la admin no', (tester) async {
      await mobile(tester, user: testAdmin);
      expect(deleteButton, findsNothing);
      expect(find.text('ELIMINAR MI CUENTA'), findsNothing);
    });

    testWidgets('bloqueada: el aviso de hablar con el salón con WhatsApp, '
        'sin el botón', (tester) async {
      await mobile(tester, user: testClient.copyWith(isBlocked: true));
      expect(deleteButton, findsNothing);
      final notice = find.text('Para eliminar tu cuenta, habla con el salón.');
      await tester.ensureVisible(notice);
      expect(notice, findsOneWidget);
      await tap(tester, find.byType(WhatsappNoticeButton));
      expect(links.opened, hasLength(1));
      expect(links.opened.single.host, 'wa.me');
    });
  });

  group('dos confirmaciones (RF-32, RF-33, RNF-5)', () {
    testWidgets('el paso 1 explica qué se borra y qué se conserva', (
      tester,
    ) async {
      await mobile(tester);
      await tap(tester, deleteButton);
      expect(inDialog(find.text('Eliminar mi cuenta')), findsOneWidget);
      expect(
        inDialog(find.textContaining('Se cancelará tu turno activo')),
        findsOneWidget,
      );
      expect(
        inDialog(find.textContaining('El salón conservará tus turnos')),
        findsOneWidget,
      );
      expect(inDialog(find.text('CONTINUAR')), findsOneWidget);
    });

    testWidgets('"Cancelar" en el paso 1 no llama a nada', (tester) async {
      await mobile(tester);
      await tap(tester, deleteButton);
      await tester.tap(inDialog(find.text('CANCELAR')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(accounts.calls, 0);
    });

    testWidgets('"Cancelar" en el paso 2 no llama a nada', (tester) async {
      await mobile(tester);
      await toStep2(tester);
      await tester.enterText(wordField, 'ELIMINAR');
      await tester.pump();
      await tester.tap(inDialog(find.text('CANCELAR')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(accounts.calls, 0);
    });

    testWidgets('el paso 2 pide escribir ELIMINAR; solo entonces se activa '
        'el botón', (tester) async {
      await mobile(tester);
      await toStep2(tester);
      expect(
        inDialog(find.text('Escribe ELIMINAR para confirmar')),
        findsOneWidget,
      );
      expect(confirmEnabled(tester), isFalse);
      await tester.enterText(wordField, 'EXCLUIR');
      await tester.pump();
      expect(confirmEnabled(tester), isFalse);
      await tester.enterText(wordField, ' eliminar ');
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('en portugués, la palabra es EXCLUIR', (tester) async {
      await mobile(tester, language: 'pt');
      final ptButton = find.text('EXCLUIR MINHA CONTA');
      await tap(tester, deleteButton);
      await tester.tap(inDialog(find.text('CONTINUAR')));
      await tester.pumpAndSettle();
      expect(
        inDialog(find.text('Digite EXCLUIR para confirmar')),
        findsOneWidget,
      );
      await tester.enterText(wordField, 'ELIMINAR');
      await tester.pump();
      ButtonStyleButton button() => tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: inDialog(ptButton),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button().onPressed, isNull);
      await tester.enterText(wordField, 'excluir');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });
  });

  testWidgets('mientras borra: indicador, botones desactivados y sin doble '
      'envío (RF-38)', (tester) async {
    final gate = Completer<void>();
    accounts.gate = gate.future;
    await mobile(tester);
    await toStep2(tester);
    await tester.enterText(wordField, 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pump();

    expect(inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    for (final button in tester.widgetList<ButtonStyleButton>(
      inDialog(find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(confirmButton, warnIfMissed: false);
    await tester.pump();
    expect(accounts.calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(accounts.calls, 1);
  });

  testWidgets('si va bien en Android/iOS: cierra la sesión, avisa y va a '
      'Inicio (RF-36, RNF-4)', (tester) async {
    final session = await mobile(tester);
    await toStep2(tester);
    await tester.enterText(wordField, 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(accounts.calls, 1);
    expect(session.user, isNull);
    expect(dialog, findsNothing);
    expect(webLocation(tester).path, '/home');
    expect(find.text('Tu cuenta se eliminó.'), findsOneWidget);
  });

  testWidgets('si va bien en Web: cierra la sesión, avisa y va a la landing '
      '(RF-36)', (tester) async {
    final session = await pumpWebApp(
      tester,
      location: '/profile',
      user: testClient,
      appointments: [],
      overrides: [accountRepositoryProvider.overrideWithValue(accounts)],
    );
    await toStep2(tester);
    await tester.enterText(wordField, 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton);
    await settleWeb(tester);

    expect(session.user, isNull);
    expect(webLocation(tester).toString(), '/');
    expect(find.byType(LandingPage), findsOneWidget);
    expect(find.byType(ProfileView), findsNothing);
    expect(find.text('Tu cuenta se eliminó.'), findsOneWidget);
  });

  testWidgets('si falla: el texto y "Reintentar" en el mismo diálogo, sin '
      'cerrar la sesión (RF-39)', (tester) async {
    accounts.failure = AccountDeletionFailure.failed;
    final session = await mobile(tester);
    await toStep2(tester);
    await tester.enterText(wordField, 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(dialog, findsOneWidget);
    expect(
      inDialog(find.text('No se pudo eliminar la cuenta. Inténtalo de nuevo.')),
      findsOneWidget,
    );
    expect(session.user, isNotNull);

    accounts.failure = null;
    await tester.tap(inDialog(find.text('REINTENTAR')));
    await tester.pumpAndSettle();
    expect(accounts.calls, 2);
    expect(session.user, isNull);
    expect(dialog, findsNothing);
  });

  testWidgets('si la bloquearon mientras tanto: su texto, sin reintentar '
      '(RF-40)', (tester) async {
    accounts.failure = AccountDeletionFailure.blocked;
    final session = await mobile(tester);
    await toStep2(tester);
    await tester.enterText(wordField, 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(
      inDialog(find.text('Para eliminar tu cuenta, habla con el salón.')),
      findsOneWidget,
    );
    expect(inDialog(find.text('REINTENTAR')), findsNothing);
    expect(session.user, isNotNull);
  });
}
