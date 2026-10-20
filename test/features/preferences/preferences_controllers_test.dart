import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/repositories/preferences_repository.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/throwing_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final store = await SharedPreferences.getInstance();
  return _containerWith(PreferencesRepository(store));
}

ProviderContainer _containerWith(PreferencesRepository repo) {
  final container = ProviderContainer(
    overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('tema', () {
    test('sin nada guardado es sistema (RF-2)', () async {
      final container = await _container();
      expect(container.read(themePreferenceProvider), ThemePreference.system);
    });

    test('lee el tema guardado al arrancar (RF-7)', () async {
      final container = await _container({'theme': 'dark'});
      expect(container.read(themePreferenceProvider), ThemePreference.dark);
    });

    test('un valor guardado corrupto es sistema', () async {
      final container = await _container({'theme': 'xyz'});
      expect(container.read(themePreferenceProvider), ThemePreference.system);
    });

    test('elegir un tema lo aplica y lo guarda (RF-5, RF-6)', () async {
      final container = await _container();

      await container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.light);

      expect(container.read(themePreferenceProvider), ThemePreference.light);
      final store = await SharedPreferences.getInstance();
      expect(store.getString('theme'), 'light');
    });

    test('elegir un tema lo aplica aunque falle el guardado', () async {
      final container = _containerWith(
        PreferencesRepository(ThrowingPreferences()),
      );

      await container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.dark);

      expect(container.read(themePreferenceProvider), ThemePreference.dark);
    });
  });

  group('idioma', () {
    test('sin nada guardado no hay preferencia', () async {
      final container = await _container();
      expect(container.read(languagePreferenceProvider), isNull);
    });

    test('lee el idioma guardado al arrancar (RF-12)', () async {
      final container = await _container({'language': 'pt'});
      expect(container.read(languagePreferenceProvider), AppLanguage.pt);
    });

    test('un valor guardado corrupto se ignora', () async {
      final container = await _container({'language': 'en'});
      expect(container.read(languagePreferenceProvider), isNull);
    });

    test('elegir un idioma lo aplica y lo guarda (RF-10, RF-11)', () async {
      final container = await _container();

      await container
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);

      expect(container.read(languagePreferenceProvider), AppLanguage.pt);
      final store = await SharedPreferences.getInstance();
      expect(store.getString('language'), 'pt');
    });

    test('elegir un idioma lo aplica aunque falle el guardado', () async {
      final container = _containerWith(const PreferencesRepository(null));

      await container
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.es);

      expect(container.read(languagePreferenceProvider), AppLanguage.es);
    });
  });
}
