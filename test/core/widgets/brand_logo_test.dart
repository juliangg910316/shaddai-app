import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/widgets/brand_logo.dart';
import 'package:shaddai/features/auth/presentation/login_view.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/pump_app.dart';

/// Pantallas que muestran la marca encima del contenido.
final _screens = <String, Widget Function()>{
  'login': () => const LoginView(),
  'captura de WhatsApp': () => const PhoneCaptureView(),
};

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String theme = 'light',
  String language = 'es',
}) async {
  await pumpApp(
    tester,
    stored: {'theme': theme, 'language': language},
    home: home,
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      userRepositoryProvider.overrideWithValue(FakeUserRepository()),
    ],
  );
  await tester.pump();
}

void main() {
  test('el sello está en los assets de la app', () {
    expect(File(BrandLogo.asset).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains(BrandLogo.asset));
  });

  test("ya no queda el monograma \"D'S\" de D'Shaddai en lib", () {
    final leftovers = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            entity.readAsStringSync().contains("D'S"))
          entity.path,
    ];
    expect(leftovers, isEmpty);
  });

  for (final MapEntry(key: name, value: build) in _screens.entries) {
    group(name, () {
      for (final (theme, brand) in [
        ('light', BrandColors.light),
        ('dark', BrandColors.dark),
      ]) {
        testWidgets('muestra el sello de Studio Shaddai en dorado ($theme)', (
          tester,
        ) async {
          await _pump(tester, build(), theme: theme);

          expect(find.byType(BrandLogo), findsOneWidget);
          final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(
            svg.colorFilter,
            ColorFilter.mode(brand.accentIcon, BlendMode.srcIn),
          );
        });
      }

      for (final (language, label) in [
        ('es', 'Logotipo de Studio Shaddai'),
        ('pt', 'Logotipo do Studio Shaddai'),
      ]) {
        testWidgets('el lector de pantalla lo anuncia en $language', (
          tester,
        ) async {
          await _pump(tester, build(), language: language);

          expect(find.bySemanticsLabel(label), findsOneWidget);
        });
      }
    });
  }
}
