/// Reglas puras de las preferencias de tema e idioma (spec 001).
///
/// Sin Flutter ni Firebase: reciben los valores guardados y el idioma del
/// dispositivo como texto, para poder probarlas sin la app.
library;

/// Preferencia de tema elegida por la persona (RF-1).
enum ThemePreference { light, dark, system }

/// Idiomas de la interfaz (RF-8).
enum AppLanguage { es, pt }

/// Tema guardado. Sin valor, o con uno desconocido, es [ThemePreference.system]
/// (RF-2).
ThemePreference parseThemePreference(String? stored) {
  for (final preference in ThemePreference.values) {
    if (preference.name == stored) return preference;
  }
  return ThemePreference.system;
}

/// Idioma guardado, o `null` si no hay ninguno válido.
AppLanguage? parseLanguage(String? stored) {
  for (final language in AppLanguage.values) {
    if (language.name == stored) return language;
  }
  return null;
}

/// Idioma a partir de la etiqueta del dispositivo ("pt-BR", "es_AR"…).
///
/// Se queda con el idioma y descarta la región. Cualquier idioma que no sea
/// español ni portugués usa español (RF-9).
AppLanguage languageFromDevice(String? deviceLanguageTag) {
  final code = (deviceLanguageTag ?? '').toLowerCase().split(RegExp('[-_]'));
  return code.first == 'pt' ? AppLanguage.pt : AppLanguage.es;
}

/// Idioma efectivo: el guardado si es válido (RF-12) y, si no, el del
/// dispositivo (RF-9).
AppLanguage resolveLanguage(String? stored, String? deviceLanguageTag) {
  return parseLanguage(stored) ?? languageFromDevice(deviceLanguageTag);
}
