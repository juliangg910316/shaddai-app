import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/booking_steps.dart';
import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/fake_config.dart';

/// Accesibilidad de la reserva de la admin (spec 007, RNF-2): contraste en
/// los dos temas, objetivos de 48 px, lector de pantalla, y texto al 200 %
/// en 320 px. "Ahora" es el martes 10/11/2026 a las 7:00 del salón.
final admin = UserModel(
  uid: 'admin1',
  email: 'beidis@example.com',
  displayName: 'Beidis Viera',
  phoneNumber: '+55 41 98000-0000',
  role: 'admin',
);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
  role: 'cliente',
);

final joana = UserModel(
  uid: 'joana',
  email: 'joana@example.com',
  displayName: 'Joana Conceição',
  phoneNumber: '41 99222-0000',
  role: 'cliente',
);

/// Turno activo de Ana: el viernes 20 de 9:00 a 10:30.
AppointmentModel anaActive() => AppointmentModel(
  id: 'de-ana',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(DateTime.utc(2026, 11, 20, 9)),
  endTime: fromSalon(DateTime.utc(2026, 11, 20, 10, 30)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 'gel-short',
    name: BilingualText(es: 'Corto', pt: 'Curto'),
    priceCents: 15000,
    durationMinutes: 120,
  ),
);

/// Un turno de una persona sin cuenta que agendó la admin.
final guestAppointment = AppointmentModel(
  id: 'sin-cuenta',
  clientId: null,
  clientName: 'Rosa Lima',
  clientPhone: '(41) 99333-0000',
  startTime: DateTime.utc(2026, 11, 20, 12),
  endTime: DateTime.utc(2026, 11, 20, 13),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 10),
  createdByAdmin: true,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Deja terminar las animaciones (diálogos y la lista que se recoloca).
Future<void> animate(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;

  setUp(() {
    bookings = FakeBookingRepository();
    users = FakeUserRepository(users: [ana, joana, admin]);
  });

  Future<void> pump(
    WidgetTester tester, {
    String theme = 'light',
    String language = 'es',
    double width = 800,
    double height = 4000,
  }) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': language},
      home: const BookingView(),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      overrides: [
        ...bookingDataOverrides(bookings: bookings, user: admin),
        userRepositoryProvider.overrideWithValue(users),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  Future<void> pumpList(
    WidgetTester tester, {
    String theme = 'light',
    String language = 'es',
    double width = 800,
  }) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': language},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
        adminAppointmentsProvider.overrideWith(
          (ref) => Stream.value([guestAppointment]),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder searchField() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.prefixIcon != null,
  );

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(searchField(), text);
    await settle(tester);
  }

  Future<void> chooseAna(WidgetTester tester) async {
    await search(tester, 'souza');
    await tester.tap(find.text('Ana Souza'));
    await settle(tester);
  }

  /// "Persona sin cuenta" y, con [phone], su WhatsApp, saliendo del campo.
  Future<void> startGuest(
    WidgetTester tester, {
    String language = 'es',
    String? phone,
  }) async {
    final action = language == 'pt' ? 'PESSOA SEM CONTA' : 'PERSONA SIN CUENTA';
    await tester.ensureVisible(find.text(action));
    await tester.tap(find.text(action));
    await settle(tester);
    if (phone == null) return;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), phone);
    await tester.tap(fields.at(0));
    await settle(tester);
  }

  /// "Agendar turno" sin nada más elegido: marca lo que falta. Vuelve
  /// arriba, a "Para quién".
  Future<void> showMissing(WidgetTester tester) async {
    final scroll = appContainer(tester)
        .read(tabScrollControllerProvider(MobileTab.booking));
    final button = find.text(
      Localizations.localeOf(tester.element(find.byType(BookingView))) ==
              const Locale('pt')
          ? 'AGENDAR HORÁRIO'
          : 'AGENDAR TURNO',
    );
    for (var i = 0; i < 10 && button.evaluate().isEmpty; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }
    await tester.ensureVisible(button);
    await animate(tester);
    await tester.tap(button);
    await settle(tester);
    // El aviso de abajo tapa parte de la lista: se quita.
    ScaffoldMessenger.of(tester.element(find.byType(BookingView)))
        .removeCurrentSnackBar();
    scroll.jumpTo(0);
    await animate(tester);
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
    group('tema $theme (RNF-2)', () {
      testWidgets('"Para quién" con resultados', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await search(tester, 'an');
        expect(find.text('Ana Souza'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('la clienta elegida con su turno activo', (tester) async {
        final semantics = tester.ensureSemantics();
        bookings.active = [anaActive()];
        await pump(tester, theme: theme);
        await chooseAna(tester);
        expect(find.textContaining('Ya tiene un turno el'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('la persona sin cuenta con sus errores y el aviso de un '
          'WhatsApp con cuenta', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await startGuest(tester, phone: '41 99222-0000');
        await showMissing(tester);
        expect(
          find.text('Escribe un nombre de hasta 80 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('Este WhatsApp es de Joana Conceição, que tiene cuenta.'),
          findsOneWidget,
        );
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('la confirmación', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await chooseAna(tester);
        await openBookingConfirmation(tester, settle: () => animate(tester));
        expect(find.text('Para: Ana Souza'), findsWidgets);
        await expectGuidelines(tester);
        expectDialogTextContrast(tester);
        semantics.dispose();
      });

      testWidgets('la tarjeta de la lista de la admin', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpList(tester, theme: theme);
        expect(find.text('SIN CUENTA'), findsOneWidget);
        expect(find.text('AGENDADO POR LA ADMIN'), findsOneWidget);
        // La cabecera verde del panel no es de esta spec: se mide la
        // tarjeta, sobre su fondo, con sus colores exactos.
        final card = find.ancestor(
          of: find.text('Rosa Lima'),
          matching: find.byType(FlatCard),
        );
        expectTextContrast(
          tester,
          card,
          tester.widget<FlatCard>(card).color ??
              Theme.of(tester.element(card)).extension<BrandColors>()!.surface,
          // Las iniciales van sobre el círculo del avatar, con su propio
          // fondo.
          skip: [find.byType(InitialsAvatar)],
        );
        // Su botón de WhatsApp: 48 px y con nombre.
        final whatsApp = find.byTooltip('Escribir a Rosa Lima por WhatsApp');
        final size = tester.getSize(whatsApp);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        semantics.dispose();
      });
    });
  }

  group('lector de pantalla (RNF-2)', () {
    testWidgets('cada resultado es un botón con el nombre y el WhatsApp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await search(tester, 'souza');
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Ana Souza, +55 41 99111-0000'),
        ),
        isSemantics(
          label: 'Ana Souza, +55 41 99111-0000',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('el aviso de un WhatsApp con cuenta y el de turno activo se '
        'anuncian', (tester) async {
      final semantics = tester.ensureSemantics();
      bookings.active = [anaActive()];
      await pump(tester);
      tester.takeAnnouncements();
      await startGuest(tester, phone: '41 99111-0000');

      const hasAccount = 'Este WhatsApp es de Ana Souza, que tiene cuenta.';
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains(hasAccount),
      );
      expect(
        tester.getSemantics(find.text(hasAccount)),
        isSemantics(label: hasAccount, isLiveRegion: true),
      );

      final active = find.textContaining('Ya tiene un turno el');
      expect(active, findsOneWidget);
      final label = (tester.widget(active) as Text).data!;
      expect(
        tester.getSemantics(active),
        isSemantics(label: label, isLiveRegion: true),
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

      testWidgets('"Para quién" con resultados y la clienta elegida con su '
          'turno activo, sin desbordes', (tester) async {
        bookings.active = [anaActive()];
        await pump(tester, language: language, width: 320, height: 9000);
        await search(tester, 'souza');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Ana Souza'));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la persona sin cuenta con sus errores y el aviso, sin '
          'desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        await startGuest(tester, language: language, phone: '41 99222-0000');
        await showMissing(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la confirmación, sin desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        await chooseAna(tester);
        await openBookingConfirmation(tester, settle: () => animate(tester));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('la tarjeta de la lista, sin desbordes', (tester) async {
        await pumpList(tester, language: language, width: 320);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
