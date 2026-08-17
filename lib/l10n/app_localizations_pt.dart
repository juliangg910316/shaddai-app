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
  String get welcomeGreeting => 'Bem-vinda,';

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

  @override
  String get guestFallbackName => 'Convidada';

  @override
  String get brandFullName => 'D\'Shaddai';

  @override
  String get popularServicesTitle => 'Serviços populares';

  @override
  String get viewAllAction => 'VER TUDO';

  @override
  String get ourWorkTitle => 'Nossos trabalhos';

  @override
  String get salonPhotoPlaceholder => 'FOTO DO SALÃO';

  @override
  String get findUsTitle => 'Encontre-nos';

  @override
  String get salonName => 'Shaddai Studio';

  @override
  String get salonAddress =>
      'Rua Prof. Nivaldo Braga 1108, Capão da Imbuia, Curitiba - PR';

  @override
  String get heroTitle => 'D\'Shaddai\nNail Salon';

  @override
  String get heroSubtitle => 'Cuidado de luxo para suas unhas';

  @override
  String get photoPlaceholderDefault => 'FOTO';

  @override
  String get serviceManicureClassicName => 'Manicure Clássica';

  @override
  String get serviceManicureClassicDesc =>
      'Limpeza, esfoliação, massagem e esmaltação tradicional.';

  @override
  String get serviceManicureSemipermName => 'Manicure Semipermanente';

  @override
  String get serviceManicureSemipermDesc =>
      'Limpeza profunda e esmaltação de longa duração (Gel).';

  @override
  String get serviceAcrylicSetName => 'Novo Set de Acrílicas';

  @override
  String get serviceAcrylicSetDesc =>
      'Unhas acrílicas com molde ou tip, comprimento médio. Inclui esmaltação.';

  @override
  String get serviceAcrylicFullName => 'Acrílicas Full';

  @override
  String get serviceAcrylicTouchupName => 'Retoque Acrílico';

  @override
  String get serviceAcrylicTouchupDesc =>
      'Preenchimento de crescimento (até 3 semanas).';

  @override
  String get servicePedicureSpaName => 'Pedicure Spa';

  @override
  String get servicePedicureSpaDesc =>
      'Limpeza profunda, remoção de calosidades, esfoliação, máscara e esmaltação.';

  @override
  String get serviceJellyPedicureName => 'Jelly Pedicure';

  @override
  String get serviceJellyPedicureDesc =>
      'Terapia de hidratação profunda com textura gelatinosa relaxante.';

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
  String get ourServicesTitle => 'Nossos Serviços';

  @override
  String get servicesMenuEyebrow => 'CARTA D\'SHADDAI';

  @override
  String get bookAction => 'AGENDAR';

  @override
  String get cancelAction => 'CANCELAR';

  @override
  String get confirmAction => 'CONFIRMAR';

  @override
  String adminAgendaLoadError(Object error) {
    return 'Não foi possível carregar a agenda: $error';
  }

  @override
  String get adminNoAppointmentsToday =>
      'Não há horários marcados para este dia.';

  @override
  String get adminAgendaTitle => 'Agenda';

  @override
  String get adminPanelEyebrow => 'PAINEL DE BEIDIS';

  @override
  String get adminStatAppointmentsToday => 'HORÁRIOS HOJE';

  @override
  String get pendingConfirmationLabel => 'A CONFIRMAR';

  @override
  String get weekdayMonday => 'Segunda-feira';

  @override
  String get weekdayTuesday => 'Terça-feira';

  @override
  String get weekdayWednesday => 'Quarta-feira';

  @override
  String get weekdayThursday => 'Quinta-feira';

  @override
  String get weekdayFriday => 'Sexta-feira';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get settingsSavedSuccess => 'Configurações salvas com sucesso.';

  @override
  String get scheduleSettingsTitle => 'Horários';

  @override
  String get closedLabel => 'FECHADO';

  @override
  String get openingTimeLabel => 'Abertura (HH:MM)';

  @override
  String get closingTimeLabel => 'Fechamento (HH:MM)';

  @override
  String get adminClientsTitle => 'Clientes';

  @override
  String adminClientsLoadError(Object error) {
    return 'Não foi possível carregar os clientes: $error';
  }

  @override
  String get adminNoClientsRegistered => 'Não há clientes cadastrados.';

  @override
  String get userStatusBlocked => 'BLOQUEADA';

  @override
  String get userStatusActive => 'ATIVA';

  @override
  String get loginTagline => 'DESIGNER DE UNHAS · BEIDIS VIERA';

  @override
  String get loginSubtitle => 'Faça login para agendar seu horário';

  @override
  String get continueWithGoogle => 'Continuar com o Google';

  @override
  String get completeProfileTitle => 'Complete seu Perfil';

  @override
  String get completeProfileSubtitle => 'Um último passo antes de agendar';

  @override
  String get whatsappFieldLabel => 'SEU WHATSAPP';

  @override
  String get phoneHintExample => '+58 412 555 0134';

  @override
  String get whatsappDisclaimer =>
      'Beidis fala com você pelo WhatsApp para confirmar seu horário, combinar mudanças e avisar se um horário for liberado. Não compartilhamos com mais ninguém.';

  @override
  String get saveAndContinueAction => 'SALVAR E CONTINUAR';

  @override
  String get confirmBookingDialogTitle => 'Confirmar Reserva';

  @override
  String confirmBookingDialogBody(String date, String time) {
    return 'Deseja reservar seu horário para o dia $date às $time?';
  }

  @override
  String get bookingCreatedSuccess =>
      'Reserva criada com sucesso! Aguardando confirmação da administradora.';

  @override
  String bookingCreateError(Object error) {
    return 'Erro ao criar a reserva: $error';
  }

  @override
  String get stepServiceLabel => '1 · SERVIÇO';

  @override
  String get stepDateLabel => '2 · DATA';

  @override
  String get stepTimeLabel => '3 · Horário';

  @override
  String slotsLoadError(Object error) {
    return 'Não foi possível carregar os horários: $error';
  }

  @override
  String get chooseTimeSlotAction => 'ESCOLHA UM HORÁRIO';

  @override
  String confirmAtTimeAction(String time) {
    return 'CONFIRMAR $time';
  }

  @override
  String get bookingPendingNoticePrefix => 'Seu horário ficará ';

  @override
  String get bookingPendingNoticeHighlight => 'Aguardando confirmação';

  @override
  String get bookingPendingNoticeSuffix => ' até que Beidis aprove.';

  @override
  String get noSlotsAvailable => 'Não há horários disponíveis para esta data.';

  @override
  String get serviceOptionClassicChip => 'Clássica 45m';

  @override
  String get serviceOptionClassicSummary => 'Clássica 45 min';

  @override
  String get serviceOptionSemipermChip => 'Semiperm. 60m';

  @override
  String get serviceOptionSemipermSummary => 'Semiperm. 60 min';

  @override
  String get serviceOptionAcrylicChip => 'Acrílicas 90m';

  @override
  String get serviceOptionAcrylicSummary => 'Acrílicas 90 min';

  @override
  String get myProfileTitle => 'Meu Perfil';

  @override
  String get adminPanelButtonLabel => 'PAINEL DE ADMINISTRADOR';

  @override
  String get myAppointmentsTitle => 'Meus horários';

  @override
  String myAppointmentsLoadError(Object error) {
    return 'Não foi possível carregar seus horários: $error';
  }

  @override
  String get noAppointmentsYet => 'Você ainda não tem horários marcados.';

  @override
  String get bookAnotherAppointmentAction => 'AGENDAR OUTRO HORÁRIO';

  @override
  String get statusConfirmedClient => 'CONFIRMADA';

  @override
  String get statusCancelledClient => 'CANCELADA';

  @override
  String get statusWaitingConfirmationClient => 'EM REVISÃO';

  @override
  String get statusConfirmedAdmin => 'CONFIRMADO';

  @override
  String get statusCancelledAdmin => 'CANCELADO';
}
