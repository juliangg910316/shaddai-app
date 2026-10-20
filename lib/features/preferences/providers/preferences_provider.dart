import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/preferences/preferences_logic.dart';
import '../../../data/repositories/preferences_repository.dart';

/// Se sobrescribe en `main` con el almacenamiento ya cargado, y en los tests.
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  throw UnimplementedError(
    'preferencesRepositoryProvider se sobrescribe en main.dart',
  );
});

/// Tema elegido. Sin elección guardada es [ThemePreference.system] (RF-2).
class ThemePreferenceController extends Notifier<ThemePreference> {
  @override
  ThemePreference build() {
    return parseThemePreference(
      ref.read(preferencesRepositoryProvider).readTheme(),
    );
  }

  /// Aplica el tema al momento y lo guarda (RF-5, RF-6). Si no se puede
  /// guardar, el tema vale igual para esta sesión.
  Future<void> select(ThemePreference preference) async {
    state = preference;
    await ref.read(preferencesRepositoryProvider).saveTheme(preference.name);
  }
}

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemePreference>(
      ThemePreferenceController.new,
    );

/// Idioma elegido a mano, o `null` si no hay ninguno guardado: entonces manda
/// el idioma del dispositivo (RF-9, RF-20).
class LanguageController extends Notifier<AppLanguage?> {
  @override
  AppLanguage? build() {
    return parseLanguage(
      ref.read(preferencesRepositoryProvider).readLanguage(),
    );
  }

  /// Aplica el idioma al momento y lo guarda (RF-10, RF-11). Si no se puede
  /// guardar, el idioma vale igual para esta sesión.
  Future<void> select(AppLanguage language) async {
    state = language;
    await ref.read(preferencesRepositoryProvider).saveLanguage(language.name);
  }
}

final languagePreferenceProvider =
    NotifierProvider<LanguageController, AppLanguage?>(LanguageController.new);
