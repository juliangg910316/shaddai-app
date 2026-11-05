import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba. En la lista de los
// tests, "Spa de manos" dura 45 min, "Corto" (con el adicional "Cromado")
// 2 h, y el combo "Gel Completo" 2 h 30 min.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

/// Un turno activo con lo reservado y un adicional.
AppointmentModel active() => AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(20, 9)),
  endTime: fromSalon(at(20, 11)),
  status: 'waiting_confirmation',
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
        priceCents: 2000,
      ),
    ],
  ),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

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

  /// Hora, servicio y adicional elegidos: así se ven todas las partes del
  /// formulario, también el resumen y las horas desactivadas.
  Future<void> chooseAll(
    WidgetTester tester, {
    String time = '10:00',
    String service = 'Corto',
  }) async {
    await tap(tester, find.text(time));
    await tap(tester, find.text(service).first);
    await tap(tester, find.text('Cromado').first);
  }

  /// Mide con la lista arriba del todo: `ensureVisible` deja lo tocado
  /// arriba, y un texto a medias fuera de la pantalla se mediría mal.
  Future<void> expectGuidelines(WidgetTester tester) async {
    final scroll = appContainer(tester)
        .read(tabScrollControllerProvider(MobileTab.booking));
    if (scroll.hasClients) scroll.jumpTo(0);
    await settle(tester);
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
      testWidgets('el formulario cumple contraste y tamaño táctil', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await chooseAll(tester);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('lo que falta, marcado, cumple el contraste', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await tap(tester, find.text('AGENDAR TURNO'));
        // El aviso flota sobre la vista: se mide la vista sin él.
        ScaffoldMessenger.of(tester.element(find.byType(BookingView)))
            .removeCurrentSnackBar();
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('el turno activo cumple contraste y tamaño táctil', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        bookings.mine = [active()];
        await pump(tester, theme: theme);
        await expectGuidelines(tester);
        semantics.dispose();
      });
    });
  }

  group('semántica (RNF-2)', () {
    testWidgets('la hora y el servicio elegidos se anuncian como elegidos', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await tap(tester, find.text('10:00'));
      await tap(tester, find.text('Spa de manos').first);

      expect(
        tester.getSemantics(find.text('10:00')),
        isSemantics(
          label: '10:00',
          isButton: true,
          isSelected: true,
          isEnabled: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Spa de manos').first),
        isSemantics(isButton: true, isSelected: true, isEnabled: true),
      );
      semantics.dispose();
    });

    testWidgets('lo que no se puede elegir dice "no disponible"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await tap(tester, find.text('17:00'));

      expect(
        tester.getSemantics(find.text('Corto').first),
        isSemantics(
          label: 'Corto, R\$ 150 · 2 h, no disponible',
          isButton: true,
          isSelected: false,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('los avisos se anuncian al lector de pantalla', (tester) async {
      await pump(tester);
      tester.takeAnnouncements();

      await tap(tester, find.text('10:00'));
      bookings.emitBusy([
        BusySlot(
          id: 'x',
          start: fromSalon(at(10, 10)),
          end: fromSalon(at(10, 11)),
        ),
      ]);
      await settle(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('La hora elegida ya no está disponible. Elige otra.'),
      );

      await tap(tester, find.text('AGENDAR TURNO'));
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Elige una hora y un servicio para agendar.'),
      );
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

      testWidgets('el formulario, sin desbordes', (tester) async {
        await pump(tester, language: language, width: 320, height: 9000);
        await chooseAll(tester, service: language == 'es' ? 'Corto' : 'Curto');
        await tap(tester, find.byType(ElevatedButton).last);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el turno activo, sin desbordes', (tester) async {
        bookings.mine = [active()];
        await pump(tester, language: language, width: 320, height: 2400);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
