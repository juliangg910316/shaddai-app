import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';

void main() {
  group('parseThemePreference', () {
    test('lee los tres valores guardados (RF-1)', () {
      expect(parseThemePreference('light'), ThemePreference.light);
      expect(parseThemePreference('dark'), ThemePreference.dark);
      expect(parseThemePreference('system'), ThemePreference.system);
    });

    test('sin preferencia guardada usa sistema (RF-2)', () {
      expect(parseThemePreference(null), ThemePreference.system);
    });

    test('un valor corrupto o desconocido usa sistema', () {
      expect(parseThemePreference('xyz'), ThemePreference.system);
      expect(parseThemePreference(''), ThemePreference.system);
      expect(parseThemePreference('DARK'), ThemePreference.system);
    });
  });

  group('parseLanguage', () {
    test('lee los dos idiomas guardados (RF-8)', () {
      expect(parseLanguage('es'), AppLanguage.es);
      expect(parseLanguage('pt'), AppLanguage.pt);
    });

    test('sin valor o con un valor desconocido devuelve null', () {
      expect(parseLanguage(null), isNull);
      expect(parseLanguage(''), isNull);
      expect(parseLanguage('en'), isNull);
      expect(parseLanguage('xyz'), isNull);
    });
  });

  group('languageFromDevice (RF-9)', () {
    test('español y portugués del dispositivo se respetan', () {
      expect(languageFromDevice('es'), AppLanguage.es);
      expect(languageFromDevice('pt'), AppLanguage.pt);
    });

    test('las variantes regionales se quedan con el idioma', () {
      expect(languageFromDevice('pt-BR'), AppLanguage.pt);
      expect(languageFromDevice('pt_PT'), AppLanguage.pt);
      expect(languageFromDevice('es_AR'), AppLanguage.es);
      expect(languageFromDevice('es-419'), AppLanguage.es);
    });

    test('no distingue mayúsculas', () {
      expect(languageFromDevice('PT'), AppLanguage.pt);
      expect(languageFromDevice('Pt-br'), AppLanguage.pt);
    });

    test('otro idioma, vacío o nulo usa español', () {
      expect(languageFromDevice('en'), AppLanguage.es);
      expect(languageFromDevice('en-US'), AppLanguage.es);
      expect(languageFromDevice(''), AppLanguage.es);
      expect(languageFromDevice(null), AppLanguage.es);
    });
  });

  group('resolveLanguage (RF-9, RF-12)', () {
    test('la preferencia guardada manda sobre el dispositivo', () {
      expect(resolveLanguage('pt', 'es-ES'), AppLanguage.pt);
      expect(resolveLanguage('es', 'pt-BR'), AppLanguage.es);
    });

    test('sin preferencia usa el idioma del dispositivo', () {
      expect(resolveLanguage(null, 'pt-BR'), AppLanguage.pt);
      expect(resolveLanguage(null, 'en'), AppLanguage.es);
    });

    test('una preferencia corrupta se ignora y usa el dispositivo', () {
      expect(resolveLanguage('xyz', 'pt-BR'), AppLanguage.pt);
      expect(resolveLanguage('xyz', null), AppLanguage.es);
    });
  });
}
