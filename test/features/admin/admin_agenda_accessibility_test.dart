import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_closure_form_view.dart';
import 'package:shaddai/features/admin/presentation/admin_closures_view.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_settings_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Accesibilidad de la agenda de la admin (spec 008, RNF-2): los cierres,
/// su formulario con los choques, la agenda con cierres y "Editar", la
/// edición de un turno con su diálogo, y el margen. Contraste en los dos
/// temas, objetivos de 48 px, lector de pantalla, y texto al 200 % en
/// 320 px, en español y en portugués.
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
);

const spa = BookedServiceModel(
  kind: BookedKind.service,
  id: 'spa',
  name: BilingualText(es: 'Spa de manos', pt: 'Spa das mãos'),
  priceCents: 5500,
  durationMinutes: 45,
);

/// El turno de Ana: el viernes 20, de 10:00 a 10:45.
AppointmentModel anaAppointment() => AppointmentModel(
  id: 't1',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(at(20, 10)),
  endTime: fromSalon(at(20, 10, 45)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: spa,
);

/// Un turno de hoy, de 9:30 a 10:15: choca con el cierre por defecto del
/// formulario (hoy de 9:00 a 10:00).
AppointmentModel todayAppointment() => AppointmentModel(
  id: 'hoy',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(at(10, 9, 30)),
  endTime: fromSalon(at(10, 10, 15)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: spa,
);

/// Un cierre de unas horas (el viernes 20 de 14:00 a 16:00) y uno de días
/// enteros (del 24 al 26).
List<ClosureModel> closures() => [
  ClosureModel(
    id: 'franja',
    start: fromSalon(at(20, 14)),
    end: fromSalon(at(20, 16)),
  ),
  ClosureModel(
    id: 'dias',
    start: fromSalon(DateTime.utc(2026, 11, 24)),
    end: fromSalon(DateTime.utc(2026, 11, 27)),
  ),
];

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeConfigRepository config;
  late FakeBookingRepository bookings;

  setUp(() {
    config = FakeConfigRepository(
      settings: CalendarSettingsModel(
        openingHours: CalendarSettingsModel.defaultSettings().openingHours,
        globalSlotDurationMinutes: 30,
        blockedDates: const [],
        editMarginMinutes: 1440,
      ),
      closures: closures(),
    );
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

  List<Override> overrides() => [
    configRepositoryProvider.overrideWithValue(config),
    bookingRepositoryProvider.overrideWithValue(bookings),
    userRepositoryProvider.overrideWithValue(
      FakeUserRepository(users: [ana, testAdmin]),
    ),
    clockProvider.overrideWithValue(() => bookingTestNow),
    salonNowProvider.overrideWith(
      (ref) => Stream.value(toSalon(bookingTestNow)),
    ),
    isWebProvider.overrideWithValue(false),
    adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
    adminAppointmentsProvider.overrideWith(
      (ref) => Stream.value([anaAppointment()]),
    ),
  ];

  /// [screen] sola, con el tema y el idioma dados.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String theme = 'light',
    String language = 'es',
    double width = 800,
    double height = 2400,
  }) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': language},
      home: screen,
      overrides: overrides(),
    );
    await settle(tester);
  }

  /// El formulario de cierre con los turnos que chocan (por defecto, hoy de
  /// 9:00 a 10:00).
  Future<void> pumpConflicts(
    WidgetTester tester, {
    String theme = 'light',
    String language = 'es',
    double width = 800,
    double height = 2400,
  }) async {
    bookings.active = [todayAppointment()];
    await pump(
      tester,
      const AdminClosureFormView(),
      theme: theme,
      language: language,
      width: width,
      height: height,
    );
    final save = find.text(language == 'pt' ? 'SALVAR' : 'GUARDAR');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(find.byKey(const ValueKey('closure-conflict-hoy')), findsOneWidget);
  }

  /// La edición del turno de Ana, en la app real (Android/iOS).
  Future<void> pumpEdit(
    WidgetTester tester, {
    String theme = 'light',
    String language = 'es',
    double width = 800,
    double height = 2400,
  }) async {
    await pumpMobileApp(
      tester,
      location: '/admin/appointments/t1/edit',
      user: testAdmin,
      userRepository: FakeUserRepository(users: [ana, testAdmin]),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      stored: {'theme': theme, 'language': language},
      width: width,
      height: height,
      overrides: [
        ...bookingScheduleOverrides(bookings: bookings, config: config),
        adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
        adminAppointmentsProvider.overrideWith(
          (ref) => Stream.value([anaAppointment()]),
        ),
      ],
    );
    await settle(tester);
  }

  /// En la edición, elige las 11:00 y abre el diálogo de cambios.
  Future<void> openEditDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('11:00'));
    await tester.tap(find.text('11:00'));
    await settle(tester);
    final save = find.textContaining(RegExp('^(GUARDAR|SALVAR) ALTERA'));
    final button = save.evaluate().isEmpty
        ? find.text('GUARDAR CAMBIOS')
        : save;
    await tester.ensureVisible(button);
    await tester.tap(button);
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

  Future<void> expectTapTargets(WidgetTester tester) async {
    for (final guideline in [
      androidTapTargetGuideline,
      labeledTapTargetGuideline,
    ]) {
      await expectLater(tester, meetsGuideline(guideline));
    }
  }

  for (final theme in ['light', 'dark']) {
    group('tema $theme (RNF-2)', () {
      testWidgets('la lista de cierres', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminClosuresView(), theme: theme);
        expect(find.byKey(const ValueKey('closure-franja')), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('el formulario con sus errores', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminClosureFormView(), theme: theme);
        final to = find.byKey(const ValueKey('closure-field-to'));
        await tester.tap(find.descendant(of: to, matching: find.text('10:00')));
        await settle(tester);
        await tester.tap(find.text('9:00').last);
        await settle(tester);
        await tester.ensureVisible(find.text('GUARDAR'));
        await tester.tap(find.text('GUARDAR'));
        await settle(tester);
        expect(
          find.text('La hora de fin debe ser posterior a la de inicio.'),
          findsOneWidget,
        );
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('el formulario con los turnos que chocan', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpConflicts(tester, theme: theme);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('la agenda con un cierre y "Editar"', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminDashboardView(), theme: theme);
        final closureCard = find.byKey(const ValueKey('agenda-closure-franja'));
        final appointmentCard = find.byKey(
          const ValueKey('agenda-appointment-t1'),
        );
        expect(closureCard, findsOneWidget);
        expect(appointmentCard, findsOneWidget);
        // La cabecera verde del panel no es de esta spec: se miden las
        // tarjetas, sobre su fondo, con sus colores exactos.
        for (final card in [closureCard, appointmentCard]) {
          final flat = find.descendant(
            of: card,
            matching: find.byType(FlatCard),
            matchRoot: true,
          );
          expectTextContrast(
            tester,
            card,
            tester.widget<FlatCard>(flat.first).color ??
                Theme.of(tester.element(card))
                    .extension<BrandColors>()!
                    .surface,
            skip: [find.byType(InitialsAvatar)],
          );
        }
        final edit = find.descendant(
          of: appointmentCard,
          matching: find.text('EDITAR'),
        );
        final size = tester.getSize(
          find
              .ancestor(
                of: edit,
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first,
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await expectTapTargets(tester);
        semantics.dispose();
      });

      testWidgets('la edición de un turno', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpEdit(tester, theme: theme);
        expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('el diálogo de cambios de la admin', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpEdit(tester, theme: theme);
        await openEditDialog(tester);
        expect(find.text('El turno quedará confirmado.'), findsOneWidget);
        await expectGuidelines(tester);
        expectDialogTextContrast(tester);
        semantics.dispose();
      });

      testWidgets('el margen en los ajustes', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const AdminSettingsView(), theme: theme);
        expect(find.text('Margen de edición'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });
    });
  }

  group('lector de pantalla (RNF-2)', () {
    testWidgets('"Quitar" dice qué cierre quita', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AdminClosuresView());
      final remove = find.descendant(
        of: find.byKey(const ValueKey('closure-franja')),
        matching: find.byType(IconButton),
      );
      expect(
        tester.getSemantics(remove),
        isSemantics(
          tooltip:
              'Quitar el cierre: Viernes, 20 de noviembre de 2026, '
              '14:00 – 16:00',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('el desplegable del margen se llama "Margen de edición"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AdminSettingsView());
      expect(find.bySemanticsLabel(RegExp('Margen de edición')), findsWidgets);
      final field = find.byKey(const ValueKey('edit-margin'));
      expect(
        tester.getSemantics(field).getSemanticsData().label,
        contains('Margen de edición'),
      );
      semantics.dispose();
    });

    testWidgets('"Margen guardado" y "No cambiaste nada" se anuncian', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const AdminSettingsView());
      tester.takeAnnouncements();
      final field = find.byKey(const ValueKey('edit-margin'));
      await tester.tap(field);
      await settle(tester);
      await tester.tap(find.text('2 horas').last);
      await settle(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Margen guardado.'),
      );
      semantics.dispose();
    });

    testWidgets('"No cambiaste nada" se anuncia', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEdit(tester);
      tester.takeAnnouncements();
      await tester.ensureVisible(find.text('GUARDAR CAMBIOS'));
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await settle(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('No cambiaste nada.'),
      );
      semantics.dispose();
    });
  });

  for (final language in ['es', 'pt']) {
    group('texto al 200 % y 320 px, en $language (RNF-2)', () {
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

      testWidgets('la lista de cierres, sin desbordes', (tester) async {
        await pump(
          tester,
          const AdminClosuresView(),
          language: language,
          width: 320,
          height: 4000,
        );
        expect(find.byType(FlatCard), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el formulario con los choques, sin desbordes', (
        tester,
      ) async {
        await pumpConflicts(
          tester,
          language: language,
          width: 320,
          height: 6000,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('la agenda con un cierre y "Editar", sin desbordes', (
        tester,
      ) async {
        await pump(
          tester,
          const AdminDashboardView(),
          language: language,
          width: 320,
          height: 6000,
        );
        expect(
          find.byKey(const ValueKey('agenda-closure-franja')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('la edición y su diálogo, sin desbordes', (tester) async {
        await pumpEdit(tester, language: language, width: 320, height: 9000);
        expect(tester.takeException(), isNull);
        await openEditDialog(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el margen, sin desbordes', (tester) async {
        await pump(
          tester,
          const AdminSettingsView(),
          language: language,
          width: 320,
          height: 6000,
        );
        expect(find.byKey(const ValueKey('edit-margin')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
