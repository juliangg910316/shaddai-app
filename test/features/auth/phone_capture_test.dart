import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La captura del WhatsApp al registrarse usa el campo compartido y la
/// validación de la spec 007 (spec 009, RF-26, RF-27, plan D-7).
void main() {
  late FakeUserRepository users;

  setUp(() => users = FakeUserRepository());

  Future<void> pump(WidgetTester tester, {String language = 'es'}) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const PhoneCaptureView(),
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(testClientWithoutPhone),
        ),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    // En la app, el router escucha la ficha; aquí, el test.
    appContainer(tester).listen(currentUserProvider, (_, _) {});
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String phone) async {
    await tester.enterText(find.byType(TextField), phone);
    await tester.tap(find.text('GUARDAR Y CONTINUAR'));
    await tester.pumpAndSettle();
  }

  for (final invalid in ['abcdefghij', '1234567', '+55 1234567']) {
    testWidgets('"$invalid" no es válido: error junto al campo y no se guarda '
        '(RF-27)', (tester) async {
      await pump(tester);
      await save(tester, invalid);
      expect(users.phoneUpdates, isEmpty);
      expect(
        find.text('Escribe un número de WhatsApp válido (de 8 a 15 dígitos).'),
        findsOneWidget,
      );
    });
  }

  testWidgets('el error en portugués', (tester) async {
    await pump(tester, language: 'pt');
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('SALVAR E CONTINUAR'));
    await tester.pumpAndSettle();
    expect(
      find.text('Digite um número de WhatsApp válido (de 8 a 15 dígitos).'),
      findsOneWidget,
    );
  });

  testWidgets('uno válido se guarda como hoy, sin error', (tester) async {
    await pump(tester);
    await save(tester, '  +55 41 99999-0000 ');
    expect(users.phoneUpdates, [
      (uid: testClientWithoutPhone.uid, phone: '+55 41 99999-0000'),
    ]);
    expect(find.textContaining('válido'), findsNothing);
  });

  testWidgets('al corregirlo, el error desaparece y se guarda', (tester) async {
    await pump(tester);
    await save(tester, 'abc');
    expect(find.textContaining('válido'), findsOneWidget);
    await save(tester, '41 99999-0000');
    expect(find.textContaining('válido'), findsNothing);
    expect(users.phoneUpdates.single.phone, '41 99999-0000');
  });
}
