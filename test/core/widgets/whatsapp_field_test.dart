import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/core/widgets/whatsapp_field.dart';

import '../../helpers/pump_app.dart';

/// El campo de WhatsApp compartido por la captura del registro y el cambio
/// desde el perfil (spec 009, RF-26, RF-27, plan D-7).
void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    String text = '',
    String? errorText,
    String language = 'es',
  }) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      stored: {'language': language},
      home: Scaffold(
        body: WhatsAppField(controller: controller, errorText: errorText),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('trae el número escrito, el icono y el texto de '
      'consentimiento', (tester) async {
    await pump(tester, text: '+55 41 99999-0000');
    expect(find.text('+55 41 99999-0000'), findsOneWidget);
    expect(find.text('TU WHATSAPP'), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
    expect(
      find.textContaining('Beidis te escribe por WhatsApp'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.phone,
    );
  });

  testWidgets('en portugués', (tester) async {
    await pump(tester, language: 'pt');
    expect(find.text('SEU WHATSAPP'), findsOneWidget);
    expect(find.textContaining('Beidis fala com você'), findsOneWidget);
  });

  testWidgets('el error va junto al campo, en el color de peligro de la '
      'marca (RF-27)', (tester) async {
    await pump(tester, errorText: 'Número inválido');
    final error = tester.widget<Text>(find.text('Número inválido'));
    final brand = tester.element(find.byType(WhatsAppField)).brand;
    expect(error.style?.color, brand.danger);
  });

  testWidgets('sin error no muestra ninguno', (tester) async {
    await pump(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
      isNull,
    );
  });
}
