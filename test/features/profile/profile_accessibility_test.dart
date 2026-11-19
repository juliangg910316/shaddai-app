import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/profile/providers/account_deletion_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Accesibilidad del perfil y de sus tres diálogos (spec 009, RNF-1 a
/// RNF-4, RC-1): contraste y áreas táctiles en claro y oscuro, texto al
/// 200 % en 320 px y cambio de idioma con un diálogo abierto.
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón. Su turno activo es
/// hoy a las 9:00; en el historial, uno cancelado por ella, uno por el
/// salón y uno realizado.
DateTime at(int day, int hour) => DateTime.utc(2026, 11, day, hour);

const booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 45,
);

AppointmentModel appointment(
  String id,
  DateTime salonStart, {
  String status = 'confirmed',
  bool byClient = false,
}) {
  final start = fromSalon(salonStart);
  return AppointmentModel(
    id: id,
    clientId: testClient.uid,
    clientName: testClient.displayName,
    clientPhone: testClient.phoneNumber!,
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: bookingTestNow,
    booked: booked,
    cancelledByClient: byClient,
  );
}

final dialog = find.byType(AlertDialog);
Finder inDialog(Finder finder) => find.descendant(of: dialog, matching: finder);

/// Los tres diálogos del perfil: cómo se abre cada uno y su título en
/// español y en portugués.
enum ProfileDialog {
  cancel('CANCELAR TURNO', '¿Cancelar tu turno?', 'Cancelar seu horário?'),
  whatsApp(null, 'Cambiar WhatsApp', 'Alterar WhatsApp'),
  delete(null, 'Eliminar mi cuenta', 'Excluir minha conta');

  const ProfileDialog(this.text, this.titleEs, this.titlePt);

  final String? text;
  final String titleEs;
  final String titlePt;

  Finder get opener => switch (this) {
    cancel => find.text(text!),
    whatsApp => find.byKey(const ValueKey('profile-whatsapp-change')),
    delete => find.byKey(const ValueKey('profile-delete-account')),
  };
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;

  setUp(() {
    bookings = FakeBookingRepository(
      mine: [
        appointment('activo', at(10, 9)),
        appointment('tuyo', at(3, 9), status: 'cancelled', byClient: true),
        appointment('salon', at(2, 9), status: 'cancelled'),
        appointment('hecho', at(1, 9)),
      ],
    );
    users = FakeUserRepository(stored: testClient);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester, {
    String theme = 'light',
    String language = 'es',
    double width = 412,
    double height = 4000,
  }) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': language},
      home: const ProfileView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          userStream: () => users.watchUser(testClient.uid),
        ),
        userRepositoryProvider.overrideWithValue(users),
        accountRepositoryProvider.overrideWithValue(FakeAccountRepository()),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  Future<void> open(
    WidgetTester tester,
    ProfileDialog which, {
    String language = 'es',
  }) async {
    final opener = language == 'pt' && which == ProfileDialog.cancel
        ? find.text('CANCELAR HORÁRIO')
        : which.opener;
    await tester.ensureVisible(opener);
    await settle(tester);
    await tester.tap(opener);
    await settle(tester);
    expect(dialog, findsOneWidget);
  }

  /// El segundo paso de "Eliminar mi cuenta".
  Future<void> toDeleteStep2(WidgetTester tester) async {
    await tester.tap(inDialog(find.byType(ElevatedButton)));
    await settle(tester);
    expect(inDialog(find.byType(TextField)), findsOneWidget);
  }

  Future<void> expectGuidelines(WidgetTester tester) async {
    for (final guideline in [
      textContrastGuideline,
      androidTapTargetGuideline,
      labeledTapTargetGuideline,
    ]) {
      await expectLater(tester, meetsGuideline(guideline));
    }
  }

  for (final theme in ['light', 'dark']) {
    group('tema $theme (RNF-1, RNF-2)', () {
      testWidgets('el perfil: turno activo, historial y "Tu cuenta"', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        expect(find.text('CANCELADO POR TI'), findsOneWidget);
        expect(find.text('CANCELADO POR EL SALÓN'), findsOneWidget);
        expect(find.text('REALIZADO'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      for (final which in ProfileDialog.values) {
        testWidgets('el diálogo "${which.titleEs}"', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, theme: theme);
          await open(tester, which);
          await expectGuidelines(tester);
          expectDialogTextContrast(tester);
          if (which == ProfileDialog.delete) {
            await toDeleteStep2(tester);
            await tester.enterText(
              inDialog(find.byType(TextField)),
              'ELIMINAR',
            );
            await settle(tester);
            await expectGuidelines(tester);
            expectDialogTextContrast(tester);
          }
          semantics.dispose();
        });
      }
    });
  }

  group('semántica (RNF-2)', () {
    testWidgets('las acciones son botones con nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      for (final label in ['CANCELAR TURNO', 'CAMBIAR', 'ELIMINAR MI CUENTA']) {
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(label: label, isButton: true, isEnabled: true),
          reason: label,
        );
      }
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('cada tarjeta del historial se lee como una frase', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      final node = tester.getSemantics(
        find.byKey(const ValueKey('history-tuyo')),
      );
      expect(node.label, contains('Manicura'));
      expect(node.label, contains('9:00'));
      expect(node.label, contains('CANCELADO POR TI'));
      semantics.dispose();
    });
  });

  for (final language in ['es', 'pt']) {
    group('texto al 200 % y 320 px, en $language (RNF-3)', () {
      setUp(() {
        TestWidgetsFlutterBinding
                .instance
                .platformDispatcher
                .textScaleFactorTestValue =
            2;
      });
      tearDown(
        TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .clearTextScaleFactorTestValue,
      );

      testWidgets('el perfil, sin desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        expect(find.byType(ProfileView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      for (final which in ProfileDialog.values) {
        testWidgets('el diálogo "${which.titleEs}", sin desbordes', (
          tester,
        ) async {
          await pump(tester, language: language, width: 320, height: 9000);
          await open(tester, which, language: language);
          expect(tester.takeException(), isNull);
          if (which == ProfileDialog.delete) {
            await toDeleteStep2(tester);
            expect(tester.takeException(), isNull);
          }
        });
      }
    });
  }

  group('al cambiar de idioma con un diálogo abierto, cambia (RC-1)', () {
    for (final which in ProfileDialog.values) {
      testWidgets(which.titleEs, (tester) async {
        await pump(tester);
        await open(tester, which);
        expect(inDialog(find.text(which.titleEs)), findsOneWidget);

        await appContainer(tester)
            .read(languagePreferenceProvider.notifier)
            .select(AppLanguage.pt);
        await settle(tester);

        expect(inDialog(find.text(which.titlePt)), findsOneWidget);
        expect(inDialog(find.text(which.titleEs)), findsNothing);
      });
    }

    testWidgets('el segundo paso de "Eliminar mi cuenta" pide la palabra '
        'del idioma nuevo', (tester) async {
      await pump(tester);
      await open(tester, ProfileDialog.delete);
      await toDeleteStep2(tester);
      expect(
        inDialog(find.text('Escribe ELIMINAR para confirmar')),
        findsOneWidget,
      );

      await appContainer(tester)
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await settle(tester);

      expect(inDialog(find.textContaining('EXCLUIR')), findsWidgets);
    });
  });
}
