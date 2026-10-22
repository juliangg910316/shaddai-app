// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get bookAppointment => 'Reservar Turno';

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

  @override
  String get brandFullName => 'Studio Shaddai';

  @override
  String get brandLogoLabel => 'Logotipo de Studio Shaddai';

  @override
  String get photoPlaceholderDefault => 'FOTO';

  @override
  String get cancelAction => 'CANCELAR';

  @override
  String get confirmAction => 'CONFIRMAR';

  @override
  String get adminAgendaLoadError =>
      'No pudimos cargar la agenda. Inténtalo de nuevo.';

  @override
  String get adminNoAppointmentsToday => 'No hay reservas para este día.';

  @override
  String get adminAgendaTitle => 'Agenda';

  @override
  String get adminPanelEyebrow => 'PANEL DE BEIDIS';

  @override
  String get adminStatAppointmentsToday => 'TURNOS HOY';

  @override
  String get pendingConfirmationLabel => 'POR CONFIRMAR';

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get settingsSavedSuccess => 'Ajustes guardados correctamente.';

  @override
  String get scheduleSettingsTitle => 'Horarios';

  @override
  String get closedLabel => 'CERRADO';

  @override
  String get openingTimeLabel => 'Apertura (HH:MM)';

  @override
  String get closingTimeLabel => 'Cierre (HH:MM)';

  @override
  String get adminClientsTitle => 'Clientes';

  @override
  String get adminClientsLoadError =>
      'No pudimos cargar los clientes. Inténtalo de nuevo.';

  @override
  String get adminNoClientsRegistered => 'No hay clientes registrados.';

  @override
  String get userStatusBlocked => 'BLOQUEADA';

  @override
  String get userStatusActive => 'ACTIVA';

  @override
  String get loginTagline => 'NAIL DESIGNER · BEIDIS VIERA';

  @override
  String get loginSubtitle => 'Inicia sesión para agendar tu turno';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get completeProfileTitle => 'Completar Perfil';

  @override
  String get completeProfileSubtitle => 'Un último paso antes de agendar';

  @override
  String get whatsappFieldLabel => 'TU WHATSAPP';

  @override
  String get phoneHintExample => '+58 412 555 0134';

  @override
  String get whatsappDisclaimer =>
      'Beidis te escribe por WhatsApp para confirmar tu turno, coordinar cambios y avisarte si se libera un horario. No lo compartimos con nadie más.';

  @override
  String get saveAndContinueAction => 'GUARDAR Y CONTINUAR';

  @override
  String get confirmBookingDialogTitle => 'Confirmar Reserva';

  @override
  String confirmBookingDialogBody(String date, String time) {
    return '¿Deseas reservar tu turno para el día $date a las $time?';
  }

  @override
  String get bookingCreatedSuccess =>
      '¡Reserva creada exitosamente! Esperando confirmación del administrador.';

  @override
  String get bookingCreateError =>
      'No pudimos crear la reserva. Inténtalo de nuevo.';

  @override
  String get stepServiceLabel => '1 · SERVICIO';

  @override
  String get stepDateLabel => '2 · FECHA';

  @override
  String get stepTimeLabel => '3 · Horario';

  @override
  String get slotsLoadError =>
      'No pudimos cargar los horarios. Inténtalo de nuevo.';

  @override
  String get chooseTimeSlotAction => 'ELIGE UN HORARIO';

  @override
  String confirmAtTimeAction(String time) {
    return 'CONFIRMAR $time';
  }

  @override
  String get bookingPendingNoticePrefix => 'Tu turno quedará en ';

  @override
  String get bookingPendingNoticeHighlight => 'Esperando confirmación';

  @override
  String get bookingPendingNoticeSuffix => ' hasta que Beidis lo apruebe.';

  @override
  String get noSlotsAvailable => 'No hay horarios disponibles para esta fecha.';

  @override
  String get serviceOptionClassicChip => 'Clásica 45m';

  @override
  String get serviceOptionClassicSummary => 'Clásica 45 min';

  @override
  String get serviceOptionSemipermChip => 'Semiperm. 60m';

  @override
  String get serviceOptionSemipermSummary => 'Semiperm. 60 min';

  @override
  String get serviceOptionAcrylicChip => 'Acrílicas 90m';

  @override
  String get serviceOptionAcrylicSummary => 'Acrílicas 90 min';

  @override
  String get myProfileTitle => 'Mi Perfil';

  @override
  String get adminPanelButtonLabel => 'PANEL DE ADMINISTRADOR';

  @override
  String get myAppointmentsTitle => 'Mis reservas';

  @override
  String get myAppointmentsLoadError =>
      'No pudimos cargar tus reservas. Inténtalo de nuevo.';

  @override
  String get noAppointmentsYet => 'Todavía no tienes reservas.';

  @override
  String get bookAnotherAppointmentAction => 'RESERVAR OTRO TURNO';

  @override
  String get statusConfirmedClient => 'CONFIRMADA';

  @override
  String get statusCancelledClient => 'CANCELADA';

  @override
  String get statusWaitingConfirmationClient => 'EN REVISIÓN';

  @override
  String get statusConfirmedAdmin => 'CONFIRMADO';

  @override
  String get statusCancelledAdmin => 'CANCELADO';

  @override
  String get preferencesTitle => 'Preferencias';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeMenuTooltip => 'Cambiar tema';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageCodeEs => 'ES';

  @override
  String get languageCodePt => 'PT';

  @override
  String get languageSwitchLabel => 'Cambiar idioma';

  @override
  String get selectedOption => 'Seleccionado';

  @override
  String get profileGuestTitle => 'Perfil';

  @override
  String get profileGuestLoginButton => 'Iniciar sesión';

  @override
  String get authBlockedError =>
      'Tu cuenta está bloqueada. Escríbenos por WhatsApp si crees que es un error.';

  @override
  String get authGenericError =>
      'No pudimos iniciar sesión. Inténtalo de nuevo.';

  @override
  String get loginAppBarTitle => 'Autenticación';

  @override
  String get webNavServices => 'Servicios';

  @override
  String get webNavCatalog => 'Catálogo';

  @override
  String get webNavAbout => 'Sobre mí';

  @override
  String get webNavReserve => 'Reservar';

  @override
  String get webMenuOpenLabel => 'Abrir menú';

  @override
  String get webMenuCloseLabel => 'Cerrar menú';

  @override
  String get webHomeLinkLabel => 'Studio Shaddai, ir al inicio';

  @override
  String get accountSignIn => 'Entrar';

  @override
  String get accountMenuLabel => 'Menú de cuenta';

  @override
  String get accountMyAppointments => 'Mis turnos';

  @override
  String get accountAdminPanel => 'Panel de administración';

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get bookingCreatedWebTitle => 'Reserva creada';

  @override
  String get bookingBackToLanding => 'Volver al inicio';

  @override
  String get webAppTitle => 'Studio Shaddai · Nail Designer';

  @override
  String get landingHeroKicker => 'Nail Designer · Capão da Imbuia, Curitiba';

  @override
  String get landingHeroScript => 'Un tiempo para ti.';

  @override
  String get landingHeroTitleLine1 => 'Más que uñas,';

  @override
  String get landingHeroTitleLine2Em => 'momentos de bienestar.';

  @override
  String get landingHeroDesc =>
      'Manicura, pedicura, alargamientos, esmaltado en gel y spa en un estudio privado, con hora reservada y atención en español y portugués.';

  @override
  String get landingHeroCtaReserve => 'Reservar cita';

  @override
  String get landingHeroCtaPrices => 'Ver lista de precios';

  @override
  String get landingHeroStatServicesLabel => 'Servicios';

  @override
  String get landingHeroStatFollowersLabel => 'Seguidoras';

  @override
  String get landingHeroStatNoticeLabel => 'Aviso p/ cambios';

  @override
  String get landingHeroAddressLabel => 'Estudio privado · Curitiba';

  @override
  String get landingHeroAddressCta => 'Mapa →';

  @override
  String get landingHeroBadgeLine1 => 'Francesa';

  @override
  String get landingHeroBadgeLine2 => 'gratis';

  @override
  String get landingHeroImageAlt =>
      'Beidis Viera – Studio Shaddai Nail Designer';

  @override
  String get landingMarqueeGelPolish => 'Esmaltado en gel';

  @override
  String get landingMarqueeSpaMore => 'Spa y más';

  @override
  String get landingMarqueeManicure => 'Manicura';

  @override
  String get landingMarqueePedicure => 'Pedicura';

  @override
  String get landingMarqueeExtensions => 'Alargamientos';

  @override
  String get landingServicesEyebrow => 'Lista de precios';

  @override
  String get landingServicesTitle => 'Todos los';

  @override
  String get landingServicesTitleEm => 'servicios';

  @override
  String get landingServicesNote =>
      'Precios en reales. Cada cita empieza con el diagnóstico de tus uñas: duración y acabado los decidimos juntas.';

  @override
  String get landingServices1Title => 'Manos';

  @override
  String get landingServices1Subtitle => 'Cuidado y elegancia siempre';

  @override
  String get landingServices1Row1 => 'Manicure tradicional';

  @override
  String get landingServices1Row2 => 'Spa de manos';

  @override
  String get landingServices1Row3 => 'Esmaltado en gel · manos';

  @override
  String get landingServices1Row4 => 'Baño de gel (corto a medio)';

  @override
  String get landingServices1Row5 => 'Baño de gel (largo)';

  @override
  String get landingServices1Note =>
      'El baño de gel incluye preparación, cutículas, esmaltado en gel de un color y decoración simple.';

  @override
  String get landingServices2Title => 'Pies';

  @override
  String get landingServices2Subtitle => 'Confort y bienestar';

  @override
  String get landingServices2Row1 => 'Pedicura tradicional';

  @override
  String get landingServices2Row2 => 'Pedicura + Mini Spa';

  @override
  String get landingServices2Row3 => 'Pedicura Spa';

  @override
  String get landingServices2Row4 => 'Plástica de pies + Pedicura';

  @override
  String get landingServices2Row5 => 'Esmaltado en gel · pies';

  @override
  String get landingServices2Note =>
      'Mini Spa: cuidado localizado de callosidades. Spa: exfoliación, hidratación y cuidado completo de los pies.';

  @override
  String get landingServices3Title => 'Alargamientos';

  @override
  String get landingServices3Subtitle => 'Gel, Polygel y Acrílico';

  @override
  String get landingServices3GroupNew => 'Nueva aplicación';

  @override
  String get landingServices3GroupMaintenance => 'Mantenimiento';

  @override
  String get landingServices3RowShort => 'Corto';

  @override
  String get landingServices3RowMedium => 'Medio';

  @override
  String get landingServices3RowLong => 'Largo';

  @override
  String get landingServices3RowExtraLong => 'Extra largo';

  @override
  String get landingServices3Note =>
      'Mismo precio por técnica; solo varía el largo. El precio base incluye preparación, cutículas, estructura, esmaltado en gel de un color y decoración simple en 1 uña. Mantenimiento hasta 30 días.';

  @override
  String get landingServices4Subtitle => 'Practicidad y ligereza';

  @override
  String get landingServices4Row1 => 'Corto / Medio';

  @override
  String get landingServices4Row2 => 'Largo';

  @override
  String get landingServices4Row3 => 'Mantenimiento / reaplicación · desde';

  @override
  String get landingServices4Note =>
      'Mantenimiento según el crecimiento y el estado de la estructura.';

  @override
  String get landingServices5Title => 'Retiradas';

  @override
  String get landingServices5Subtitle => 'Salud de la uña primero';

  @override
  String get landingServices5Row1 => 'Esmaltado en gel';

  @override
  String get landingServices5Row2 => 'Baño de gel';

  @override
  String get landingServices5Row3 => 'Alargamiento';

  @override
  String get landingServices5Note =>
      'Retirada + nueva aplicación en la misma cita: R\$ 30.';

  @override
  String get landingServices6Title => 'Decoración y adicionales';

  @override
  String get landingServices6Subtitle => 'Detalles que marcan la diferencia';

  @override
  String get landingServices6Row1 => 'Francesa elaborada';

  @override
  String get landingServices6Row2 => 'Cromado / ojo de gato';

  @override
  String get landingServices6Row3 => 'Encapsulado';

  @override
  String get landingServices6Row4 => 'Nail art simple';

  @override
  String get landingServices6Row5 => 'Nail art intermedia';

  @override
  String get landingServices6Row6 => 'Nail art elaborada';

  @override
  String get landingServices6Row7 => 'Pedrería';

  @override
  String get landingServices6Note =>
      'Adhesivos, composiciones con varias técnicas y diseños personalizados se valoran según cantidad de uñas, dificultad y tiempo.';

  @override
  String get landingCombosEyebrow => 'Ventajas';

  @override
  String get landingCombosNote =>
      'Los combos no son acumulables con otras promociones.';

  @override
  String get landingCombo1Name => 'Manos y Pies Tradicional';

  @override
  String get landingCombo1Desc => 'Manicura tradicional + Pedicura tradicional';

  @override
  String get landingCombo2Name => 'Gel Completo';

  @override
  String get landingCombo2Desc => 'Esmaltado en gel manos + pies';

  @override
  String get landingCombo3Name => 'Momento Shaddai';

  @override
  String get landingCombo3Desc => 'Manicura + Spa de manos + Pedicura Spa';

  @override
  String get landingCatalogEyebrow => 'Material del estudio';

  @override
  String get landingCatalogTitle => 'Catálogo de';

  @override
  String get landingCatalogTitleEm => 'servicios';

  @override
  String get landingCatalogNote =>
      'Toca para ampliar cada página del catálogo.';

  @override
  String get landingCatalogAltPortada =>
      'Studio Shaddai — Catálogo de servicios';

  @override
  String get landingCatalogAltAlongamentos => 'Alargamientos';

  @override
  String get landingCatalogAltSoftGel => 'Soft Gel';

  @override
  String get landingCatalogAltManutencion => 'Mantenimiento de uñas';

  @override
  String get landingCatalogAltDecoraciones => 'Decoraciones para uñas';

  @override
  String get landingCatalogAltCombos => 'Combos y paquetes especiales';

  @override
  String get landingCatalogAltNaturales => 'Uñas naturales';

  @override
  String get landingCatalogAltPies => 'Pies y cuidados especiales';

  @override
  String get landingCatalogAltAgendamiento => 'Agendamiento de citas';

  @override
  String get landingCatalogMoreCta => 'Más páginas del catálogo en Instagram';

  @override
  String get landingInfoEyebrow => 'Información importante';

  @override
  String get landingInfoTitle => 'Cómo funciona la';

  @override
  String get landingInfoTitleEm => 'atención';

  @override
  String get landingInfoDesc =>
      'Reglas simples para cuidar la estructura de tus uñas — y tu hora reservada.';

  @override
  String get landingInfoScript => 'Tu tiempo también importa ♡';

  @override
  String get landingInfo1Title => 'Reposición';

  @override
  String get landingInfo1Body =>
      '1 uña durante el mantenimiento: incluida. A partir de la 2ª uña: R\$ 5 cada una. Fuera del mantenimiento: R\$ 15.';

  @override
  String get landingInfo2Title => 'Plazo de mantenimiento';

  @override
  String get landingInfo2Body =>
      'Los mantenimientos se realizan hasta 30 días. Pasado ese plazo, el servicio puede considerarse nueva aplicación según el crecimiento, desprendimientos y estado de la estructura.';

  @override
  String get landingInfo3Title => 'Retrasos';

  @override
  String get landingInfo3Body =>
      'Tolerancia de 10 minutos. Después, la cita puede adaptarse o reprogramarse para no afectar los horarios siguientes.';

  @override
  String get landingInfo4Title => 'Cancelaciones';

  @override
  String get landingInfo4Body =>
      'Cancelaciones o cambios de horario: avisar con al menos 24 horas de antelación. Atención siempre con hora reservada.';

  @override
  String get landingGalleryEyebrow => 'Mi trabajo';

  @override
  String get landingGalleryTitle => 'Galería de';

  @override
  String get landingGalleryTitleEm => 'diseños';

  @override
  String get landingGalleryMoreLink => 'Ver más en Instagram →';

  @override
  String landingGalleryItemLabel(int n) {
    return 'Diseño $n — ver más en Instagram';
  }

  @override
  String get landingAboutQuoteLabel => 'En sus palabras';

  @override
  String get landingAboutQuote => '“La belleza también es cuidarte a ti.”';

  @override
  String get landingAboutEyebrow => 'Mi historia';

  @override
  String get landingAboutTitle => 'Soy';

  @override
  String get landingAboutParagraph1 =>
      'Nail designer y apasionada de la belleza. Detrás de Studio Shaddai hay una mujer que sigue aprendiendo, soñando y creciendo cada día.';

  @override
  String get landingAboutParagraph2 =>
      'Las redes muestran el resultado final, pero detrás de cada diseño hay preparación, técnica y pasión por el detalle. Para mí, cada uña es una oportunidad de crear algo bello que también cuide la salud de tus manos.';

  @override
  String get landingAboutValue1 => 'Técnica con fundamento, no solo tendencia';

  @override
  String get landingAboutValue2 => 'Salud de la uña primero, siempre';

  @override
  String get landingAboutValue3 => 'Espacio higienizado, trabajo impecable';

  @override
  String get landingAboutValue4 => 'Atención en español y portugués';

  @override
  String get landingContactEyebrow => 'Hablemos';

  @override
  String get landingContactTitle => 'Reserva tu';

  @override
  String get landingContactTitleEm => 'cita';

  @override
  String get landingContactDesc =>
      '¿Lista para tener las uñas que siempre quisiste? Escríbeme y encontramos el momento perfecto para ti.';

  @override
  String get landingContactCtaWhatsapp => 'Agenda por WhatsApp ♡';

  @override
  String get landingContactPhoneLabel => 'Teléfono';

  @override
  String get landingContactEmailLabel => 'Email';

  @override
  String get landingContactAddressLabel => 'Dirección';

  @override
  String get landingContactInstagramLabel => 'Instagram';

  @override
  String get landingFooterTagline => 'La belleza también es cuidarte ♡';

  @override
  String get landingWhatsappFloatTitle => 'Reservar por WhatsApp';

  @override
  String get landingSoftGelTitle => 'Soft Gel';

  @override
  String get landingCombosTitle => 'Combos';

  @override
  String get landingCombosTitleEm => 'Shaddai';

  @override
  String get landingHeroBadgeLine3 => '1ª visita ♡';

  @override
  String get landingServices6RowBabyBoomer => 'Baby boomer';

  @override
  String get landingServices6RowReversa => 'Reversa';

  @override
  String get salonMapLabel => 'Mapa con la ubicación del estudio';

  @override
  String get bookingSignInTitle => 'Inicia sesión para reservar';

  @override
  String get bookingSignInBody =>
      'Usamos tu cuenta de Google para guardar tus turnos y que Beidis pueda confirmarlos por WhatsApp.';
}
