import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/core/theme/contrast.dart';
import 'package:shaddai/features/booking/presentation/booking_notices.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/l10n/app_localizations.dart';

/// El aviso de error de "Agendar turno" y de "Guardar cambios" va sobre el
/// color de peligro: su texto tiene que leerse en los dos temas (spec 005,
/// RNF-2; spec 006, RNF-2).
void main() {
  Future<void> show(
    WidgetTester tester,
    ThemeData theme,
    void Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => action(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  double contrastOf(WidgetTester tester, String message) {
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == message,
        ),
      ),
    );
    return contrastRatio(
      text.text.style!.color!.toARGB32(),
      snackBar.backgroundColor!.toARGB32(),
    );
  }

  for (final (name, theme) in [
    ('claro', AppTheme.light),
    ('oscuro', AppTheme.dark),
  ]) {
    testWidgets('tema $name: el error de "Guardar cambios" se lee', (
      tester,
    ) async {
      await show(
        tester,
        theme,
        (context) => showEditSaveResult(context, EditSaveOutcome.failed),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(contrastOf(tester, l10n.bookingEditSaveError), greaterThan(4.5));
    });

    testWidgets('tema $name: el error de "Agendar turno" se lee', (
      tester,
    ) async {
      await show(
        tester,
        theme,
        (context) =>
            showBookingSubmitResult(context, BookingSubmitResult.failed),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(contrastOf(tester, l10n.bookingCreateError), greaterThan(4.5));
    });
  }
}
