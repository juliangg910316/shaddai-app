// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'D\'Shaddai';

  @override
  String get bookAppointment => 'Reservar Turno';

  @override
  String welcomeBack(String name) {
    return 'Bienvenida, $name';
  }

  @override
  String get homeTab => 'Inicio';

  @override
  String get servicesTab => 'Servicios';

  @override
  String get appointmentsTab => 'Turnos';

  @override
  String get profileTab => 'Perfil';

  @override
  String get adminTab => 'Admin';
}
