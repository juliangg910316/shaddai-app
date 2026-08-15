// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'D\'Shaddai';

  @override
  String get bookAppointment => 'Agendar Horário';

  @override
  String welcomeBack(String name) {
    return 'Bem-vinda, $name';
  }

  @override
  String get homeTab => 'Início';

  @override
  String get servicesTab => 'Serviços';

  @override
  String get appointmentsTab => 'Horários';

  @override
  String get profileTab => 'Perfil';

  @override
  String get adminTab => 'Admin';
}
