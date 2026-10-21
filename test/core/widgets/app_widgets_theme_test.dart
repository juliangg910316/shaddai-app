import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
import 'package:shaddai/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

Color? _boxColor(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  for (final (name, theme, brand) in [
    ('claro', AppTheme.light, BrandColors.light),
    ('oscuro', AppTheme.dark, BrandColors.dark),
  ]) {
    group('tema $name (RF-15, RF-16)', () {
      testWidgets('los widgets compartidos toman sus colores del tema', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          const Column(
            children: [
              SectionHeading('Mis turnos'),
              FlatCard(key: Key('card'), child: Text('Tarjeta')),
              InitialsAvatar(key: Key('avatar'), name: 'Ana Herrera'),
              PhotoPlaceholder(key: Key('photo'), height: 60),
            ],
          ),
        );

        expect(_boxColor(tester, find.byKey(const Key('card'))), brand.surface);
        expect(_boxColor(tester, find.byKey(const Key('avatar'))), brand.brand);
        expect(
          _boxColor(tester, find.byKey(const Key('photo'))),
          brand.placeholder,
        );
        expect(
          tester.widget<Text>(find.text('Mis turnos')).style?.color,
          brand.inkStrong,
        );
      });

      testWidgets('los textos de los widgets compartidos se leen bien', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          Column(
            children: [
              const SectionHeading('Mis turnos'),
              SectionHeadingWithAction(
                'Servicios',
                actionLabel: 'VER TODO',
                onAction: () {},
              ),
              const FlatCard(child: Text('Tarjeta')),
              const InitialsAvatar(name: 'Ana Herrera'),
              const PhotoPlaceholder(height: 60),
              GoldPillButton(label: 'RESERVAR', onPressed: () {}),
              OutlinePillButton(label: 'OTRO TURNO', onPressed: () {}),
            ],
          ),
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('los estados de turno usan colores del tema', (tester) async {
        late AppLocalizations l10n;
        await _pump(
          tester,
          theme,
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        );

        for (final status in ['confirmed', 'cancelled', 'waiting']) {
          final client = AppointmentStatusStyle.forClient(l10n, status, brand);
          final admin = AppointmentStatusStyle.forAdmin(l10n, status, brand);
          expect([
            brand.inkStrong,
            brand.danger,
            brand.accentText,
          ], contains(client.color));
          expect(admin.color, client.color);
        }
      });
    });
  }
}
