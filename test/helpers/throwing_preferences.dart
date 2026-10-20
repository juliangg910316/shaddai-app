import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento que falla en todo, como un navegador en modo privado.
class ThrowingPreferences implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('almacenamiento bloqueado');
}
