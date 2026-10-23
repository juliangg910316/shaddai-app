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

  /// No description provided for @bookAppointment.
  ///
  /// In es, this message translates to:
  /// **'Reservar Turno'**
  String get bookAppointment;

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

  /// No description provided for @brandFullName.
  ///
  /// In es, this message translates to:
  /// **'Studio Shaddai'**
  String get brandFullName;

  /// No description provided for @brandLogoLabel.
  ///
  /// In es, this message translates to:
  /// **'Logotipo de Studio Shaddai'**
  String get brandLogoLabel;

  /// No description provided for @photoPlaceholderDefault.
  ///
  /// In es, this message translates to:
  /// **'FOTO'**
  String get photoPlaceholderDefault;

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
  /// **'No pudimos cargar la agenda. Inténtalo de nuevo.'**
  String get adminAgendaLoadError;

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
  /// **'No pudimos cargar los clientes. Inténtalo de nuevo.'**
  String get adminClientsLoadError;

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
  /// **'No pudimos crear la reserva. Inténtalo de nuevo.'**
  String get bookingCreateError;

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
  /// **'No pudimos cargar los horarios. Inténtalo de nuevo.'**
  String get slotsLoadError;

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
  /// **'No pudimos cargar tus reservas. Inténtalo de nuevo.'**
  String get myAppointmentsLoadError;

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

  /// No description provided for @preferencesTitle.
  ///
  /// In es, this message translates to:
  /// **'Preferencias'**
  String get preferencesTitle;

  /// No description provided for @themeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get themeLabel;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeMenuTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar tema'**
  String get themeMenuTooltip;

  /// No description provided for @languageLabel.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get languageLabel;

  /// Nombre del idioma en su propio idioma, igual en todas las traducciones
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Nombre del idioma en su propio idioma, igual en todas las traducciones
  ///
  /// In es, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// Código del idioma en el selector de Web
  ///
  /// In es, this message translates to:
  /// **'ES'**
  String get languageCodeEs;

  /// Código del idioma en el selector de Web
  ///
  /// In es, this message translates to:
  /// **'PT'**
  String get languageCodePt;

  /// No description provided for @languageSwitchLabel.
  ///
  /// In es, this message translates to:
  /// **'Cambiar idioma'**
  String get languageSwitchLabel;

  /// Lo que anuncia el lector de pantalla en la opción activa
  ///
  /// In es, this message translates to:
  /// **'Seleccionado'**
  String get selectedOption;

  /// No description provided for @profileGuestTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestLoginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get profileGuestLoginButton;

  /// No description provided for @authBlockedError.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está bloqueada. Escríbenos por WhatsApp si crees que es un error.'**
  String get authBlockedError;

  /// No description provided for @authGenericError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos iniciar sesión. Inténtalo de nuevo.'**
  String get authGenericError;

  /// No description provided for @loginAppBarTitle.
  ///
  /// In es, this message translates to:
  /// **'Autenticación'**
  String get loginAppBarTitle;

  /// Enlace de la barra superior de Web a la lista de precios
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get webNavServices;

  /// Enlace de la barra superior de Web al catálogo
  ///
  /// In es, this message translates to:
  /// **'Catálogo'**
  String get webNavCatalog;

  /// Enlace de la barra superior de Web a la sección Sobre mí
  ///
  /// In es, this message translates to:
  /// **'Sobre mí'**
  String get webNavAbout;

  /// Botón de la barra superior de Web que lleva a la reserva
  ///
  /// In es, this message translates to:
  /// **'Reservar'**
  String get webNavReserve;

  /// Botón del menú lateral en ancho estrecho
  ///
  /// In es, this message translates to:
  /// **'Abrir menú'**
  String get webMenuOpenLabel;

  /// Botón para cerrar el menú lateral
  ///
  /// In es, this message translates to:
  /// **'Cerrar menú'**
  String get webMenuCloseLabel;

  /// Etiqueta del logotipo de la barra superior para lectores de pantalla
  ///
  /// In es, this message translates to:
  /// **'Studio Shaddai, ir al inicio'**
  String get webHomeLinkLabel;

  /// Botón de cuenta de Web sin sesión
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get accountSignIn;

  /// Etiqueta del botón de cuenta de Web con sesión
  ///
  /// In es, this message translates to:
  /// **'Menú de cuenta'**
  String get accountMenuLabel;

  /// Opción del menú de cuenta que lleva al perfil
  ///
  /// In es, this message translates to:
  /// **'Mis turnos'**
  String get accountMyAppointments;

  /// Opción del menú de cuenta, solo para admin
  ///
  /// In es, this message translates to:
  /// **'Panel de administración'**
  String get accountAdminPanel;

  /// Opción del menú de cuenta que cierra la sesión
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get accountSignOut;

  /// Título del diálogo de Web tras crear una reserva
  ///
  /// In es, this message translates to:
  /// **'Reserva creada'**
  String get bookingCreatedWebTitle;

  /// Botón del diálogo de reserva creada que lleva a la landing
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get bookingBackToLanding;

  /// Título de la pestaña del navegador y de la app
  ///
  /// In es, this message translates to:
  /// **'Studio Shaddai · Nail Designer'**
  String get webAppTitle;

  /// No description provided for @landingHeroKicker.
  ///
  /// In es, this message translates to:
  /// **'Nail Designer · Capão da Imbuia, Curitiba'**
  String get landingHeroKicker;

  /// No description provided for @landingHeroScript.
  ///
  /// In es, this message translates to:
  /// **'Un tiempo para ti.'**
  String get landingHeroScript;

  /// No description provided for @landingHeroTitleLine1.
  ///
  /// In es, this message translates to:
  /// **'Más que uñas,'**
  String get landingHeroTitleLine1;

  /// No description provided for @landingHeroTitleLine2Em.
  ///
  /// In es, this message translates to:
  /// **'momentos de bienestar.'**
  String get landingHeroTitleLine2Em;

  /// No description provided for @landingHeroDesc.
  ///
  /// In es, this message translates to:
  /// **'Manicura, pedicura, alargamientos, esmaltado en gel y spa en un estudio privado, con hora reservada y atención en español y portugués.'**
  String get landingHeroDesc;

  /// No description provided for @landingHeroCtaReserve.
  ///
  /// In es, this message translates to:
  /// **'Reservar cita'**
  String get landingHeroCtaReserve;

  /// No description provided for @landingHeroCtaPrices.
  ///
  /// In es, this message translates to:
  /// **'Ver lista de precios'**
  String get landingHeroCtaPrices;

  /// No description provided for @landingHeroStatServicesLabel.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get landingHeroStatServicesLabel;

  /// No description provided for @landingHeroStatFollowersLabel.
  ///
  /// In es, this message translates to:
  /// **'Seguidoras'**
  String get landingHeroStatFollowersLabel;

  /// No description provided for @landingHeroStatNoticeLabel.
  ///
  /// In es, this message translates to:
  /// **'Aviso p/ cambios'**
  String get landingHeroStatNoticeLabel;

  /// No description provided for @landingHeroAddressLabel.
  ///
  /// In es, this message translates to:
  /// **'Estudio privado · Curitiba'**
  String get landingHeroAddressLabel;

  /// No description provided for @landingHeroAddressCta.
  ///
  /// In es, this message translates to:
  /// **'Mapa →'**
  String get landingHeroAddressCta;

  /// No description provided for @landingHeroBadgeLine1.
  ///
  /// In es, this message translates to:
  /// **'Francesa'**
  String get landingHeroBadgeLine1;

  /// No description provided for @landingHeroBadgeLine2.
  ///
  /// In es, this message translates to:
  /// **'gratis'**
  String get landingHeroBadgeLine2;

  /// No description provided for @landingHeroImageAlt.
  ///
  /// In es, this message translates to:
  /// **'Beidis Viera – Studio Shaddai Nail Designer'**
  String get landingHeroImageAlt;

  /// No description provided for @landingMarqueeGelPolish.
  ///
  /// In es, this message translates to:
  /// **'Esmaltado en gel'**
  String get landingMarqueeGelPolish;

  /// No description provided for @landingMarqueeSpaMore.
  ///
  /// In es, this message translates to:
  /// **'Spa y más'**
  String get landingMarqueeSpaMore;

  /// No description provided for @landingMarqueeManicure.
  ///
  /// In es, this message translates to:
  /// **'Manicura'**
  String get landingMarqueeManicure;

  /// No description provided for @landingMarqueePedicure.
  ///
  /// In es, this message translates to:
  /// **'Pedicura'**
  String get landingMarqueePedicure;

  /// No description provided for @landingMarqueeExtensions.
  ///
  /// In es, this message translates to:
  /// **'Alargamientos'**
  String get landingMarqueeExtensions;

  /// No description provided for @landingServicesEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Lista de precios'**
  String get landingServicesEyebrow;

  /// No description provided for @landingServicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Todos los'**
  String get landingServicesTitle;

  /// No description provided for @landingServicesTitleEm.
  ///
  /// In es, this message translates to:
  /// **'servicios'**
  String get landingServicesTitleEm;

  /// No description provided for @landingServicesNote.
  ///
  /// In es, this message translates to:
  /// **'Precios en reales. Cada cita empieza con el diagnóstico de tus uñas: duración y acabado los decidimos juntas.'**
  String get landingServicesNote;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Manos'**
  String get landingServices1Title;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Cuidado y elegancia siempre'**
  String get landingServices1Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Manicure tradicional'**
  String get landingServices1Row1;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Spa de manos'**
  String get landingServices1Row2;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Esmaltado en gel · manos'**
  String get landingServices1Row3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Baño de gel (corto a medio)'**
  String get landingServices1Row4;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Baño de gel (largo)'**
  String get landingServices1Row5;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'El baño de gel incluye preparación, cutículas, esmaltado en gel de un color y decoración simple.'**
  String get landingServices1Note;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Pies'**
  String get landingServices2Title;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Confort y bienestar'**
  String get landingServices2Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Pedicura tradicional'**
  String get landingServices2Row1;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Pedicura + Mini Spa'**
  String get landingServices2Row2;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Pedicura Spa'**
  String get landingServices2Row3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Plástica de pies + Pedicura'**
  String get landingServices2Row4;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Esmaltado en gel · pies'**
  String get landingServices2Row5;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Mini Spa: cuidado localizado de callosidades. Spa: exfoliación, hidratación y cuidado completo de los pies.'**
  String get landingServices2Note;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Alargamientos'**
  String get landingServices3Title;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Gel, Polygel y Acrílico'**
  String get landingServices3Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Nueva aplicación'**
  String get landingServices3GroupNew;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento'**
  String get landingServices3GroupMaintenance;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Corto'**
  String get landingServices3RowShort;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Medio'**
  String get landingServices3RowMedium;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Largo'**
  String get landingServices3RowLong;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Extra largo'**
  String get landingServices3RowExtraLong;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Mismo precio por técnica; solo varía el largo. El precio base incluye preparación, cutículas, estructura, esmaltado en gel de un color y decoración simple en 1 uña. Mantenimiento hasta 30 días.'**
  String get landingServices3Note;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Practicidad y ligereza'**
  String get landingServices4Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Corto / Medio'**
  String get landingServices4Row1;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Largo'**
  String get landingServices4Row2;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento / reaplicación · desde'**
  String get landingServices4Row3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento según el crecimiento y el estado de la estructura.'**
  String get landingServices4Note;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Retiradas'**
  String get landingServices5Title;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Salud de la uña primero'**
  String get landingServices5Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Esmaltado en gel'**
  String get landingServices5Row1;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Baño de gel'**
  String get landingServices5Row2;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Alargamiento'**
  String get landingServices5Row3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Retirada + nueva aplicación en la misma cita: R\$ 30.'**
  String get landingServices5Note;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Decoración y adicionales'**
  String get landingServices6Title;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Detalles que marcan la diferencia'**
  String get landingServices6Subtitle;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Francesa elaborada'**
  String get landingServices6Row1;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Cromado / ojo de gato'**
  String get landingServices6Row2;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Encapsulado'**
  String get landingServices6Row3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Nail art simple'**
  String get landingServices6Row4;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Nail art intermedia'**
  String get landingServices6Row5;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Nail art elaborada'**
  String get landingServices6Row6;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Pedrería'**
  String get landingServices6Row7;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Adhesivos, composiciones con varias técnicas y diseños personalizados se valoran según cantidad de uñas, dificultad y tiempo.'**
  String get landingServices6Note;

  /// No description provided for @landingCombosEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Ventajas'**
  String get landingCombosEyebrow;

  /// No description provided for @landingCombosNote.
  ///
  /// In es, this message translates to:
  /// **'Los combos no son acumulables con otras promociones.'**
  String get landingCombosNote;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Manos y Pies Tradicional'**
  String get landingCombo1Name;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Manicura tradicional + Pedicura tradicional'**
  String get landingCombo1Desc;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Gel Completo'**
  String get landingCombo2Name;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Esmaltado en gel manos + pies'**
  String get landingCombo2Desc;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Momento Shaddai'**
  String get landingCombo3Name;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Manicura + Spa de manos + Pedicura Spa'**
  String get landingCombo3Desc;

  /// No description provided for @landingCatalogEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Material del estudio'**
  String get landingCatalogEyebrow;

  /// No description provided for @landingCatalogTitle.
  ///
  /// In es, this message translates to:
  /// **'Catálogo de'**
  String get landingCatalogTitle;

  /// No description provided for @landingCatalogTitleEm.
  ///
  /// In es, this message translates to:
  /// **'servicios'**
  String get landingCatalogTitleEm;

  /// No description provided for @landingCatalogNote.
  ///
  /// In es, this message translates to:
  /// **'Toca para ampliar cada página del catálogo.'**
  String get landingCatalogNote;

  /// No description provided for @landingCatalogAltPortada.
  ///
  /// In es, this message translates to:
  /// **'Studio Shaddai — Catálogo de servicios'**
  String get landingCatalogAltPortada;

  /// No description provided for @landingCatalogAltAlongamentos.
  ///
  /// In es, this message translates to:
  /// **'Alargamientos'**
  String get landingCatalogAltAlongamentos;

  /// No description provided for @landingCatalogAltSoftGel.
  ///
  /// In es, this message translates to:
  /// **'Soft Gel'**
  String get landingCatalogAltSoftGel;

  /// No description provided for @landingCatalogAltManutencion.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento de uñas'**
  String get landingCatalogAltManutencion;

  /// No description provided for @landingCatalogAltDecoraciones.
  ///
  /// In es, this message translates to:
  /// **'Decoraciones para uñas'**
  String get landingCatalogAltDecoraciones;

  /// No description provided for @landingCatalogAltCombos.
  ///
  /// In es, this message translates to:
  /// **'Combos y paquetes especiales'**
  String get landingCatalogAltCombos;

  /// No description provided for @landingCatalogAltNaturales.
  ///
  /// In es, this message translates to:
  /// **'Uñas naturales'**
  String get landingCatalogAltNaturales;

  /// No description provided for @landingCatalogAltPies.
  ///
  /// In es, this message translates to:
  /// **'Pies y cuidados especiales'**
  String get landingCatalogAltPies;

  /// No description provided for @landingCatalogAltAgendamiento.
  ///
  /// In es, this message translates to:
  /// **'Agendamiento de citas'**
  String get landingCatalogAltAgendamiento;

  /// No description provided for @landingCatalogMoreCta.
  ///
  /// In es, this message translates to:
  /// **'Más páginas del catálogo en Instagram'**
  String get landingCatalogMoreCta;

  /// No description provided for @landingInfoEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Información importante'**
  String get landingInfoEyebrow;

  /// No description provided for @landingInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo funciona la'**
  String get landingInfoTitle;

  /// No description provided for @landingInfoTitleEm.
  ///
  /// In es, this message translates to:
  /// **'atención'**
  String get landingInfoTitleEm;

  /// No description provided for @landingInfoDesc.
  ///
  /// In es, this message translates to:
  /// **'Reglas simples para cuidar la estructura de tus uñas — y tu hora reservada.'**
  String get landingInfoDesc;

  /// No description provided for @landingInfoScript.
  ///
  /// In es, this message translates to:
  /// **'Tu tiempo también importa ♡'**
  String get landingInfoScript;

  /// No description provided for @landingInfo1Title.
  ///
  /// In es, this message translates to:
  /// **'Reposición'**
  String get landingInfo1Title;

  /// No description provided for @landingInfo1Body.
  ///
  /// In es, this message translates to:
  /// **'1 uña durante el mantenimiento: incluida. A partir de la 2ª uña: R\$ 5 cada una. Fuera del mantenimiento: R\$ 15.'**
  String get landingInfo1Body;

  /// No description provided for @landingInfo2Title.
  ///
  /// In es, this message translates to:
  /// **'Plazo de mantenimiento'**
  String get landingInfo2Title;

  /// No description provided for @landingInfo2Body.
  ///
  /// In es, this message translates to:
  /// **'Los mantenimientos se realizan hasta 30 días. Pasado ese plazo, el servicio puede considerarse nueva aplicación según el crecimiento, desprendimientos y estado de la estructura.'**
  String get landingInfo2Body;

  /// No description provided for @landingInfo3Title.
  ///
  /// In es, this message translates to:
  /// **'Retrasos'**
  String get landingInfo3Title;

  /// No description provided for @landingInfo3Body.
  ///
  /// In es, this message translates to:
  /// **'Tolerancia de 10 minutos. Después, la cita puede adaptarse o reprogramarse para no afectar los horarios siguientes.'**
  String get landingInfo3Body;

  /// No description provided for @landingInfo4Title.
  ///
  /// In es, this message translates to:
  /// **'Cancelaciones'**
  String get landingInfo4Title;

  /// No description provided for @landingInfo4Body.
  ///
  /// In es, this message translates to:
  /// **'Cancelaciones o cambios de horario: avisar con al menos 24 horas de antelación. Atención siempre con hora reservada.'**
  String get landingInfo4Body;

  /// No description provided for @landingGalleryEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Mi trabajo'**
  String get landingGalleryEyebrow;

  /// No description provided for @landingGalleryTitle.
  ///
  /// In es, this message translates to:
  /// **'Galería de'**
  String get landingGalleryTitle;

  /// No description provided for @landingGalleryTitleEm.
  ///
  /// In es, this message translates to:
  /// **'diseños'**
  String get landingGalleryTitleEm;

  /// No description provided for @landingGalleryMoreLink.
  ///
  /// In es, this message translates to:
  /// **'Ver más en Instagram →'**
  String get landingGalleryMoreLink;

  /// Etiqueta de accesibilidad para cada foto de la galería
  ///
  /// In es, this message translates to:
  /// **'Diseño {n} — ver más en Instagram'**
  String landingGalleryItemLabel(int n);

  /// No description provided for @landingAboutQuoteLabel.
  ///
  /// In es, this message translates to:
  /// **'En sus palabras'**
  String get landingAboutQuoteLabel;

  /// No description provided for @landingAboutQuote.
  ///
  /// In es, this message translates to:
  /// **'“La belleza también es cuidarte a ti.”'**
  String get landingAboutQuote;

  /// No description provided for @landingAboutEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Mi historia'**
  String get landingAboutEyebrow;

  /// No description provided for @landingAboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Soy'**
  String get landingAboutTitle;

  /// No description provided for @landingAboutParagraph1.
  ///
  /// In es, this message translates to:
  /// **'Nail designer y apasionada de la belleza. Detrás de Studio Shaddai hay una mujer que sigue aprendiendo, soñando y creciendo cada día.'**
  String get landingAboutParagraph1;

  /// No description provided for @landingAboutParagraph2.
  ///
  /// In es, this message translates to:
  /// **'Las redes muestran el resultado final, pero detrás de cada diseño hay preparación, técnica y pasión por el detalle. Para mí, cada uña es una oportunidad de crear algo bello que también cuide la salud de tus manos.'**
  String get landingAboutParagraph2;

  /// No description provided for @landingAboutValue1.
  ///
  /// In es, this message translates to:
  /// **'Técnica con fundamento, no solo tendencia'**
  String get landingAboutValue1;

  /// No description provided for @landingAboutValue2.
  ///
  /// In es, this message translates to:
  /// **'Salud de la uña primero, siempre'**
  String get landingAboutValue2;

  /// No description provided for @landingAboutValue3.
  ///
  /// In es, this message translates to:
  /// **'Espacio higienizado, trabajo impecable'**
  String get landingAboutValue3;

  /// No description provided for @landingAboutValue4.
  ///
  /// In es, this message translates to:
  /// **'Atención en español y portugués'**
  String get landingAboutValue4;

  /// No description provided for @landingContactEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Hablemos'**
  String get landingContactEyebrow;

  /// No description provided for @landingContactTitle.
  ///
  /// In es, this message translates to:
  /// **'Reserva tu'**
  String get landingContactTitle;

  /// No description provided for @landingContactTitleEm.
  ///
  /// In es, this message translates to:
  /// **'cita'**
  String get landingContactTitleEm;

  /// No description provided for @landingContactDesc.
  ///
  /// In es, this message translates to:
  /// **'¿Lista para tener las uñas que siempre quisiste? Escríbeme y encontramos el momento perfecto para ti.'**
  String get landingContactDesc;

  /// No description provided for @landingContactCtaWhatsapp.
  ///
  /// In es, this message translates to:
  /// **'Agenda por WhatsApp ♡'**
  String get landingContactCtaWhatsapp;

  /// No description provided for @landingContactPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get landingContactPhoneLabel;

  /// No description provided for @landingContactEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get landingContactEmailLabel;

  /// No description provided for @landingContactAddressLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get landingContactAddressLabel;

  /// No description provided for @landingContactInstagramLabel.
  ///
  /// In es, this message translates to:
  /// **'Instagram'**
  String get landingContactInstagramLabel;

  /// No description provided for @landingFooterTagline.
  ///
  /// In es, this message translates to:
  /// **'La belleza también es cuidarte ♡'**
  String get landingFooterTagline;

  /// No description provided for @landingWhatsappFloatTitle.
  ///
  /// In es, this message translates to:
  /// **'Reservar por WhatsApp'**
  String get landingWhatsappFloatTitle;

  /// Nombre de la técnica; no se traduce
  ///
  /// In es, this message translates to:
  /// **'Soft Gel'**
  String get landingSoftGelTitle;

  /// No description provided for @landingCombosTitle.
  ///
  /// In es, this message translates to:
  /// **'Combos'**
  String get landingCombosTitle;

  /// No description provided for @landingCombosTitleEm.
  ///
  /// In es, this message translates to:
  /// **'Shaddai'**
  String get landingCombosTitleEm;

  /// Tercera línea de la insignia del hero; en shaddai-web estaba en el código
  ///
  /// In es, this message translates to:
  /// **'1ª visita ♡'**
  String get landingHeroBadgeLine3;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Baby boomer'**
  String get landingServices6RowBabyBoomer;

  /// Solo para la carga inicial de la lista de precios (spec 004)
  ///
  /// In es, this message translates to:
  /// **'Reversa'**
  String get landingServices6RowReversa;

  /// Nombre accesible del mapa incrustado del contacto en Android/iOS
  ///
  /// In es, this message translates to:
  /// **'Mapa con la ubicación del estudio'**
  String get salonMapLabel;

  /// Título del aviso de la pestaña Reservas sin sesión (Android/iOS)
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para reservar'**
  String get bookingSignInTitle;

  /// Texto del aviso de la pestaña Reservas sin sesión
  ///
  /// In es, this message translates to:
  /// **'Usamos tu cuenta de Google para guardar tus turnos y que Beidis pueda confirmarlos por WhatsApp.'**
  String get bookingSignInBody;

  /// Etiqueta para el lector de pantalla del indicador de carga de la lista de precios (spec 004, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Cargando precios'**
  String get pricesLoading;

  /// Aviso cuando la lista de precios no se puede cargar (RF-8)
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los precios.'**
  String get pricesLoadError;

  /// Botón para volver a cargar la lista de precios (RF-9)
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get pricesRetry;

  /// Aviso cuando no hay ninguna categoría que mostrar (RF-10)
  ///
  /// In es, this message translates to:
  /// **'Consulta los precios por WhatsApp.'**
  String get pricesEmpty;

  /// Precio «desde» de un servicio
  ///
  /// In es, this message translates to:
  /// **'desde {price}'**
  String priceFrom(String price);

  /// Pista del lector de pantalla en cada servicio y combo de la lista (RNF-5)
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get priceDetailOpenHint;

  /// Lo que anuncia el lector de pantalla en cada servicio y combo de la lista (RNF-5)
  ///
  /// In es, this message translates to:
  /// **'{name}, {price}'**
  String priceLineSemantics(String name, String price);

  /// Aviso bajo el catálogo: sus páginas son imágenes fijas (spec 004, RF-42)
  ///
  /// In es, this message translates to:
  /// **'Los precios vigentes son los de la lista de precios.'**
  String get pricesCatalogDisclaimer;

  /// Etiqueta de la duración en el detalle de un servicio o combo (spec 004, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get priceDetailDuration;

  /// Botón del detalle que vuelve a la lista de precios (RF-17, RF-44)
  ///
  /// In es, this message translates to:
  /// **'Volver a la lista de precios'**
  String get priceDetailBackToPrices;

  /// Aviso del detalle de un servicio o combo borrado, oculto o que no existe (RF-17)
  ///
  /// In es, this message translates to:
  /// **'Este servicio ya no está disponible.'**
  String get priceDetailUnavailable;

  /// Título de la gestión de servicios y precios de la admin, y tooltip de su icono en el panel (spec 004, RF-19)
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get adminServicesTitle;

  /// Gestión de servicios sin ningún elemento guardado (RF-35)
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay servicios.'**
  String get adminServicesEmpty;

  /// Botón de la carga inicial de la lista de precios (RF-35)
  ///
  /// In es, this message translates to:
  /// **'Cargar la lista de precios actual'**
  String get adminServicesSeed;

  /// Título de la confirmación de la carga inicial (RF-36)
  ///
  /// In es, this message translates to:
  /// **'¿Cargar la lista de precios actual?'**
  String get adminServicesSeedConfirmTitle;

  /// Texto de la confirmación de la carga inicial (RF-36)
  ///
  /// In es, this message translates to:
  /// **'Se crearán las categorías, servicios y combos de hoy. Después podrás editarlos.'**
  String get adminServicesSeedConfirmBody;

  /// Botón que confirma la carga inicial (RF-36)
  ///
  /// In es, this message translates to:
  /// **'Cargar'**
  String get adminServicesSeedConfirmAction;

  /// Título de la lista de combos en la gestión de servicios
  ///
  /// In es, this message translates to:
  /// **'Combos'**
  String get adminServicesCombos;

  /// Aviso breve tras guardar un cambio en la gestión de servicios (RF-34)
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados'**
  String get adminServicesSaved;

  /// Aviso cuando un cambio de la gestión de servicios no se puede guardar (RF-33)
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar los cambios.'**
  String get adminServicesSaveError;

  /// Etiqueta de un elemento oculto en la gestión de servicios (RF-20)
  ///
  /// In es, this message translates to:
  /// **'Oculto'**
  String get adminServicesHidden;

  /// Tooltip del botón que sube un elemento en la gestión de servicios (RF-26)
  ///
  /// In es, this message translates to:
  /// **'Subir'**
  String get adminServicesMoveUp;

  /// Tooltip del botón que baja un elemento en la gestión de servicios (RF-26)
  ///
  /// In es, this message translates to:
  /// **'Bajar'**
  String get adminServicesMoveDown;

  /// Tooltip del botón que oculta un elemento de la lista de precios (RF-27)
  ///
  /// In es, this message translates to:
  /// **'Ocultar'**
  String get adminServicesHide;

  /// Tooltip del botón que vuelve a mostrar un elemento oculto (RF-27)
  ///
  /// In es, this message translates to:
  /// **'Mostrar'**
  String get adminServicesShow;

  /// Tooltip del botón de borrar un elemento, y botón que confirma el borrado (RF-29, RF-31)
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get adminServicesDelete;

  /// Título de la confirmación de borrado; {name} es el nombre del elemento en el idioma activo (RF-29, RF-31)
  ///
  /// In es, this message translates to:
  /// **'¿Borrar «{name}»?'**
  String adminServicesDeleteTitle(String name);

  /// Texto de la confirmación de borrado (RF-29, RF-31)
  ///
  /// In es, this message translates to:
  /// **'No se puede deshacer.'**
  String get adminServicesDeleteBody;

  /// Diálogo informativo al intentar borrar una categoría con elementos (RF-30)
  ///
  /// In es, this message translates to:
  /// **'Esta categoría tiene servicios o adicionales. Bórralos o muévelos a otra categoría antes de borrarla.'**
  String get adminServicesCategoryNotEmpty;

  /// Botón que cierra el diálogo informativo de una categoría con elementos (RF-30)
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get adminServicesUnderstood;

  /// Aviso cuando otra admin ya borró el elemento que se quiere cambiar
  ///
  /// In es, this message translates to:
  /// **'Este elemento ya no existe.'**
  String get adminServicesItemGone;

  /// Tooltip del botón que abre el formulario de un elemento (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get adminServicesEdit;

  /// Botón de la gestión que abre el formulario de una categoría nueva (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Añadir categoría'**
  String get adminServicesAddCategory;

  /// Título del formulario de una categoría nueva
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get adminServicesNewCategory;

  /// Título del formulario de una categoría existente
  ///
  /// In es, this message translates to:
  /// **'Editar categoría'**
  String get adminServicesEditCategory;

  /// Campo del nombre en español de un formulario de la gestión (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Nombre en español'**
  String get adminFieldNameEs;

  /// Campo del nombre en portugués (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Nombre en portugués'**
  String get adminFieldNamePt;

  /// Campo del subtítulo de una categoría en español (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Subtítulo en español'**
  String get adminFieldSubtitleEs;

  /// Campo del subtítulo de una categoría en portugués (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Subtítulo en portugués'**
  String get adminFieldSubtitlePt;

  /// Campo de la nota de una categoría en español (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Nota en español'**
  String get adminFieldNoteEs;

  /// Campo de la nota de una categoría en portugués (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Nota en portugués'**
  String get adminFieldNotePt;

  /// Error de un nombre que falta en un idioma (RF-22)
  ///
  /// In es, this message translates to:
  /// **'Obligatorio'**
  String get adminFieldRequired;

  /// Error de un texto opcional escrito solo en el otro idioma (RF-23)
  ///
  /// In es, this message translates to:
  /// **'Escríbelo también en este idioma'**
  String get adminFieldMissingTranslation;

  /// Error del precio (RF-24)
  ///
  /// In es, this message translates to:
  /// **'Precio no válido (hasta 2 decimales)'**
  String get adminFieldInvalidPrice;

  /// Error de la duración (RF-25)
  ///
  /// In es, this message translates to:
  /// **'Entre 5 y 480 minutos'**
  String get adminFieldInvalidDuration;

  /// Error de un texto demasiado largo; {max} es la longitud máxima
  ///
  /// In es, this message translates to:
  /// **'Máximo {max} caracteres'**
  String adminFieldTooLong(int max);

  /// Botón que guarda un formulario de la gestión; se muestra en mayúsculas
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get adminSave;

  /// Botón de cada categoría que abre el formulario de un servicio nuevo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Añadir servicio'**
  String get adminServicesAddService;

  /// Botón de cada categoría que abre el formulario de un adicional nuevo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Añadir adicional'**
  String get adminServicesAddAddon;

  /// Título del formulario de un servicio nuevo
  ///
  /// In es, this message translates to:
  /// **'Nuevo servicio'**
  String get adminServicesNewService;

  /// Título del formulario de un servicio existente
  ///
  /// In es, this message translates to:
  /// **'Editar servicio'**
  String get adminServicesEditService;

  /// Título del formulario de un adicional nuevo
  ///
  /// In es, this message translates to:
  /// **'Nuevo adicional'**
  String get adminServicesNewAddon;

  /// Título del formulario de un adicional existente
  ///
  /// In es, this message translates to:
  /// **'Editar adicional'**
  String get adminServicesEditAddon;

  /// Campo de la descripción en español de un servicio o combo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Descripción en español'**
  String get adminFieldDescriptionEs;

  /// Campo de la descripción en portugués de un servicio o combo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Descripción en portugués'**
  String get adminFieldDescriptionPt;

  /// Campo del grupo de un servicio en español; vacío = sin grupo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Grupo en español'**
  String get adminFieldGroupEs;

  /// Campo del grupo de un servicio en portugués (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Grupo en portugués'**
  String get adminFieldGroupPt;

  /// Campo del precio en reales (RF-24)
  ///
  /// In es, this message translates to:
  /// **'Precio (R\$)'**
  String get adminFieldPrice;

  /// Casilla del servicio cuyo precio es «desde» (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Precio «desde»'**
  String get adminFieldPriceFrom;

  /// Campo de la duración en minutos de un servicio o combo (RF-25)
  ///
  /// In es, this message translates to:
  /// **'Duración (minutos)'**
  String get adminFieldDuration;

  /// Desplegable de la categoría de un servicio o adicional (RF-32)
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get adminFieldCategory;

  /// Botón de la gestión que abre el formulario de un combo nuevo (RF-21)
  ///
  /// In es, this message translates to:
  /// **'Añadir combo'**
  String get adminServicesAddCombo;

  /// Título del formulario de un combo nuevo
  ///
  /// In es, this message translates to:
  /// **'Nuevo combo'**
  String get adminServicesNewCombo;

  /// Título del formulario de un combo existente
  ///
  /// In es, this message translates to:
  /// **'Editar combo'**
  String get adminServicesEditCombo;
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
