import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('pt'),
  ];

  /// El nombre de la aplicación
  ///
  /// In es, this message translates to:
  /// **'D\'Shaddai'**
  String get appTitle;

  /// No description provided for @bookAppointment.
  ///
  /// In es, this message translates to:
  /// **'Reservar Turno'**
  String get bookAppointment;

  /// No description provided for @welcomeBack.
  ///
  /// In es, this message translates to:
  /// **'Bienvenida, {name}'**
  String welcomeBack(String name);

  /// Saludo del inicio, el nombre se muestra aparte y con otro color
  ///
  /// In es, this message translates to:
  /// **'Bienvenida,'**
  String get welcomeGreeting;

  /// No description provided for @homeTab.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get homeTab;

  /// No description provided for @servicesTab.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get servicesTab;

  /// No description provided for @appointmentsTab.
  ///
  /// In es, this message translates to:
  /// **'Turnos'**
  String get appointmentsTab;

  /// No description provided for @profileTab.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTab;

  /// No description provided for @adminTab.
  ///
  /// In es, this message translates to:
  /// **'Admin'**
  String get adminTab;

  /// Nombre de respaldo cuando no hay usuario autenticado
  ///
  /// In es, this message translates to:
  /// **'Invitada'**
  String get guestFallbackName;

  /// No description provided for @brandFullName.
  ///
  /// In es, this message translates to:
  /// **'D\'Shaddai'**
  String get brandFullName;

  /// No description provided for @popularServicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Servicios populares'**
  String get popularServicesTitle;

  /// No description provided for @viewAllAction.
  ///
  /// In es, this message translates to:
  /// **'VER TODO'**
  String get viewAllAction;

  /// No description provided for @ourWorkTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuestros trabajos'**
  String get ourWorkTitle;

  /// No description provided for @salonPhotoPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'FOTO DEL SALÓN'**
  String get salonPhotoPlaceholder;

  /// No description provided for @findUsTitle.
  ///
  /// In es, this message translates to:
  /// **'Encuéntranos'**
  String get findUsTitle;

  /// No description provided for @salonName.
  ///
  /// In es, this message translates to:
  /// **'Shaddai Studio'**
  String get salonName;

  /// No description provided for @salonAddress.
  ///
  /// In es, this message translates to:
  /// **'Rua Prof. Nivaldo Braga 1108, Capão da Imbuia, Curitiba - PR'**
  String get salonAddress;

  /// No description provided for @heroTitle.
  ///
  /// In es, this message translates to:
  /// **'D\'Shaddai\nNail Salon'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuidado de lujo para tus uñas'**
  String get heroSubtitle;

  /// No description provided for @photoPlaceholderDefault.
  ///
  /// In es, this message translates to:
  /// **'FOTO'**
  String get photoPlaceholderDefault;

  /// No description provided for @serviceManicureClassicName.
  ///
  /// In es, this message translates to:
  /// **'Manicure Clásica'**
  String get serviceManicureClassicName;

  /// No description provided for @serviceManicureClassicDesc.
  ///
  /// In es, this message translates to:
  /// **'Limpieza, exfoliación, masaje y esmaltado tradicional.'**
  String get serviceManicureClassicDesc;

  /// No description provided for @serviceManicureSemipermName.
  ///
  /// In es, this message translates to:
  /// **'Manicure Semipermanente'**
  String get serviceManicureSemipermName;

  /// No description provided for @serviceManicureSemipermDesc.
  ///
  /// In es, this message translates to:
  /// **'Limpieza profunda y esmaltado de larga duración (Gel).'**
  String get serviceManicureSemipermDesc;

  /// No description provided for @serviceAcrylicSetName.
  ///
  /// In es, this message translates to:
  /// **'Set Nuevo Acrílicas'**
  String get serviceAcrylicSetName;

  /// No description provided for @serviceAcrylicSetDesc.
  ///
  /// In es, this message translates to:
  /// **'Uñas acrílicas con molde o tip, largo medio. Incluye esmaltado.'**
  String get serviceAcrylicSetDesc;

  /// No description provided for @serviceAcrylicFullName.
  ///
  /// In es, this message translates to:
  /// **'Acrílicas Full'**
  String get serviceAcrylicFullName;

  /// No description provided for @serviceAcrylicTouchupName.
  ///
  /// In es, this message translates to:
  /// **'Retoque Acrílico'**
  String get serviceAcrylicTouchupName;

  /// No description provided for @serviceAcrylicTouchupDesc.
  ///
  /// In es, this message translates to:
  /// **'Relleno de crecimiento (hasta 3 semanas).'**
  String get serviceAcrylicTouchupDesc;

  /// No description provided for @servicePedicureSpaName.
  ///
  /// In es, this message translates to:
  /// **'Pedicure Spa'**
  String get servicePedicureSpaName;

  /// No description provided for @servicePedicureSpaDesc.
  ///
  /// In es, this message translates to:
  /// **'Limpieza profunda, remoción de callosidades, exfoliación, mascarilla y esmaltado.'**
  String get servicePedicureSpaDesc;

  /// No description provided for @serviceJellyPedicureName.
  ///
  /// In es, this message translates to:
  /// **'Jelly Pedicure'**
  String get serviceJellyPedicureName;

  /// No description provided for @serviceJellyPedicureDesc.
  ///
  /// In es, this message translates to:
  /// **'Terapia de hidratación profunda con textura gelatinosa relajante.'**
  String get serviceJellyPedicureDesc;

  /// No description provided for @duration45Min.
  ///
  /// In es, this message translates to:
  /// **'45 min'**
  String get duration45Min;

  /// No description provided for @duration60Min.
  ///
  /// In es, this message translates to:
  /// **'60 min'**
  String get duration60Min;

  /// No description provided for @duration75Min.
  ///
  /// In es, this message translates to:
  /// **'75 min'**
  String get duration75Min;

  /// No description provided for @duration90Min.
  ///
  /// In es, this message translates to:
  /// **'90 min'**
  String get duration90Min;

  /// No description provided for @categoryManicure.
  ///
  /// In es, this message translates to:
  /// **'Manicure'**
  String get categoryManicure;

  /// No description provided for @categoryAcrylicGel.
  ///
  /// In es, this message translates to:
  /// **'Acrílicas & Gel'**
  String get categoryAcrylicGel;

  /// No description provided for @categoryPedicure.
  ///
  /// In es, this message translates to:
  /// **'Pedicure'**
  String get categoryPedicure;

  /// No description provided for @ourServicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuestros Servicios'**
  String get ourServicesTitle;

  /// No description provided for @servicesMenuEyebrow.
  ///
  /// In es, this message translates to:
  /// **'CARTA D\'SHADDAI'**
  String get servicesMenuEyebrow;

  /// No description provided for @bookAction.
  ///
  /// In es, this message translates to:
  /// **'RESERVAR'**
  String get bookAction;

  /// No description provided for @cancelAction.
  ///
  /// In es, this message translates to:
  /// **'CANCELAR'**
  String get cancelAction;

  /// No description provided for @confirmAction.
  ///
  /// In es, this message translates to:
  /// **'CONFIRMAR'**
  String get confirmAction;

  /// No description provided for @adminAgendaLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la agenda: {error}'**
  String adminAgendaLoadError(Object error);

  /// No description provided for @adminNoAppointmentsToday.
  ///
  /// In es, this message translates to:
  /// **'No hay reservas para este día.'**
  String get adminNoAppointmentsToday;

  /// No description provided for @adminAgendaTitle.
  ///
  /// In es, this message translates to:
  /// **'Agenda'**
  String get adminAgendaTitle;

  /// No description provided for @adminPanelEyebrow.
  ///
  /// In es, this message translates to:
  /// **'PANEL DE BEIDIS'**
  String get adminPanelEyebrow;

  /// No description provided for @adminStatAppointmentsToday.
  ///
  /// In es, this message translates to:
  /// **'TURNOS HOY'**
  String get adminStatAppointmentsToday;

  /// No description provided for @pendingConfirmationLabel.
  ///
  /// In es, this message translates to:
  /// **'POR CONFIRMAR'**
  String get pendingConfirmationLabel;

  /// No description provided for @weekdayMonday.
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get weekdaySunday;

  /// No description provided for @settingsSavedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Ajustes guardados correctamente.'**
  String get settingsSavedSuccess;

  /// No description provided for @scheduleSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Horarios'**
  String get scheduleSettingsTitle;

  /// No description provided for @closedLabel.
  ///
  /// In es, this message translates to:
  /// **'CERRADO'**
  String get closedLabel;

  /// No description provided for @openingTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Apertura (HH:MM)'**
  String get openingTimeLabel;

  /// No description provided for @closingTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Cierre (HH:MM)'**
  String get closingTimeLabel;

  /// No description provided for @adminClientsTitle.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get adminClientsTitle;

  /// No description provided for @adminClientsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los clientes: {error}'**
  String adminClientsLoadError(Object error);

  /// No description provided for @adminNoClientsRegistered.
  ///
  /// In es, this message translates to:
  /// **'No hay clientes registrados.'**
  String get adminNoClientsRegistered;

  /// No description provided for @userStatusBlocked.
  ///
  /// In es, this message translates to:
  /// **'BLOQUEADA'**
  String get userStatusBlocked;

  /// No description provided for @userStatusActive.
  ///
  /// In es, this message translates to:
  /// **'ACTIVA'**
  String get userStatusActive;

  /// No description provided for @loginTagline.
  ///
  /// In es, this message translates to:
  /// **'NAIL DESIGNER · BEIDIS VIERA'**
  String get loginTagline;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para agendar tu turno'**
  String get loginSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @completeProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Completar Perfil'**
  String get completeProfileTitle;

  /// No description provided for @completeProfileSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un último paso antes de agendar'**
  String get completeProfileSubtitle;

  /// No description provided for @whatsappFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'TU WHATSAPP'**
  String get whatsappFieldLabel;

  /// No description provided for @phoneHintExample.
  ///
  /// In es, this message translates to:
  /// **'+58 412 555 0134'**
  String get phoneHintExample;

  /// No description provided for @whatsappDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Beidis te escribe por WhatsApp para confirmar tu turno, coordinar cambios y avisarte si se libera un horario. No lo compartimos con nadie más.'**
  String get whatsappDisclaimer;

  /// No description provided for @saveAndContinueAction.
  ///
  /// In es, this message translates to:
  /// **'GUARDAR Y CONTINUAR'**
  String get saveAndContinueAction;

  /// No description provided for @confirmBookingDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Reserva'**
  String get confirmBookingDialogTitle;

  /// No description provided for @confirmBookingDialogBody.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas reservar tu turno para el día {date} a las {time}?'**
  String confirmBookingDialogBody(String date, String time);

  /// No description provided for @bookingCreatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Reserva creada exitosamente! Esperando confirmación del administrador.'**
  String get bookingCreatedSuccess;

  /// No description provided for @bookingCreateError.
  ///
  /// In es, this message translates to:
  /// **'Error al crear la reserva: {error}'**
  String bookingCreateError(Object error);

  /// No description provided for @stepServiceLabel.
  ///
  /// In es, this message translates to:
  /// **'1 · SERVICIO'**
  String get stepServiceLabel;

  /// No description provided for @stepDateLabel.
  ///
  /// In es, this message translates to:
  /// **'2 · FECHA'**
  String get stepDateLabel;

  /// No description provided for @stepTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'3 · Horario'**
  String get stepTimeLabel;

  /// No description provided for @slotsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los horarios: {error}'**
  String slotsLoadError(Object error);

  /// No description provided for @chooseTimeSlotAction.
  ///
  /// In es, this message translates to:
  /// **'ELIGE UN HORARIO'**
  String get chooseTimeSlotAction;

  /// No description provided for @confirmAtTimeAction.
  ///
  /// In es, this message translates to:
  /// **'CONFIRMAR {time}'**
  String confirmAtTimeAction(String time);

  /// No description provided for @bookingPendingNoticePrefix.
  ///
  /// In es, this message translates to:
  /// **'Tu turno quedará en '**
  String get bookingPendingNoticePrefix;

  /// No description provided for @bookingPendingNoticeHighlight.
  ///
  /// In es, this message translates to:
  /// **'Esperando confirmación'**
  String get bookingPendingNoticeHighlight;

  /// No description provided for @bookingPendingNoticeSuffix.
  ///
  /// In es, this message translates to:
  /// **' hasta que Beidis lo apruebe.'**
  String get bookingPendingNoticeSuffix;

  /// No description provided for @noSlotsAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay horarios disponibles para esta fecha.'**
  String get noSlotsAvailable;

  /// No description provided for @serviceOptionClassicChip.
  ///
  /// In es, this message translates to:
  /// **'Clásica 45m'**
  String get serviceOptionClassicChip;

  /// No description provided for @serviceOptionClassicSummary.
  ///
  /// In es, this message translates to:
  /// **'Clásica 45 min'**
  String get serviceOptionClassicSummary;

  /// No description provided for @serviceOptionSemipermChip.
  ///
  /// In es, this message translates to:
  /// **'Semiperm. 60m'**
  String get serviceOptionSemipermChip;

  /// No description provided for @serviceOptionSemipermSummary.
  ///
  /// In es, this message translates to:
  /// **'Semiperm. 60 min'**
  String get serviceOptionSemipermSummary;

  /// No description provided for @serviceOptionAcrylicChip.
  ///
  /// In es, this message translates to:
  /// **'Acrílicas 90m'**
  String get serviceOptionAcrylicChip;

  /// No description provided for @serviceOptionAcrylicSummary.
  ///
  /// In es, this message translates to:
  /// **'Acrílicas 90 min'**
  String get serviceOptionAcrylicSummary;

  /// No description provided for @myProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get myProfileTitle;

  /// No description provided for @adminPanelButtonLabel.
  ///
  /// In es, this message translates to:
  /// **'PANEL DE ADMINISTRADOR'**
  String get adminPanelButtonLabel;

  /// No description provided for @myAppointmentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis reservas'**
  String get myAppointmentsTitle;

  /// No description provided for @myAppointmentsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus reservas: {error}'**
  String myAppointmentsLoadError(Object error);

  /// No description provided for @noAppointmentsYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes reservas.'**
  String get noAppointmentsYet;

  /// No description provided for @bookAnotherAppointmentAction.
  ///
  /// In es, this message translates to:
  /// **'RESERVAR OTRO TURNO'**
  String get bookAnotherAppointmentAction;

  /// No description provided for @statusConfirmedClient.
  ///
  /// In es, this message translates to:
  /// **'CONFIRMADA'**
  String get statusConfirmedClient;

  /// No description provided for @statusCancelledClient.
  ///
  /// In es, this message translates to:
  /// **'CANCELADA'**
  String get statusCancelledClient;

  /// No description provided for @statusWaitingConfirmationClient.
  ///
  /// In es, this message translates to:
  /// **'EN REVISIÓN'**
  String get statusWaitingConfirmationClient;

  /// No description provided for @statusConfirmedAdmin.
  ///
  /// In es, this message translates to:
  /// **'CONFIRMADO'**
  String get statusConfirmedAdmin;

  /// No description provided for @statusCancelledAdmin.
  ///
  /// In es, this message translates to:
  /// **'CANCELADO'**
  String get statusCancelledAdmin;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
