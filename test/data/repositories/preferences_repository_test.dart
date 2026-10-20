import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/throwing_preferences.dart';

Future<SharedPreferences> _store([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('con almacenamiento disponible', () {
    test('sin nada guardado devuelve null', () async {
      final repo = PreferencesRepository(await _store());

      expect(repo.readTheme(), isNull);
      expect(repo.readLanguage(), isNull);
    });

    test('lee lo que ya estaba guardado', () async {
      final repo = PreferencesRepository(
        await _store({'theme': 'dark', 'language': 'pt'}),
      );

      expect(repo.readTheme(), 'dark');
      expect(repo.readLanguage(), 'pt');
    });

    test('guarda el tema y el idioma, y se releen (RF-6, RF-11)', () async {
      final store = await _store();
      final repo = PreferencesRepository(store);

      await repo.saveTheme('light');
      await repo.saveLanguage('es');

      // Otra instancia sobre el mismo almacenamiento, como al reabrir la app.
      final reopened = PreferencesRepository(store);
      expect(reopened.readTheme(), 'light');
      expect(reopened.readLanguage(), 'es');
    });

    test('usa las claves theme y language', () async {
      final store = await _store();
      final repo = PreferencesRepository(store);

      await repo.saveTheme('system');
      await repo.saveLanguage('pt');

      expect(store.getString('theme'), 'system');
      expect(store.getString('language'), 'pt');
    });
  });

  group('sin almacenamiento disponible', () {
    test('si no hay almacenamiento, lee null y no guarda nada', () async {
      const repo = PreferencesRepository(null);

      expect(repo.readTheme(), isNull);
      expect(repo.readLanguage(), isNull);
      await expectLater(repo.saveTheme('dark'), completes);
      await expectLater(repo.saveLanguage('pt'), completes);
    });

    test('si el almacenamiento falla, no lanza', () async {
      final repo = PreferencesRepository(ThrowingPreferences());

      expect(repo.readTheme(), isNull);
      expect(repo.readLanguage(), isNull);
      await expectLater(repo.saveTheme('dark'), completes);
      await expectLater(repo.saveLanguage('pt'), completes);
    });
  });
}
