import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba. El turno es el
// viernes 20 de 9:00 a 11:00: "Corto" (2 h) con "Cromado".
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

AppointmentModel active() => AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(20, 9)),
  endTime: fromSalon(at(20, 11)),
  status: 'confirmed',
  createdAt: bookingTestNow,
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 'gel-short',
    name: BilingualText(es: 'Corto', pt: 'Curto'),
    priceCents: 15000,
    durationMinutes: 120,
    addons: [
      BookedAddonModel(
        id: 'chrome',
        name: BilingualText(es: 'Cromado', pt: 'Cromado'),
        priceCents: 1500,
      ),
    ],
  ),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Un diálogo tarda en abrirse o cerrarse: mientras se anima, su contenido
/// no está en el árbol de semántica.
Future<void> animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await settle(tester);
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository(mine: [active()]));

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
        ...bookingDataOverrides(bookings: bookings),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  String editAction(String language) =>
      language == 'pt' ? 'EDITAR HORÁRIO' : 'EDITAR TURNO';
  String saveAction(String language) =>
      language == 'pt' ? 'SALVAR ALTERAÇÕES' : 'GUARDAR CAMBIOS';

  /// Abre la edición y cambia la hora a las 14:00.
  Future<void> editHour(WidgetTester tester, {String language = 'es'}) async {
    await tap(tester, find.text(editAction(language)));
    expect(find.byType(BookingForm), findsOneWidget);
    await tap(tester, find.text('14:00'));
  }

  /// "Guardar cambios": abre el diálogo de antes y después.
  Future<void> openChanges(
    WidgetTester tester, {
    String language = 'es',
  }) async {
    await tap(tester, find.text(saveAction(language)));
    await animate(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  /// Confirma el diálogo de antes y después: abre "Cambios guardados".
  Future<void> confirmChanges(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await animate(tester);
    expect(bookings.edited, hasLength(1));
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

  for (final theme in ['light', 'dark']) {
    group('tema $theme (RNF-2)', () {
      testWidgets('la edición: "Guardar cambios" y "Cancelar"', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await editHour(tester);
        appContainer(tester)
            .read(tabScrollControllerProvider(MobileTab.booking))
            .jumpTo(0);
        await settle(tester);
        expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
        expect(find.text('CANCELAR'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('el diálogo de antes y después', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await editHour(tester);
        await openChanges(tester);
        await expectGuidelines(tester);
        expectDialogTextContrast(tester);
        semantics.dispose();
      });

      testWidgets('"Cambios guardados"', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await editHour(tester);
        await openChanges(tester);
        await confirmChanges(tester);
        expect(find.text('Cambios guardados'), findsOneWidget);
        await expectGuidelines(tester);
        expectDialogTextContrast(tester);
        semantics.dispose();
      });
    });
  }

  group('semántica (RNF-2)', () {
    testWidgets('"Editar turno", "Guardar cambios" y "Cancelar" son botones '
        'con nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(
        tester.getSemantics(find.text('EDITAR TURNO')),
        isSemantics(label: 'EDITAR TURNO', isButton: true, isEnabled: true),
      );
      await editHour(tester);
      for (final label in ['GUARDAR CAMBIOS', 'CANCELAR']) {
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(label: label, isButton: true, isEnabled: true),
          reason: label,
        );
      }
      semantics.dispose();
    });

    testWidgets('en el antes y el después se anuncia lo que cambia', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await editHour(tester);
      await openChanges(tester);
      expect(
        find.bySemanticsLabel('Inicio, cambia. Antes: 9:00. Después: 14:00.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Servicio: Corto'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('los avisos de la edición se anuncian', (tester) async {
      await pump(tester);
      await tap(tester, find.text('EDITAR TURNO'));
      tester.takeAnnouncements();

      // Lo que falta (RF-10).
      await tap(tester, find.text('9:00'));
      await tap(tester, find.text('GUARDAR CAMBIOS'));
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Elige una hora'),
      );

      // El error al guardar (RF-16).
      await tap(tester, find.text('14:00'));
      bookings.updateError = Exception('offline');
      await openChanges(tester);
      tester.takeAnnouncements();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await animate(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('No pudimos guardar los cambios. Inténtalo de nuevo.'),
      );
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

      testWidgets('la edición, sin desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        await editHour(tester, language: language);
        expect(find.text(saveAction(language)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('los dos diálogos, sin desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        await editHour(tester, language: language);
        await openChanges(tester, language: language);
        expect(tester.takeException(), isNull);
        await confirmChanges(tester);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
