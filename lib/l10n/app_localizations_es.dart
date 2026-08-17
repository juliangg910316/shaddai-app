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
  String get welcomeGreeting => 'Bienvenida,';

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
  String get guestFallbackName => 'Invitada';

  @override
  String get brandFullName => 'D\'Shaddai';

  @override
  String get popularServicesTitle => 'Servicios populares';

  @override
  String get viewAllAction => 'VER TODO';

  @override
  String get ourWorkTitle => 'Nuestros trabajos';

  @override
  String get salonPhotoPlaceholder => 'FOTO DEL SALÓN';

  @override
  String get findUsTitle => 'Encuéntranos';

  @override
  String get salonName => 'Shaddai Studio';

  @override
  String get salonAddress =>
      'Rua Prof. Nivaldo Braga 1108, Capão da Imbuia, Curitiba - PR';

  @override
  String get heroTitle => 'D\'Shaddai\nNail Salon';

  @override
  String get heroSubtitle => 'Cuidado de lujo para tus uñas';

  @override
  String get photoPlaceholderDefault => 'FOTO';

  @override
  String get serviceManicureClassicName => 'Manicure Clásica';

  @override
  String get serviceManicureClassicDesc =>
      'Limpieza, exfoliación, masaje y esmaltado tradicional.';

  @override
  String get serviceManicureSemipermName => 'Manicure Semipermanente';

  @override
  String get serviceManicureSemipermDesc =>
      'Limpieza profunda y esmaltado de larga duración (Gel).';

  @override
  String get serviceAcrylicSetName => 'Set Nuevo Acrílicas';

  @override
  String get serviceAcrylicSetDesc =>
      'Uñas acrílicas con molde o tip, largo medio. Incluye esmaltado.';

  @override
  String get serviceAcrylicFullName => 'Acrílicas Full';

  @override
  String get serviceAcrylicTouchupName => 'Retoque Acrílico';

  @override
  String get serviceAcrylicTouchupDesc =>
      'Relleno de crecimiento (hasta 3 semanas).';

  @override
  String get servicePedicureSpaName => 'Pedicure Spa';

  @override
  String get servicePedicureSpaDesc =>
      'Limpieza profunda, remoción de callosidades, exfoliación, mascarilla y esmaltado.';

  @override
  String get serviceJellyPedicureName => 'Jelly Pedicure';

  @override
  String get serviceJellyPedicureDesc =>
      'Terapia de hidratación profunda con textura gelatinosa relajante.';

  @override
  String get duration45Min => '45 min';

  @override
  String get duration60Min => '60 min';

  @override
  String get duration75Min => '75 min';

  @override
  String get duration90Min => '90 min';

  @override
  String get categoryManicure => 'Manicure';

  @override
  String get categoryAcrylicGel => 'Acrílicas & Gel';

  @override
  String get categoryPedicure => 'Pedicure';

  @override
  String get ourServicesTitle => 'Nuestros Servicios';

  @override
  String get servicesMenuEyebrow => 'CARTA D\'SHADDAI';

  @override
  String get bookAction => 'RESERVAR';

  @override
  String get cancelAction => 'CANCELAR';

  @override
  String get confirmAction => 'CONFIRMAR';

  @override
  String adminAgendaLoadError(Object error) {
    return 'No pudimos cargar la agenda: $error';
  }

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
  String adminClientsLoadError(Object error) {
    return 'No pudimos cargar los clientes: $error';
  }

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
  String bookingCreateError(Object error) {
    return 'Error al crear la reserva: $error';
  }

  @override
  String get stepServiceLabel => '1 · SERVICIO';

  @override
  String get stepDateLabel => '2 · FECHA';

  @override
  String get stepTimeLabel => '3 · Horario';

  @override
  String slotsLoadError(Object error) {
    return 'No pudimos cargar los horarios: $error';
  }

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
  String myAppointmentsLoadError(Object error) {
    return 'No pudimos cargar tus reservas: $error';
  }

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
}
