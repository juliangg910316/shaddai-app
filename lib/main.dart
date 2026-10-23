import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/preferences/preferences_logic.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_colors.dart';
import 'core/theme/system_bars.dart';
import 'data/firestore_cache.dart';
import 'data/repositories/preferences_repository.dart';
import 'features/preferences/providers/preferences_provider.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase ya estaba inicializado o falta configuración: $e');
  }

  // En Web, la lista de precios se ve sin conexión con los datos de la última
  // visita (spec 004, RF-40).
  configureFirestoreCache(isWeb: kIsWeb);

  // Las preferencias se cargan antes de arrancar para que el primer fotograma
  // ya use el tema y el idioma guardados (RF-7, RF-12). Si el almacenamiento
  // no está disponible, la app sigue con los valores por defecto.
  SharedPreferences? store;
  try {
    store = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Almacenamiento de preferencias no disponible: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(store),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themePreference = ref.watch(themePreferenceProvider);
    final language = ref.watch(languagePreferenceProvider);

    return MaterialApp.router(
      // Título de la pestaña del navegador, en el idioma activo (spec 002).
      onGenerateTitle: (context) => AppLocalizations.of(context)!.webAppTitle,

      // Tema (RF-1 a RF-5). Sin animación, el cambio se ve en el siguiente
      // fotograma (RNF-2).
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.system => ThemeMode.system,
      },
      themeAnimationDuration: Duration.zero,

      // Idioma. Con preferencia guardada manda ella (RF-12). Sin ella, `locale`
      // es nulo y Flutter resuelve el idioma del dispositivo con el callback,
      // también cuando cambia con la app abierta (RF-9, RF-20).
      locale: language == null ? null : Locale(language.name),
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        final tag = (deviceLocales == null || deviceLocales.isEmpty)
            ? null
            : deviceLocales.first.toLanguageTag();
        return Locale(languageFromDevice(tag).name);
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''), // Español
        Locale('pt', ''), // Portugués
      ],

      // Barras del sistema legibles sobre el fondo del tema (RF-23). Las
      // pantallas con cabecera propia (admin) las sobrescriben.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemBarsStyleFor(context.brand.background),
        child: child ?? const SizedBox.shrink(),
      ),

      // Routing. El router no depende del tema ni del idioma: al cambiarlos se
      // conserva la pantalla y su estado (RF-5, RF-10).
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
