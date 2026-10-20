import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/core/router/app_router.dart';
import 'package:shaddai/data/repositories/preferences_repository.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:shaddai/l10n/app_localizations.dart';
import 'package:shaddai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monta la app real ([MyApp]) sin Firebase: el router se sustituye por
/// [router] o, si no se pasa, por una sola ruta con [home]. Las preferencias
/// usan un almacenamiento en memoria con los valores [stored], y [overrides]
/// sustituye los providers que tocarían Firebase.
Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  Widget home = const ProbePage(),
  GoRouter? router,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final store = await SharedPreferences.getInstance();
  final appRouter =
      router ??
      GoRouter(
        routes: [GoRoute(path: '/', builder: (context, state) => home)],
      );
  addTearDown(appRouter.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(store),
        ),
        goRouterProvider.overrideWithValue(appRouter),
        ...overrides,
      ],
      child: const MyApp(),
    ),
  );
}

/// Contenedor de providers de la app montada con [pumpApp].
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyApp)));

/// Página de prueba que muestra un texto de la app, uno de Material y un campo
/// de texto, para comprobar el idioma, el tema y que el estado se conserva.
class ProbePage extends StatelessWidget {
  const ProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(AppLocalizations.of(context)!.homeTab, key: const Key('app')),
          Text(
            MaterialLocalizations.of(context).okButtonLabel,
            key: const Key('material'),
          ),
          const TextField(key: Key('field')),
        ],
      ),
    );
  }
}

/// Tema y idioma efectivos en la página de prueba.
Brightness probeBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ProbePage))).brightness;

String probeLanguage(WidgetTester tester) =>
    Localizations.localeOf(tester.element(find.byType(ProbePage))).languageCode;
