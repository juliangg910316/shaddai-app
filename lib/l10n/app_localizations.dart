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
  /// **'TURNOS DEL DÍA'**
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

  /// No description provided for @myAppointmentsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus reservas. Inténtalo de nuevo.'**
  String get myAppointmentsLoadError;

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

  /// Título del paso de la fecha en la reserva (spec 005, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get bookingStepDate;

  /// Título del paso de la hora (RF-4)
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get bookingStepTime;

  /// Título del paso del servicio o combo (RF-10)
  ///
  /// In es, this message translates to:
  /// **'Servicio'**
  String get bookingStepService;

  /// Título del paso de los adicionales (RF-18)
  ///
  /// In es, this message translates to:
  /// **'Adicionales'**
  String get bookingStepAddons;

  /// Título del resumen de lo elegido (RF-22)
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get bookingStepSummary;

  /// Nota cuando el dispositivo no está en la zona del salón (RF-5)
  ///
  /// In es, this message translates to:
  /// **'Horas de Curitiba'**
  String get bookingSalonTimeNote;

  /// Sin días seleccionables en la ventana (RF-3)
  ///
  /// In es, this message translates to:
  /// **'No hay fechas disponibles para reservar. Escríbenos por WhatsApp.'**
  String get bookingNoDaysAvailable;

  /// Día elegido sin horas libres (RF-7)
  ///
  /// In es, this message translates to:
  /// **'No quedan horas libres este día. Prueba otra fecha.'**
  String get bookingNoFreeSlots;

  /// Se tocó un servicio que no cabe en la hora elegida (RF-13)
  ///
  /// In es, this message translates to:
  /// **'Este servicio dura {duration}: elige una hora con más tiempo libre.'**
  String bookingServiceNeedsLongerSlot(String duration);

  /// Se tocó una hora en la que no cabe el servicio elegido (RF-15)
  ///
  /// In es, this message translates to:
  /// **'No hay tiempo suficiente a esta hora para un servicio de {duration}.'**
  String bookingSlotTooShortFor(String duration);

  /// La hora elegida dejó de ser libre (RF-9)
  ///
  /// In es, this message translates to:
  /// **'La hora elegida ya no está disponible. Elige otra.'**
  String get bookingSlotGone;

  /// El servicio ya no cabe en la hora elegida (RF-16)
  ///
  /// In es, this message translates to:
  /// **'La hora elegida ya no tiene tiempo suficiente para el servicio. Elige otra.'**
  String get bookingSlotNoLongerFits;

  /// El servicio elegido ya no se ofrece (RF-17, RF-44)
  ///
  /// In es, this message translates to:
  /// **'El servicio elegido ya no está disponible.'**
  String get bookingItemUnavailable;

  /// La fecha elegida dejó de poder elegirse (casos límite)
  ///
  /// In es, this message translates to:
  /// **'La fecha elegida ya no se puede reservar: te mostramos la siguiente disponible.'**
  String get bookingDateMoved;

  /// Lo que anuncia el lector de pantalla en una opción que no se puede elegir (D-11)
  ///
  /// In es, this message translates to:
  /// **'no disponible'**
  String get bookingUnavailableLabel;

  /// Falta la hora para agendar (RF-24)
  ///
  /// In es, this message translates to:
  /// **'Elige una hora'**
  String get bookingMissingSlot;

  /// Falta el servicio para agendar (RF-24)
  ///
  /// In es, this message translates to:
  /// **'Elige un servicio'**
  String get bookingMissingService;

  /// Faltan la hora y el servicio (RF-24)
  ///
  /// In es, this message translates to:
  /// **'Elige una hora y un servicio para agendar.'**
  String get bookingMissingBoth;

  /// Botón que guarda el turno (RF-25)
  ///
  /// In es, this message translates to:
  /// **'Agendar turno'**
  String get bookingAction;

  /// Título del diálogo de confirmación (RF-25)
  ///
  /// In es, this message translates to:
  /// **'Confirmar turno'**
  String get bookingConfirmTitle;

  /// Aviso del diálogo de confirmación (RF-28)
  ///
  /// In es, this message translates to:
  /// **'El turno quedará esperando la confirmación de Beidis.'**
  String get bookingConfirmPending;

  /// La comprobación previa encontró la hora ocupada (RF-29)
  ///
  /// In es, this message translates to:
  /// **'Esa hora acaba de ocuparse. Elige otra.'**
  String get bookingSlotTaken;

  /// La comprobación previa encontró un turno activo (RF-36)
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un turno pendiente.'**
  String get bookingAlreadyActive;

  /// Título de la vista del turno activo (RF-34)
  ///
  /// In es, this message translates to:
  /// **'Tu turno'**
  String get bookingActiveTitle;

  /// Explicación bajo el turno activo (RF-34)
  ///
  /// In es, this message translates to:
  /// **'Solo puedes tener un turno pendiente a la vez. Puedes ver todos tus turnos en tu perfil.'**
  String get bookingOnlyOneActive;

  /// Aviso para una cuenta bloqueada (RF-38)
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta no puede reservar turnos. Si crees que es un error, escríbenos por WhatsApp.'**
  String get bookingBlocked;

  /// Error al cargar turnos o calendario (RF-49)
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la agenda.'**
  String get bookingLoadError;

  /// Botón para volver a cargar la agenda (RF-49)
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get bookingRetry;

  /// Etiqueta de la duración en el resumen (RF-22)
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get bookingDuration;

  /// Etiqueta del precio total en el resumen (RF-22)
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get bookingTotal;

  /// Franja de inicio y fin de un turno
  ///
  /// In es, this message translates to:
  /// **'{start} – {end}'**
  String bookingTimeRange(String start, String end);

  /// Encabezado del aviso al cambiar el servicio de la edición desde su detalle (spec 006, RF-28)
  ///
  /// In es, this message translates to:
  /// **'Cambiaste el servicio:'**
  String get bookingEditItemChanged;

  /// El servicio pedido desde el detalle no cabe en la hora de la edición (spec 006, RF-29)
  ///
  /// In es, this message translates to:
  /// **'{service} dura {duration} y a esa hora solo hay {free} libres. Elige otra hora u otro servicio.'**
  String bookingEditItemDoesNotFit(
    String service,
    String duration,
    String free,
  );

  /// Al abrir la edición, un adicional del turno ya no se ofrece (spec 006, RF-6)
  ///
  /// In es, this message translates to:
  /// **'Algunos adicionales de tu turno ya no están disponibles y se quitaron.'**
  String get bookingEditAddonsUnavailable;

  /// El turno en edición ya no está activo (spec 006, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Tu turno ya no está activo: se canceló o terminó.'**
  String get bookingEditNotActive;

  /// Botón bajo el turno activo para editarlo (spec 006, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Editar turno'**
  String get bookingEditAction;

  /// El turno activo ya no es editable (spec 006, RF-2)
  ///
  /// In es, this message translates to:
  /// **'Ya no puedes cambiar este turno porque falta poco para que empiece. Si necesitas cambiarlo, escríbenos por WhatsApp.'**
  String get bookingEditClosed;

  /// Título de la vista de reserva al editar el turno (spec 006, RF-4)
  ///
  /// In es, this message translates to:
  /// **'Editar turno'**
  String get bookingEditTitle;

  /// Botón de la edición en lugar de Agendar turno (spec 006, RF-10)
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get bookingSaveChangesAction;

  /// Título del diálogo de antes y después (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Confirmar cambios'**
  String get bookingEditConfirmTitle;

  /// Valor de antes en el diálogo de cambios, para el lector de pantalla (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Antes'**
  String get bookingEditBefore;

  /// Valor de después en el diálogo de cambios, para el lector de pantalla (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Después'**
  String get bookingEditAfter;

  /// Marca de un valor que cambia, para el lector de pantalla (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'cambia'**
  String get bookingEditChangedLabel;

  /// Etiqueta de la hora de inicio en el diálogo de cambios (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get bookingEditStart;

  /// Etiqueta de la hora de fin en el diálogo de cambios (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Fin'**
  String get bookingEditEnd;

  /// Sin adicionales en el diálogo de cambios (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get bookingEditNoAddons;

  /// Aviso del diálogo de cambios (spec 006, RF-11)
  ///
  /// In es, this message translates to:
  /// **'El turno volverá a esperar la confirmación de Beidis.'**
  String get bookingEditConfirmPending;

  /// Al reservar un turno que ya empieza dentro del margen de edición (spec 006, RF-23)
  ///
  /// In es, this message translates to:
  /// **'No podrás cambiar este turno: falta menos de {margin} para que empiece.'**
  String bookingEditMarginWarning(String margin);

  /// Un valor que cambió, con el antes y el después (spec 006, RF-17, RF-28)
  ///
  /// In es, this message translates to:
  /// **'{label}: {before} → {after}'**
  String bookingEditChangeLine(String label, String before, String after);

  /// Título del diálogo tras guardar la edición (spec 006, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados'**
  String get bookingEditSavedTitle;

  /// Tras guardar la edición (spec 006, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Tu turno vuelve a esperar la confirmación de Beidis.'**
  String get bookingEditSavedPending;

  /// Se guardó la edición sin cambios (spec 006, RF-17)
  ///
  /// In es, this message translates to:
  /// **'No cambiaste nada: el turno sigue igual.'**
  String get bookingEditNoChanges;

  /// Al guardar, el turno ya está dentro del margen de edición (spec 006, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Ya no se puede cambiar el turno: falta poco para que empiece.'**
  String get bookingEditNotEditable;

  /// Al guardar, alguien cambió el turno (spec 006, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Tu turno cambió mientras lo editabas. Revisa cómo está ahora.'**
  String get bookingEditChangedMeanwhile;

  /// No se pudo guardar la edición (spec 006, RF-16)
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar los cambios. Inténtalo de nuevo.'**
  String get bookingEditSaveError;

  /// Título de la reserva de la admin (spec 007, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Agendar un turno'**
  String get bookingAdminTitle;

  /// Título de la parte de para quién es el turno (spec 007, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Para quién'**
  String get bookingStepRecipient;

  /// Etiqueta de la búsqueda de clientas (spec 007, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Nombre o WhatsApp de la clienta'**
  String get bookingRecipientSearchLabel;

  /// Indicación bajo la búsqueda de clientas (spec 007, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 caracteres'**
  String get bookingRecipientSearchHint;

  /// La búsqueda no encuentra a nadie (spec 007, RF-5)
  ///
  /// In es, this message translates to:
  /// **'No hay clientas con ese nombre o WhatsApp.'**
  String get bookingRecipientNoResults;

  /// Error al cargar las fichas (spec 007, RF-6)
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las clientas.'**
  String get bookingRecipientLoadError;

  /// Botón para agendar a alguien sin cuenta (spec 007, RF-5, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Persona sin cuenta'**
  String get bookingRecipientGuestAction;

  /// Vuelve de la persona sin cuenta a la búsqueda (spec 007)
  ///
  /// In es, this message translates to:
  /// **'Buscar clienta'**
  String get bookingRecipientSearchAction;

  /// Quita la clienta elegida para buscar otra (spec 007)
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get bookingRecipientChange;

  /// La persona elegida ya tiene un turno activo (spec 007, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Ya tiene un turno el {date} a las {time}: {service}. No se le puede agendar otro.'**
  String bookingRecipientActive(String date, String time, String service);

  /// Nombre de la persona sin cuenta (spec 007, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get bookingGuestNameLabel;

  /// WhatsApp de la persona sin cuenta (spec 007, RF-7)
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get bookingGuestPhoneLabel;

  /// Casilla de consentimiento de la persona sin cuenta (spec 007, RF-8)
  ///
  /// In es, this message translates to:
  /// **'La persona acepta dar su nombre y su WhatsApp para este turno.'**
  String get bookingGuestConsent;

  /// Nombre vacío o demasiado largo (spec 007, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Escribe un nombre de hasta 80 caracteres.'**
  String get bookingGuestNameError;

  /// WhatsApp no válido (spec 007, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Escribe un WhatsApp válido (de 8 a 15 dígitos).'**
  String get bookingGuestPhoneError;

  /// Casilla sin marcar (spec 007, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Marca la casilla para continuar.'**
  String get bookingGuestConsentError;

  /// El WhatsApp de la persona sin cuenta es de una clienta (spec 007, RF-10)
  ///
  /// In es, this message translates to:
  /// **'Este WhatsApp es de {name}, que tiene cuenta.'**
  String bookingGuestPhoneHasAccount(String name);

  /// Elige a la clienta con ese WhatsApp (spec 007, RF-10)
  ///
  /// In es, this message translates to:
  /// **'Elegir a {name}'**
  String bookingGuestChooseAccount(String name);

  /// Sigue con la persona sin cuenta (spec 007, RF-10)
  ///
  /// In es, this message translates to:
  /// **'Seguir sin cuenta'**
  String get bookingGuestKeepGuest;

  /// El WhatsApp es de una clienta bloqueada (spec 007, RF-11)
  ///
  /// In es, this message translates to:
  /// **'Este WhatsApp es de una clienta bloqueada: no se le puede agendar.'**
  String get bookingGuestPhoneBlocked;

  /// Falta para quién o sus datos (spec 007, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Indica para quién es el turno'**
  String get bookingMissingRecipient;

  /// Falta para quién y algo más (spec 007, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Faltan datos para agendar: revisa lo marcado.'**
  String get bookingMissingSeveral;

  /// Para quién es el turno, primero en el resumen (spec 007, RF-16)
  ///
  /// In es, this message translates to:
  /// **'Para: {name}'**
  String bookingSummaryFor(String name);

  /// Tras el WhatsApp de una persona sin cuenta en el resumen (spec 007, RF-16)
  ///
  /// In es, this message translates to:
  /// **'sin cuenta'**
  String get bookingSummaryGuest;

  /// Confirmación de la admin (spec 007, RF-16)
  ///
  /// In es, this message translates to:
  /// **'El turno quedará confirmado.'**
  String get bookingAdminConfirmNote;

  /// La admin agenda para una clienta con cuenta dentro del margen de edición (spec 007, RF-29)
  ///
  /// In es, this message translates to:
  /// **'{name} no podrá cambiar este turno: falta menos de {margin} para que empiece.'**
  String bookingAdminMarginWarning(String name, String margin);

  /// La admin agendó el turno (spec 007, RF-20)
  ///
  /// In es, this message translates to:
  /// **'Turno agendado para {name}.'**
  String bookingAdminCreated(String name);

  /// La clienta elegida se bloqueó y se quitó de Para quién (spec 007, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Esa clienta está bloqueada: ya no se le puede agendar.'**
  String get bookingRecipientBlocked;

  /// Marca de un turno de una persona sin cuenta en la lista de la admin (spec 007, RF-22)
  ///
  /// In es, this message translates to:
  /// **'Sin cuenta'**
  String get adminAppointmentGuest;

  /// Marca de un turno que creó la admin (spec 007, RF-23)
  ///
  /// In es, this message translates to:
  /// **'Agendado por la admin'**
  String get adminAppointmentByAdmin;

  /// Nombre del botón de WhatsApp de un turno en la lista de la admin (spec 007, RF-22, D-6)
  ///
  /// In es, this message translates to:
  /// **'Escribir a {name} por WhatsApp'**
  String adminAppointmentWhatsApp(String name);

  /// Título de la pantalla de cierres y del botón del panel (spec 008, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Cierres'**
  String get adminClosuresTitle;

  /// Lista de cierres vacía (spec 008, RF-2)
  ///
  /// In es, this message translates to:
  /// **'No hay cierres próximos.'**
  String get adminClosuresEmpty;

  /// Botón para crear un cierre (spec 008, RF-2, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Nuevo cierre'**
  String get adminClosuresNew;

  /// Error al cargar los cierres (spec 008, RF-10)
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los cierres.'**
  String get adminClosuresLoadError;

  /// Cierre de días enteros (spec 008, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Todo el día'**
  String get closureAllDay;

  /// Cierre de varios días: el primero y el último (spec 008, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Del {first} al {last}'**
  String closureDaysRange(String first, String last);

  /// Botón para quitar un cierre (spec 008, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get closureDeleteAction;

  /// Título de la confirmación al quitar un cierre (spec 008, RF-7)
  ///
  /// In es, this message translates to:
  /// **'¿Quitar este cierre?'**
  String get closureDeleteTitle;

  /// Texto de la confirmación al quitar un cierre (spec 008, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Esas horas volverán a estar libres para reservar.'**
  String get closureDeleteBody;

  /// Aviso tras quitar un cierre (spec 008, RF-7)
  ///
  /// In es, this message translates to:
  /// **'Cierre quitado.'**
  String get closureDeleted;

  /// Error al quitar un cierre (spec 008, RF-11)
  ///
  /// In es, this message translates to:
  /// **'No se pudo quitar el cierre. Inténtalo de nuevo.'**
  String get closureDeleteError;

  /// Tipo de cierre: una franja (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Unas horas'**
  String get closureKindRange;

  /// Tipo de cierre: días enteros (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Días enteros'**
  String get closureKindDays;

  /// Fecha de una franja (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get closureDateLabel;

  /// Hora de inicio de una franja (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get closureFromLabel;

  /// Hora de fin de una franja (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get closureToLabel;

  /// Primer día de un cierre de días enteros (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Primer día'**
  String get closureFirstDayLabel;

  /// Último día de un cierre de días enteros (spec 008, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Último día'**
  String get closureLastDayLabel;

  /// Error: la franja no termina después de empezar (spec 008, RF-4)
  ///
  /// In es, this message translates to:
  /// **'La hora de fin debe ser posterior a la de inicio.'**
  String get closureErrorEndNotAfterStart;

  /// Error: días al revés (spec 008, RF-4)
  ///
  /// In es, this message translates to:
  /// **'El último día no puede ser anterior al primero.'**
  String get closureErrorDaysReversed;

  /// Error: el cierre ya terminó (spec 008, RF-4)
  ///
  /// In es, this message translates to:
  /// **'Ese tiempo ya pasó.'**
  String get closureErrorPast;

  /// Error: fecha a más de 365 días (spec 008, RF-4)
  ///
  /// In es, this message translates to:
  /// **'Solo se puede cerrar hasta el {date}.'**
  String closureErrorTooFar(String date);

  /// Título de los turnos que chocan con un cierre (spec 008, RF-5)
  ///
  /// In es, this message translates to:
  /// **'Hay turnos en ese tiempo'**
  String get closureConflictsTitle;

  /// Explicación de los turnos que chocan (spec 008, RF-5)
  ///
  /// In es, this message translates to:
  /// **'Muévelos o cancélalos y vuelve a guardar el cierre.'**
  String get closureConflictsBody;

  /// Aviso tras guardar un cierre (spec 008, RF-6)
  ///
  /// In es, this message translates to:
  /// **'Cierre guardado.'**
  String get closureSaved;

  /// Error al guardar un cierre (spec 008, RF-11)
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el cierre. Inténtalo de nuevo.'**
  String get closureSaveError;

  /// Botón para editar un turno desde el panel (spec 008, RF-5, RF-18)
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get adminAppointmentEdit;

  /// Confirmación al cancelar un turno desde el panel (spec 008, RF-5)
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar el turno de {name}?'**
  String adminCancelAppointmentTitle(String name);

  /// Error al cancelar un turno desde los cierres (spec 008, RF-5)
  ///
  /// In es, this message translates to:
  /// **'No se pudo cancelar el turno. Inténtalo de nuevo.'**
  String get adminCancelAppointmentError;

  /// Marca de un cierre en la agenda del día (spec 008, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Cerrado'**
  String get adminAgendaClosed;

  /// Guardar cambios sin cambios (spec 008, RF-26)
  ///
  /// In es, this message translates to:
  /// **'No cambiaste nada.'**
  String get adminEditNoChanges;

  /// Edición de la admin guardada (spec 008, RF-28)
  ///
  /// In es, this message translates to:
  /// **'Turno de {name} guardado.'**
  String adminEditSaved(String name);

  /// El turno en edición ya no está activo (spec 008, RF-30)
  ///
  /// In es, this message translates to:
  /// **'Ese turno ya no está activo: se canceló o terminó.'**
  String get adminEditNotActive;

  /// Alguien cambió el turno en edición (spec 008, RF-30)
  ///
  /// In es, this message translates to:
  /// **'Alguien cambió ese turno mientras lo editabas. Revisa cómo está ahora.'**
  String get adminEditChanged;

  /// El turno a editar no existe (spec 008)
  ///
  /// In es, this message translates to:
  /// **'No se encontró ese turno.'**
  String get adminEditNotFound;

  /// Botón para volver a la agenda (spec 008)
  ///
  /// In es, this message translates to:
  /// **'Volver a la agenda'**
  String get adminEditBackToAgenda;

  /// Título de la sección del margen (spec 008, RF-36)
  ///
  /// In es, this message translates to:
  /// **'Margen de edición'**
  String get settingsEditMarginTitle;

  /// Explicación del margen (spec 008, RF-36)
  ///
  /// In es, this message translates to:
  /// **'Hasta cuánto antes del turno puede cambiarlo la clienta.'**
  String get settingsEditMarginHelp;

  /// Opción de margen 0 (spec 008, RF-36)
  ///
  /// In es, this message translates to:
  /// **'Sin margen'**
  String get settingsEditMarginNone;

  /// Opción de margen en horas (spec 008, RF-36)
  ///
  /// In es, this message translates to:
  /// **'{hours, plural, =1{1 hora} other{{hours} horas}}'**
  String settingsEditMarginHours(int hours);

  /// Margen guardado que no es una opción (spec 008, RF-37)
  ///
  /// In es, this message translates to:
  /// **'{hours} h {minutes} min'**
  String settingsEditMarginCustom(int hours, int minutes);

  /// Aviso al guardar el margen (spec 008, RF-38)
  ///
  /// In es, this message translates to:
  /// **'Margen guardado.'**
  String get settingsEditMarginSaved;

  /// Error al guardar el margen (spec 008, RF-39)
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el margen.'**
  String get settingsEditMarginError;

  /// Nombre de "Quitar" de un cierre para el lector de pantalla (spec 008, RNF-2)
  ///
  /// In es, this message translates to:
  /// **'Quitar el cierre: {dates}, {hours}'**
  String closureDeleteFor(String dates, String hours);

  /// Botón del día anterior en la agenda (spec 008, RNF-2)
  ///
  /// In es, this message translates to:
  /// **'Día anterior'**
  String get adminAgendaPreviousDay;

  /// Botón del día siguiente en la agenda (spec 008, RNF-2)
  ///
  /// In es, this message translates to:
  /// **'Día siguiente'**
  String get adminAgendaNextDay;

  /// Botón para cancelar el turno activo (spec 009, RF-8)
  ///
  /// In es, this message translates to:
  /// **'Cancelar turno'**
  String get cancelAppointmentAction;

  /// Título del diálogo de cancelar (spec 009, RF-9)
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar tu turno?'**
  String get cancelDialogTitle;

  /// Confirma la cancelación (spec 009, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Sí, cancelar'**
  String get cancelConfirm;

  /// Cierra el diálogo sin cancelar (spec 009, RF-10)
  ///
  /// In es, this message translates to:
  /// **'No, mantener'**
  String get cancelKeep;

  /// Aviso tras cancelar (spec 009, RF-12)
  ///
  /// In es, this message translates to:
  /// **'Tu turno se canceló.'**
  String get cancelDone;

  /// El turno ya está dentro del margen (spec 009, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Ya no puedes cancelarlo: falta poco para tu turno. Escríbenos por WhatsApp.'**
  String get cancelNotCancellable;

  /// El turno ya se canceló o terminó (spec 009, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Este turno ya no está activo.'**
  String get cancelNotActive;

  /// Alguien cambió el turno (spec 009, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Tu turno cambió. Revísalo antes de cancelarlo.'**
  String get cancelChanged;

  /// Error al cancelar, sin detalles (spec 009, RF-15)
  ///
  /// In es, this message translates to:
  /// **'No se pudo cancelar. Inténtalo de nuevo.'**
  String get cancelFailed;

  /// Título del turno activo en el perfil (spec 009, RF-1)
  ///
  /// In es, this message translates to:
  /// **'Tu próximo turno'**
  String get profileNextAppointmentTitle;

  /// El perfil sin turno activo (spec 009, RF-5)
  ///
  /// In es, this message translates to:
  /// **'No tienes turnos próximos.'**
  String get profileNoUpcoming;

  /// Botón para reservar desde el perfil sin turno activo (spec 009, RF-5)
  ///
  /// In es, this message translates to:
  /// **'Reservar'**
  String get profileBookAction;

  /// Título del historial del perfil (spec 009, RF-20)
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get profileHistoryTitle;

  /// Etiqueta de un turno que canceló la clienta (spec 009, RF-20)
  ///
  /// In es, this message translates to:
  /// **'CANCELADO POR TI'**
  String get historyCancelledByYou;

  /// Etiqueta de un turno que canceló el salón (spec 009, RF-20)
  ///
  /// In es, this message translates to:
  /// **'CANCELADO POR EL SALÓN'**
  String get historyCancelledBySalon;

  /// Etiqueta de un turno confirmado que ya terminó (spec 009, RF-20)
  ///
  /// In es, this message translates to:
  /// **'REALIZADO'**
  String get historyDone;

  /// Etiqueta de un turno que terminó sin confirmarse (spec 009, RF-21)
  ///
  /// In es, this message translates to:
  /// **'NO CONFIRMADO'**
  String get historyNotConfirmed;

  /// Vuelve a pedir los turnos del perfil (spec 009, RF-24)
  ///
  /// In es, this message translates to:
  /// **'REINTENTAR'**
  String get profileAppointmentsRetry;

  /// Marca de la agenda: lo canceló la clienta (spec 009, RF-18)
  ///
  /// In es, this message translates to:
  /// **'Cancelado por la clienta'**
  String get adminAppointmentCancelledByClient;

  /// Error del campo de WhatsApp del registro y del perfil (spec 009, RF-27)
  ///
  /// In es, this message translates to:
  /// **'Escribe un número de WhatsApp válido (de 8 a 15 dígitos).'**
  String get whatsAppInvalid;

  /// Sección de la cuenta en el perfil (spec 009, RF-25)
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta'**
  String get profileAccountTitle;

  /// Etiqueta del WhatsApp en el perfil (spec 009, RF-25)
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get profileWhatsAppLabel;

  /// Abre el cambio del WhatsApp (spec 009, RF-25)
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get changeAction;

  /// Título del diálogo para cambiar el WhatsApp (spec 009, RF-26)
  ///
  /// In es, this message translates to:
  /// **'Cambiar WhatsApp'**
  String get changeWhatsAppTitle;

  /// Guarda el WhatsApp nuevo (spec 009, RF-28)
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get whatsAppSaveAction;

  /// Aviso tras cambiar el WhatsApp (spec 009, RF-28)
  ///
  /// In es, this message translates to:
  /// **'Tu WhatsApp se actualizó.'**
  String get whatsAppSaved;

  /// Error al cambiar el WhatsApp, sin detalles técnicos (spec 009, RF-30)
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar. Inténtalo de nuevo.'**
  String get whatsAppSaveFailed;

  /// Botón y título para borrar la cuenta (spec 009, RF-31)
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get deleteAccountAction;

  /// Qué se borra y qué se conserva (spec 009, RF-32)
  ///
  /// In es, this message translates to:
  /// **'Se cancelará tu turno activo y se borrarán tu cuenta, tu nombre, tu correo, tu foto y tu WhatsApp. El salón conservará tus turnos, con tu nombre y tu WhatsApp, para su agenda.'**
  String get deleteAccountExplain;

  /// Pasa a escribir la palabra de confirmación (spec 009, RF-32)
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get deleteAccountContinue;

  /// Palabra que se escribe para confirmar el borrado (spec 009, D-11)
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get deleteAccountWord;

  /// Pide escribir la palabra de confirmación (spec 009, RF-32)
  ///
  /// In es, this message translates to:
  /// **'Escribe {word} para confirmar'**
  String deleteAccountTypeWord(String word);

  /// Aviso tras borrar la cuenta (spec 009, RF-36)
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta se eliminó.'**
  String get deleteAccountDone;

  /// Error al borrar la cuenta, sin detalles (spec 009, RF-39)
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta. Inténtalo de nuevo.'**
  String get deleteAccountFailed;

  /// Una clienta bloqueada no puede borrar su cuenta (spec 009, RF-40)
  ///
  /// In es, this message translates to:
  /// **'Para eliminar tu cuenta, habla con el salón.'**
  String get deleteAccountBlocked;

  /// Marca de la agenda: la clienta borró su cuenta (spec 009, RF-35)
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada'**
  String get adminAppointmentAccountDeleted;

  /// Botón de la agenda que vuelve al día de hoy del salón (spec 010, RF-3)
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get adminAgendaToday;

  /// Nombre del botón de la fecha de la agenda, que abre el calendario (spec 010, RF-4)
  ///
  /// In es, this message translates to:
  /// **'Elegir fecha'**
  String get adminAgendaPickDate;

  /// Marca de la agenda: el turno terminó sin confirmarse (spec 010, RF-9)
  ///
  /// In es, this message translates to:
  /// **'Sin confirmar'**
  String get adminAppointmentUnconfirmed;

  /// Error al confirmar un turno desde la agenda, sin detalles (spec 010, RF-17)
  ///
  /// In es, this message translates to:
  /// **'No se pudo confirmar. Inténtalo de nuevo.'**
  String get adminConfirmFailed;

  /// Aviso tras cancelar un turno desde la agenda o un cierre (spec 010, RF-18)
  ///
  /// In es, this message translates to:
  /// **'Turno cancelado.'**
  String get adminCancelDone;

  /// El turno cambió con el diálogo de cancelar abierto: no se cancela (spec 010, RF-15)
  ///
  /// In es, this message translates to:
  /// **'El turno cambió. Revísalo antes de cancelarlo.'**
  String get adminCancelChanged;

  /// Nombre del interruptor de bloqueo de una clienta para el lector de pantalla (spec 010, RNF-2)
  ///
  /// In es, this message translates to:
  /// **'Bloquear a {name}'**
  String adminBlockSwitch(String name);

  /// Título del diálogo de bloquear a una clienta (spec 010, RF-25)
  ///
  /// In es, this message translates to:
  /// **'¿Bloquear a {name}?'**
  String adminBlockTitle(String name);

  /// Qué supone bloquear a una clienta (spec 010, RF-25)
  ///
  /// In es, this message translates to:
  /// **'No podrá iniciar sesión ni reservar.'**
  String get adminBlockBody;

  /// Confirma el bloqueo (spec 010, RF-27)
  ///
  /// In es, this message translates to:
  /// **'Sí, bloquear'**
  String get adminBlockConfirm;

  /// Título del diálogo de desbloquear a una clienta (spec 010, RF-29)
  ///
  /// In es, this message translates to:
  /// **'¿Desbloquear a {name}?'**
  String adminUnblockTitle(String name);

  /// Qué supone desbloquear a una clienta (spec 010, RF-29)
  ///
  /// In es, this message translates to:
  /// **'Podrá volver a iniciar sesión y reservar.'**
  String get adminUnblockBody;

  /// Confirma el desbloqueo (spec 010, RF-30)
  ///
  /// In es, this message translates to:
  /// **'Sí, desbloquear'**
  String get adminUnblockConfirm;

  /// Cierra el diálogo de bloquear o desbloquear sin cambiar nada (spec 010, RF-31)
  ///
  /// In es, this message translates to:
  /// **'No, volver'**
  String get adminDialogBack;

  /// En el diálogo de bloquear, antes del turno activo que se cancelará (spec 010, RF-26)
  ///
  /// In es, this message translates to:
  /// **'Su turno se cancelará:'**
  String get adminBlockCancelsAppointment;

  /// Aviso tras bloquear a una clienta (spec 010, RF-33)
  ///
  /// In es, this message translates to:
  /// **'{name} está bloqueada.'**
  String adminBlockDone(String name);

  /// Aviso tras desbloquear a una clienta (spec 010, RF-33)
  ///
  /// In es, this message translates to:
  /// **'{name} está desbloqueada.'**
  String adminUnblockDone(String name);

  /// El turno activo de la clienta cambió con el diálogo abierto: no se bloquea (spec 010, RF-28)
  ///
  /// In es, this message translates to:
  /// **'Su turno cambió. Revísalo antes de bloquearla.'**
  String get adminBlockChanged;

  /// Error al bloquear, sin detalles (spec 010, RF-34)
  ///
  /// In es, this message translates to:
  /// **'No se pudo bloquear. Inténtalo de nuevo.'**
  String get adminBlockFailed;

  /// Error al desbloquear, sin detalles (spec 010, RF-34)
  ///
  /// In es, this message translates to:
  /// **'No se pudo desbloquear. Inténtalo de nuevo.'**
  String get adminUnblockFailed;

  /// Título de la explicación antes de pedir el permiso de notificaciones a la admin (spec 011, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Avisos de turnos'**
  String get adminPushExplainTitle;

  /// Para qué sirven los avisos, antes del diálogo del sistema (spec 011, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Te avisaremos en este teléfono cuando una clienta reserve, cambie o cancele un turno. A continuación, el teléfono te pedirá permiso para mostrar notificaciones.'**
  String get adminPushExplainBody;

  /// Botón que cierra la explicación y pide el permiso del sistema (spec 011, RF-15)
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get adminPushExplainContinue;

  /// Acción del aviso con la app abierta: abre la agenda del día del turno (spec 011, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get adminPushView;

  /// Nombre de "Ver" para el lector de pantalla (spec 011, RF-14)
  ///
  /// In es, this message translates to:
  /// **'Ver la agenda de ese día'**
  String get adminPushViewLabel;

  /// Título del aviso del panel cuando el teléfono no tiene permiso de notificaciones (spec 011, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Avisos desactivados'**
  String get adminPushDisabledTitle;

  /// Cómo activar los avisos en los ajustes del teléfono (spec 011, RF-17)
  ///
  /// In es, this message translates to:
  /// **'Este teléfono no muestra los avisos de turnos. Para recibirlos, activa las notificaciones de la app en los ajustes del teléfono.'**
  String get adminPushDisabledBody;
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
