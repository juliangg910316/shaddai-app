import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_users_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Accesibilidad del panel de la admin (spec 010, RNF-1 a RNF-4): la
/// agenda (con su cabecera verde), la lista de clientas y los tres diálogos
/// (cancelar, bloquear y desbloquear). Contraste en los dos temas, áreas
/// táctiles de 48 px con nombre, lector de pantalla, texto al 200 % en
/// 320 px en español y en portugués, y cambio de idioma con un diálogo
/// abierto.
///
/// "Ahora" es el viernes 20/11/2026 a las 7:00 del salón. Ana tiene un turno
/// a las 9:00 por confirmar; Bea, uno confirmado a las 11:00; Carla está
/// bloqueada.
final now = DateTime.utc(2026, 11, 20, 10);

AppointmentModel appointment(
  String id,
  String clientId,
  int hour,
  String status,
) {
  final start = fromSalon(DateTime.utc(2026, 11, 20, hour));
  return AppointmentModel(
    id: id,
    clientId: clientId,
    clientName: 'Clienta ${clientId.toUpperCase()}',
    clientPhone: '+55 41 99999-000$hour',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: start,
    booked: const BookedServiceModel(
      kind: BookedKind.service,
      id: 's1',
      name: BilingualText(es: 'Manicura rusa', pt: 'Manicure russa'),
      priceCents: 3000,
      durationMinutes: 45,
    ),
  );
}

UserModel user(String uid, String name, {bool blocked = false}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: '+55 41 98888-1111',
  isBlocked: blocked,
);

/// Los tres diálogos: cómo se abre cada uno y su título en ES y en PT.
enum AdminDialog {
  cancel(
    '¿Cancelar el turno de Clienta ANA?',
    'Cancelar o horário de Clienta ANA?',
  ),
  block('¿Bloquear a Ana?', 'Bloquear Ana?'),
  unblock('¿Desbloquear a Carla?', 'Desbloquear Carla?');

  const AdminDialog(this.titleEs, this.titlePt);

  final String titleEs;
  final String titlePt;

  Widget get screen =>
      this == cancel ? const AdminDashboardView() : const AdminUsersView();

  Finder get opener => switch (this) {
    cancel => find.descendant(
      of: find.byKey(const ValueKey('agenda-appointment-t1')),
      matching: find.text('CANCELAR'),
    ),
    block => find.descendant(
      of: find.byKey(const ValueKey('client-ana')),
      matching: find.byType(Switch),
    ),
    unblock => find.descendant(
      of: find.byKey(const ValueKey('client-carla')),
      matching: find.byType(Switch),
    ),
  };
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;

  setUp(() {
    final day = [
      appointment('t1', 'ana', 9, 'waiting_confirmation'),
      appointment('t2', 'bea', 11, 'confirmed'),
    ];
    bookings = FakeBookingRepository(active: day)..day = day;
    users = FakeUserRepository(
      users: [
        user('ana', 'Ana'),
        user('bea', 'Bea'),
        user('carla', 'Carla', blocked: true),
      ],
    )..bookings = bookings;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String theme = 'light',
    String language = 'es',
    double width = 412,
    double height = 2400,
    DateTime? shown,
  }) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': language},
      home: screen,
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        userRepositoryProvider.overrideWithValue(users),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => now),
        salonNowProvider.overrideWith((ref) => Stream.value(toSalon(now))),
        isWebProvider.overrideWithValue(false),
        if (shown != null)
          adminSelectedDateProvider.overrideWith((ref) => shown),
      ],
    );
    await settle(tester);
  }

  /// Pasa la agenda al día siguiente, para que aparezca "Hoy". Se toca el
  /// botón en lugar de volver a montar la app: los overrides de una prueba
  /// no se pueden cambiar.
  Future<void> nextDay(WidgetTester tester) async {
    final next = find.byKey(const ValueKey('agenda-next-day'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, AdminDialog which) async {
    await tester.ensureVisible(which.opener);
    await settle(tester);
    await tester.tap(which.opener);
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
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

  final header = find.byKey(const ValueKey('agenda-header'));
  final dialog = find.byType(AlertDialog);
  Finder inDialog(Finder finder) =>
      find.descendant(of: dialog, matching: finder);

  for (final theme in ['light', 'dark']) {
    group('tema $theme (RNF-1, RNF-2)', () {
      testWidgets('la cabecera verde: subtítulo y contadores con contraste '
          'AA, medidos con sus colores exactos', (tester) async {
        await pump(tester, const AdminDashboardView(), theme: theme);
        expect(find.text('PANEL DE BEIDIS'), findsOneWidget);
        expect(find.text('TURNOS DEL DÍA'), findsOneWidget);
        expectTextContrast(
          tester,
          header,
          Theme.of(tester.element(header)).extension<BrandColors>()!.brand,
        );
      });

      testWidgets('la agenda, también con "Hoy"', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminDashboardView(), theme: theme);
        await expectGuidelines(tester);
        await nextDay(tester);
        expect(find.text('HOY'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('la lista de clientas', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminUsersView(), theme: theme);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      for (final which in AdminDialog.values) {
        testWidgets('el diálogo "${which.titleEs}"', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, which.screen, theme: theme);
          await open(tester, which);
          await expectGuidelines(tester);
          expectDialogTextContrast(tester);
          semantics.dispose();
        });
      }
    });
  }

  group('lector de pantalla (RNF-2)', () {
    testWidgets('la fecha y "Hoy" son botones con nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const AdminDashboardView(),
        shown: DateTime.utc(2026, 11, 21),
      );
      expect(find.byTooltip('Elegir fecha'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('agenda-date'))),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('HOY')),
        isSemantics(label: 'HOY', isButton: true, isEnabled: true),
      );
      semantics.dispose();
    });

    testWidgets('las acciones del turno son botones con nombre', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AdminDashboardView());
      for (final label in ['EDITAR', 'CANCELAR', 'CONFIRMAR']) {
        expect(
          tester.getSemantics(find.text(label).first),
          isSemantics(label: label, isButton: true, isEnabled: true),
          reason: label,
        );
      }
      expect(
        find.byTooltip('Escribir a Clienta ANA por WhatsApp'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('cada fila de clienta es una frase; su interruptor tiene '
        'nombre y estado', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AdminUsersView());
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('client-text-carla')))
            .label,
        'Carla, +55 41 98888-1111, BLOQUEADA',
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(const ValueKey('client-carla')),
            matching: find.byType(Switch),
          ),
        ),
        isSemantics(
          label: 'Bloquear a Carla',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
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

      testWidgets('la agenda, con "Hoy", sin desbordes', (tester) async {
        await pump(
          tester,
          const AdminDashboardView(),
          language: language,
          width: 320,
          height: 6000,
        );
        expect(tester.takeException(), isNull);
        await nextDay(tester);
        expect(find.byKey(const ValueKey('agenda-today')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la lista de clientas, sin desbordes', (tester) async {
        await pump(
          tester,
          const AdminUsersView(),
          language: language,
          width: 320,
          height: 6000,
        );
        expect(tester.takeException(), isNull);
      });

      for (final which in AdminDialog.values) {
        testWidgets('el diálogo "${which.titleEs}", sin desbordes', (
          tester,
        ) async {
          await pump(
            tester,
            which.screen,
            language: language,
            width: 320,
            height: 6000,
          );
          await open(tester, which);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  group('al cambiar de idioma con un diálogo abierto, cambia (RC-1)', () {
    for (final which in AdminDialog.values) {
      testWidgets(which.titleEs, (tester) async {
        await pump(tester, which.screen);
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
  });
}
