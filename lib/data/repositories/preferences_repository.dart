import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de tema e idioma guardadas solo en el dispositivo o navegador
/// (spec 001, RNF-3): nunca van a Firebase.
///
/// Recibe el almacenamiento ya cargado (se obtiene en `main` antes de arrancar
/// la app). Es `null` cuando no está disponible, por ejemplo en un navegador en
/// modo privado. Nunca lanza: si algo falla, lee `null` y no guarda, y la app
/// sigue con los valores por defecto.
class PreferencesRepository {
  final SharedPreferences? _store;

  const PreferencesRepository(this._store);

  static const _themeKey = 'theme';
  static const _languageKey = 'language';

  String? readTheme() => _read(_themeKey);

  String? readLanguage() => _read(_languageKey);

  Future<void> saveTheme(String value) => _save(_themeKey, value);

  Future<void> saveLanguage(String value) => _save(_languageKey, value);

  String? _read(String key) {
    try {
      return _store?.getString(key);
    } catch (e) {
      debugPrint('No se pudo leer la preferencia "$key": $e');
      return null;
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await _store?.setString(key, value);
    } catch (e) {
      debugPrint('No se pudo guardar la preferencia "$key": $e');
    }
  }
}
