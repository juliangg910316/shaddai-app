import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Accesibilidad del panel de la admin (spec 010, RNF-1 a RNF-4). T5 mide
/// la cabecera verde de la agenda; T10 añade la lista y los diálogos.
///
/// "Ahora" es el viernes 20/11/2026 a las 7:00 del salón.
final now = DateTime.utc(2026, 11, 20, 10);

AppointmentModel appointment(String id, String status, int hour) {
  final start = fromSalon(DateTime.utc(2026, 11, 20, hour));
  return AppointmentModel(
    id: id,
    clientId: id,
    clientName: 'Clienta $id',
    clientPhone: '+55 41 99999-000$hour',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: start,
  );
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, {String theme = 'light'}) async {
    await loadAppFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'theme': theme, 'language': 'es'},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(
          FakeBookingRepository()
            ..day = [
              appointment('a', 'waiting_confirmation', 9),
              appointment('b', 'confirmed', 11),
            ],
        ),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => now),
        salonNowProvider.overrideWith((ref) => Stream.value(toSalon(now))),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  final header = find.byKey(const ValueKey('agenda-header'));

  for (final theme in ['light', 'dark']) {
    group('tema $theme (RNF-1)', () {
      testWidgets('la cabecera verde: subtítulo y contadores con contraste '
          'AA, medidos con sus colores exactos', (tester) async {
        await pump(tester, theme: theme);
        expect(find.text('PANEL DE BEIDIS'), findsOneWidget);
        expect(find.text('TURNOS DEL DÍA'), findsOneWidget);
        expectTextContrast(
          tester,
          header,
          Theme.of(tester.element(header)).extension<BrandColors>()!.brand,
        );
      });

      testWidgets('la agenda pasa textContrastGuideline', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, theme: theme);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    });
  }
}
