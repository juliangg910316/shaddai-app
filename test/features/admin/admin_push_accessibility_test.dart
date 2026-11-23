import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/contrast.dart';
import 'package:shaddai/data/models/push_notice.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';

import '../../helpers/dialog_contrast.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_push.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// Accesibilidad de los avisos push en la app: contraste en claro y oscuro,
/// botones de 48 px con nombre, el aviso anunciado al lector y el texto al
/// 200 % en 320 px (spec 011, RNF-1 a RNF-3, RC-1; plan § 8, § 9; T9).
final admin = UserModel(
  uid: 'beidis',
  email: 'beidis@example.com',
  displayName: 'Beidis',
  role: 'admin',
  phoneNumber: '+5541999990000',
);

List<Override> get emptyAgenda => [
  ...bookingScheduleOverrides(bookings: FakeBookingRepository()),
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
];

final notice = PushNotice.fromParts(
  title: 'Turno nuevo',
  body:
      'Ana Herrera · sábado 21 de noviembre, 10:00 · Manicura. Espera tu '
      'confirmación.',
  data: {'kind': 'created', 'appointmentId': 't1', 'day': '2026-11-21'},
);

final explanation = find.byKey(const Key('admin-push-dialog'));
final disabledCard = find.byKey(const Key('admin-push-disabled'));
final snackBar = find.byType(SnackBar);

Future<FakePushRepository> pump(
  WidgetTester tester, {
  PushPermission permission = PushPermission.granted,
  String theme = 'light',
  String language = 'es',
  double width = 412,
  double textScale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final push = FakePushRepository(currentPermission: permission);
  await pumpMobileApp(
    tester,
    location: '/admin',
    user: admin,
    stored: {'theme': theme, 'language': language},
    width: width,
    pushRepository: push,
    overrides: emptyAgenda,
  );
  await settleWeb(tester);
  return push;
}

Future<void> showNotice(WidgetTester tester, FakePushRepository push) async {
  push.receiveNotice(notice);
  await settleWeb(tester);
}

/// El texto de [button] sobre su propio fondo (WCAG AA).
void expectButtonTextContrast(WidgetTester tester, Finder button) {
  final material = tester.widget<Material>(
    find.descendant(of: button, matching: find.byType(Material)).first,
  );
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: button, matching: find.byType(RichText)).first,
  );
  final style = paragraph.text.style!;
  final bold = (style.fontWeight?.value ?? 400) >= 700;
  expect(
    contrastRatio(style.color!.toARGB32(), material.color!.toARGB32()),
    greaterThanOrEqualTo(isLargeText(style.fontSize!, bold: bold) ? 3 : 4.5),
  );
}

/// El botón mide al menos 48 × 48 px.
void expectTapTarget(WidgetTester tester, Finder button) {
  final size = tester.getSize(button);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}

void main() {
  for (final theme in ['light', 'dark']) {
    group('tema $theme: contraste (RNF-1)', () {
      testWidgets('la explicación del permiso', (tester) async {
        await pump(tester, permission: PushPermission.notAsked, theme: theme);
        expect(explanation, findsOneWidget);
        expectDialogTextContrast(tester);
        expectButtonTextContrast(
          tester,
          find.widgetWithText(ElevatedButton, 'Continuar'),
        );
      });

      testWidgets('el aviso de permiso denegado', (tester) async {
        await pump(tester, permission: PushPermission.denied, theme: theme);
        final card = find.descendant(
          of: disabledCard,
          matching: find.byType(Container),
        );
        final decoration =
            tester.widget<Container>(card.first).decoration! as BoxDecoration;
        expectTextContrast(tester, disabledCard, decoration.color!);
      });

      testWidgets('el aviso con la app abierta y "Ver"', (tester) async {
        final push = await pump(tester, theme: theme);
        await showNotice(tester, push);
        final background = Theme.of(tester.element(snackBar))
            .snackBarTheme
            .backgroundColor!;
        expectTextContrast(tester, snackBar, background);
        final view = find.widgetWithText(TextButton, 'Ver');
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: view, matching: find.byType(RichText)).first,
        );
        expect(
          contrastRatio(
            paragraph.text.style!.color!.toARGB32(),
            background.toARGB32(),
          ),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  group('botones y lector de pantalla (RNF-2)', () {
    testWidgets('"Continuar": 48 px y su nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, permission: PushPermission.notAsked);
      final button = find.widgetWithText(ElevatedButton, 'Continuar');
      expectTapTarget(tester, button);
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Continuar',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('"Ver": 48 px y su nombre', (tester) async {
      final semantics = tester.ensureSemantics();
      final push = await pump(tester);
      await showNotice(tester, push);
      final button = find.widgetWithText(TextButton, 'Ver');
      expectTapTarget(tester, button);
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Ver la agenda de ese día',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('el aviso con la app abierta se anuncia', (tester) async {
      final push = await pump(tester);
      tester.takeAnnouncements();
      await showNotice(tester, push);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains(
          'Turno nuevo. Ana Herrera · sábado 21 de noviembre, 10:00 · '
          'Manicura. Espera tu confirmación.',
        ),
      );
    });
  });

  group('texto al 200 % en 320 px (RNF-3)', () {
    for (final language in ['es', 'pt']) {
      testWidgets('la explicación, en $language', (tester) async {
        await pump(
          tester,
          permission: PushPermission.notAsked,
          language: language,
          width: 320,
          textScale: 2,
        );
        expect(explanation, findsOneWidget);
        expect(tester.takeException(), isNull);
        // El botón se ve entero dentro de la pantalla.
        final button = find.descendant(
          of: explanation,
          matching: find.byType(ElevatedButton),
        );
        expect(tester.getRect(button).right, lessThanOrEqualTo(320));
      });

      testWidgets('el aviso de permiso denegado, en $language', (tester) async {
        await pump(
          tester,
          permission: PushPermission.denied,
          language: language,
          width: 320,
          textScale: 2,
        );
        expect(disabledCard, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(disabledCard).right, lessThanOrEqualTo(320));
      });

      testWidgets('el aviso con la app abierta, en $language', (tester) async {
        final push = await pump(
          tester,
          language: language,
          width: 320,
          textScale: 2,
        );
        await showNotice(tester, push);
        expect(snackBar, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
