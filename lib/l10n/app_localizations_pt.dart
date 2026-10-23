// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get bookAppointment => 'Agendar Horário';

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
  String get brandFullName => 'Studio Shaddai';

  @override
  String get brandLogoLabel => 'Logotipo do Studio Shaddai';

  @override
  String get photoPlaceholderDefault => 'FOTO';

  @override
  String get cancelAction => 'CANCELAR';

  @override
  String get confirmAction => 'CONFIRMAR';

  @override
  String get adminAgendaLoadError =>
      'Não foi possível carregar a agenda. Tente novamente.';

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
  String get adminClientsLoadError =>
      'Não foi possível carregar os clientes. Tente novamente.';

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
  String get bookingCreateError =>
      'Não foi possível criar a reserva. Tente novamente.';

  @override
  String get stepServiceLabel => '1 · SERVIÇO';

  @override
  String get stepDateLabel => '2 · DATA';

  @override
  String get stepTimeLabel => '3 · Horário';

  @override
  String get slotsLoadError =>
      'Não foi possível carregar os horários. Tente novamente.';

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
  String get myAppointmentsLoadError =>
      'Não foi possível carregar seus horários. Tente novamente.';

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

  @override
  String get preferencesTitle => 'Preferências';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeMenuTooltip => 'Alterar tema';

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
  String get languageSwitchLabel => 'Alterar idioma';

  @override
  String get selectedOption => 'Selecionado';

  @override
  String get profileGuestTitle => 'Perfil';

  @override
  String get profileGuestLoginButton => 'Entrar';

  @override
  String get authBlockedError =>
      'Sua conta está bloqueada. Fale conosco pelo WhatsApp se achar que é um erro.';

  @override
  String get authGenericError => 'Não foi possível entrar. Tente novamente.';

  @override
  String get loginAppBarTitle => 'Autenticação';

  @override
  String get webNavServices => 'Serviços';

  @override
  String get webNavCatalog => 'Catálogo';

  @override
  String get webNavAbout => 'Sobre mim';

  @override
  String get webNavReserve => 'Agendar';

  @override
  String get webMenuOpenLabel => 'Abrir menu';

  @override
  String get webMenuCloseLabel => 'Fechar menu';

  @override
  String get webHomeLinkLabel => 'Studio Shaddai, ir para o início';

  @override
  String get accountSignIn => 'Entrar';

  @override
  String get accountMenuLabel => 'Menu da conta';

  @override
  String get accountMyAppointments => 'Meus horários';

  @override
  String get accountAdminPanel => 'Painel de administração';

  @override
  String get accountSignOut => 'Sair';

  @override
  String get bookingCreatedWebTitle => 'Agendamento criado';

  @override
  String get bookingBackToLanding => 'Voltar ao início';

  @override
  String get webAppTitle => 'Studio Shaddai · Nail Designer';

  @override
  String get landingHeroKicker => 'Nail Designer · Capão da Imbuia, Curitiba';

  @override
  String get landingHeroScript => 'Um tempo para você.';

  @override
  String get landingHeroTitleLine1 => 'Mais que unhas,';

  @override
  String get landingHeroTitleLine2Em => 'momentos de bem-estar.';

  @override
  String get landingHeroDesc =>
      'Manicure, pedicure, alongamentos, esmaltação em gel e spa em um estúdio privado, com horário agendado e atendimento em espanhol e português.';

  @override
  String get landingHeroCtaReserve => 'Agendar horário';

  @override
  String get landingHeroCtaPrices => 'Ver tabela de preços';

  @override
  String get landingHeroStatServicesLabel => 'Serviços';

  @override
  String get landingHeroStatFollowersLabel => 'Seguidoras';

  @override
  String get landingHeroStatNoticeLabel => 'Aviso p/ mudanças';

  @override
  String get landingHeroAddressLabel => 'Estúdio privado · Curitiba';

  @override
  String get landingHeroAddressCta => 'Mapa →';

  @override
  String get landingHeroBadgeLine1 => 'Francesinha';

  @override
  String get landingHeroBadgeLine2 => 'grátis';

  @override
  String get landingHeroImageAlt =>
      'Beidis Viera – Studio Shaddai Nail Designer';

  @override
  String get landingMarqueeGelPolish => 'Esmaltação em gel';

  @override
  String get landingMarqueeSpaMore => 'Spa e mais';

  @override
  String get landingMarqueeManicure => 'Manicure';

  @override
  String get landingMarqueePedicure => 'Pedicure';

  @override
  String get landingMarqueeExtensions => 'Alongamentos';

  @override
  String get landingServicesEyebrow => 'Tabela de preços';

  @override
  String get landingServicesTitle => 'Todos os';

  @override
  String get landingServicesTitleEm => 'serviços';

  @override
  String get landingServicesNote =>
      'Preços em reais. Cada atendimento começa com o diagnóstico das suas unhas: duração e acabamento decidimos juntas.';

  @override
  String get landingServices1Title => 'Mãos';

  @override
  String get landingServices1Subtitle => 'Cuidado e elegância sempre';

  @override
  String get landingServices1Row1 => 'Manicure tradicional';

  @override
  String get landingServices1Row2 => 'Spa de mãos';

  @override
  String get landingServices1Row3 => 'Esmaltação em gel · mãos';

  @override
  String get landingServices1Row4 => 'Banho de gel (curto a médio)';

  @override
  String get landingServices1Row5 => 'Banho de gel (longo)';

  @override
  String get landingServices1Note =>
      'O banho de gel inclui preparação, cutículas, esmaltação em gel de uma cor e decoração simples.';

  @override
  String get landingServices2Title => 'Pés';

  @override
  String get landingServices2Subtitle => 'Conforto e bem-estar';

  @override
  String get landingServices2Row1 => 'Pedicure tradicional';

  @override
  String get landingServices2Row2 => 'Pedicure + Mini Spa';

  @override
  String get landingServices2Row3 => 'Pedicure Spa';

  @override
  String get landingServices2Row4 => 'Plástica dos pés + Pedicure';

  @override
  String get landingServices2Row5 => 'Esmaltação em gel · pés';

  @override
  String get landingServices2Note =>
      'Mini Spa: cuidado localizado de calosidades. Spa: esfoliação, hidratação e cuidado completo dos pés.';

  @override
  String get landingServices3Title => 'Alongamentos';

  @override
  String get landingServices3Subtitle => 'Gel, Polygel e Acrílico';

  @override
  String get landingServices3GroupNew => 'Nova aplicação';

  @override
  String get landingServices3GroupMaintenance => 'Manutenção';

  @override
  String get landingServices3RowShort => 'Curto';

  @override
  String get landingServices3RowMedium => 'Médio';

  @override
  String get landingServices3RowLong => 'Longo';

  @override
  String get landingServices3RowExtraLong => 'Extra longo';

  @override
  String get landingServices3Note =>
      'Mesmo preço por técnica; só varia o comprimento. O preço base inclui preparação, cutículas, estrutura, esmaltação em gel de uma cor e decoração simples em 1 unha. Manutenção até 30 dias.';

  @override
  String get landingServices4Subtitle => 'Praticidade e leveza';

  @override
  String get landingServices4Row1 => 'Curto / Médio';

  @override
  String get landingServices4Row2 => 'Longo';

  @override
  String get landingServices4Row3 => 'Manutenção / reaplicação · a partir de';

  @override
  String get landingServices4Note =>
      'Manutenção conforme o crescimento e o estado da estrutura.';

  @override
  String get landingServices5Title => 'Remoções';

  @override
  String get landingServices5Subtitle => 'Saúde da unha primeiro';

  @override
  String get landingServices5Row1 => 'Esmaltação em gel';

  @override
  String get landingServices5Row2 => 'Banho de gel';

  @override
  String get landingServices5Row3 => 'Alongamento';

  @override
  String get landingServices5Note =>
      'Remoção + nova aplicação no mesmo atendimento: R\$ 30.';

  @override
  String get landingServices6Title => 'Decoração e adicionais';

  @override
  String get landingServices6Subtitle => 'Detalhes que fazem a diferença';

  @override
  String get landingServices6Row1 => 'Francesinha elaborada';

  @override
  String get landingServices6Row2 => 'Cromado / olho de gato';

  @override
  String get landingServices6Row3 => 'Encapsulado';

  @override
  String get landingServices6Row4 => 'Nail art simples';

  @override
  String get landingServices6Row5 => 'Nail art intermediária';

  @override
  String get landingServices6Row6 => 'Nail art elaborada';

  @override
  String get landingServices6Row7 => 'Pedraria';

  @override
  String get landingServices6Note =>
      'Adesivos, composições com várias técnicas e desenhos personalizados são avaliados conforme quantidade de unhas, dificuldade e tempo.';

  @override
  String get landingCombosEyebrow => 'Vantagens';

  @override
  String get landingCombosNote =>
      'Os combos não são acumuláveis com outras promoções.';

  @override
  String get landingCombo1Name => 'Mãos e Pés Tradicional';

  @override
  String get landingCombo1Desc => 'Manicure tradicional + Pedicure tradicional';

  @override
  String get landingCombo2Name => 'Gel Completo';

  @override
  String get landingCombo2Desc => 'Esmaltação em gel mãos + pés';

  @override
  String get landingCombo3Name => 'Momento Shaddai';

  @override
  String get landingCombo3Desc => 'Manicure + Spa de mãos + Pedicure Spa';

  @override
  String get landingCatalogEyebrow => 'Material do estúdio';

  @override
  String get landingCatalogTitle => 'Catálogo de';

  @override
  String get landingCatalogTitleEm => 'serviços';

  @override
  String get landingCatalogNote =>
      'Toque para ampliar cada página do catálogo.';

  @override
  String get landingCatalogAltPortada =>
      'Studio Shaddai — Catálogo de serviços';

  @override
  String get landingCatalogAltAlongamentos => 'Alongamentos';

  @override
  String get landingCatalogAltSoftGel => 'Soft Gel';

  @override
  String get landingCatalogAltManutencion => 'Manutenção de unhas';

  @override
  String get landingCatalogAltDecoraciones => 'Decorações para unhas';

  @override
  String get landingCatalogAltCombos => 'Combos e pacotes especiais';

  @override
  String get landingCatalogAltNaturales => 'Unhas naturais';

  @override
  String get landingCatalogAltPies => 'Pés e cuidados especiais';

  @override
  String get landingCatalogAltAgendamiento => 'Agendamento de horários';

  @override
  String get landingCatalogMoreCta => 'Mais páginas do catálogo no Instagram';

  @override
  String get landingInfoEyebrow => 'Informação importante';

  @override
  String get landingInfoTitle => 'Como funciona o';

  @override
  String get landingInfoTitleEm => 'atendimento';

  @override
  String get landingInfoDesc =>
      'Regras simples para cuidar da estrutura das suas unhas — e do seu horário reservado.';

  @override
  String get landingInfoScript => 'Seu tempo também importa ♡';

  @override
  String get landingInfo1Title => 'Reposição';

  @override
  String get landingInfo1Body =>
      '1 unha durante a manutenção: incluída. A partir da 2ª unha: R\$ 5 cada. Fora da manutenção: R\$ 15.';

  @override
  String get landingInfo2Title => 'Prazo de manutenção';

  @override
  String get landingInfo2Body =>
      'As manutenções são realizadas até 30 dias. Após esse prazo, o serviço pode ser considerado nova aplicação conforme o crescimento, descolamentos e estado da estrutura.';

  @override
  String get landingInfo3Title => 'Atrasos';

  @override
  String get landingInfo3Body =>
      'Tolerância de 10 minutos. Depois, o horário pode ser adaptado ou reagendado para não afetar os horários seguintes.';

  @override
  String get landingInfo4Title => 'Cancelamentos';

  @override
  String get landingInfo4Body =>
      'Cancelamentos ou mudanças de horário: avisar com pelo menos 24 horas de antecedência. Atendimento sempre com horário reservado.';

  @override
  String get landingGalleryEyebrow => 'Meu trabalho';

  @override
  String get landingGalleryTitle => 'Galeria de';

  @override
  String get landingGalleryTitleEm => 'designs';

  @override
  String get landingGalleryMoreLink => 'Ver mais no Instagram →';

  @override
  String landingGalleryItemLabel(int n) {
    return 'Design $n — veja mais no Instagram';
  }

  @override
  String get landingAboutQuoteLabel => 'Em suas palavras';

  @override
  String get landingAboutQuote => '“A beleza também é cuidar de você.”';

  @override
  String get landingAboutEyebrow => 'Minha história';

  @override
  String get landingAboutTitle => 'Sou';

  @override
  String get landingAboutParagraph1 =>
      'Nail designer e apaixonada pela beleza. Por trás do Studio Shaddai há uma mulher que continua aprendendo, sonhando e crescendo a cada dia.';

  @override
  String get landingAboutParagraph2 =>
      'As redes mostram o resultado final, mas por trás de cada design há preparação, técnica e paixão pelo detalhe. Para mim, cada unha é uma oportunidade de criar algo bonito que também cuide da saúde das suas mãos.';

  @override
  String get landingAboutValue1 => 'Técnica com fundamento, não só tendência';

  @override
  String get landingAboutValue2 => 'Saúde da unha primeiro, sempre';

  @override
  String get landingAboutValue3 => 'Espaço higienizado, trabalho impecável';

  @override
  String get landingAboutValue4 => 'Atendimento em espanhol e português';

  @override
  String get landingContactEyebrow => 'Vamos conversar';

  @override
  String get landingContactTitle => 'Marque seu';

  @override
  String get landingContactTitleEm => 'horário';

  @override
  String get landingContactDesc =>
      'Pronta para ter as unhas que sempre quis? Me escreva e encontramos o momento perfeito para você.';

  @override
  String get landingContactCtaWhatsapp => 'Agende pelo WhatsApp ♡';

  @override
  String get landingContactPhoneLabel => 'Telefone';

  @override
  String get landingContactEmailLabel => 'E-mail';

  @override
  String get landingContactAddressLabel => 'Endereço';

  @override
  String get landingContactInstagramLabel => 'Instagram';

  @override
  String get landingFooterTagline => 'A beleza também é cuidar de você ♡';

  @override
  String get landingWhatsappFloatTitle => 'Agendar pelo WhatsApp';

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
  String get salonMapLabel => 'Mapa com a localização do estúdio';

  @override
  String get bookingSignInTitle => 'Entre para agendar';

  @override
  String get bookingSignInBody =>
      'Usamos sua conta Google para guardar seus horários e para que Beidis possa confirmá-los pelo WhatsApp.';

  @override
  String get pricesLoading => 'Carregando preços';

  @override
  String get pricesLoadError => 'Não foi possível carregar os preços.';

  @override
  String get pricesRetry => 'Tentar novamente';

  @override
  String get pricesEmpty => 'Consulte os preços pelo WhatsApp.';

  @override
  String priceFrom(String price) {
    return 'a partir de $price';
  }

  @override
  String get priceDetailOpenHint => 'Ver detalhes';

  @override
  String priceLineSemantics(String name, String price) {
    return '$name, $price';
  }

  @override
  String get pricesCatalogDisclaimer =>
      'Os preços vigentes são os da lista de preços.';

  @override
  String get priceDetailDuration => 'Duração';

  @override
  String get priceDetailBackToPrices => 'Voltar à lista de preços';

  @override
  String get priceDetailUnavailable => 'Este serviço não está mais disponível.';

  @override
  String get adminServicesTitle => 'Serviços';

  @override
  String get adminServicesEmpty => 'Ainda não há serviços.';

  @override
  String get adminServicesSeed => 'Carregar a lista de preços atual';

  @override
  String get adminServicesSeedConfirmTitle =>
      'Carregar a lista de preços atual?';

  @override
  String get adminServicesSeedConfirmBody =>
      'Serão criadas as categorias, serviços e combos de hoje. Depois você poderá editá-los.';

  @override
  String get adminServicesSeedConfirmAction => 'Carregar';

  @override
  String get adminServicesCombos => 'Combos';

  @override
  String get adminServicesSaved => 'Alterações salvas';

  @override
  String get adminServicesSaveError => 'Não foi possível salvar as alterações.';

  @override
  String get adminServicesHidden => 'Oculto';

  @override
  String get adminServicesMoveUp => 'Subir';

  @override
  String get adminServicesMoveDown => 'Descer';

  @override
  String get adminServicesHide => 'Ocultar';

  @override
  String get adminServicesShow => 'Mostrar';

  @override
  String get adminServicesDelete => 'Excluir';

  @override
  String adminServicesDeleteTitle(String name) {
    return 'Excluir «$name»?';
  }

  @override
  String get adminServicesDeleteBody => 'Não é possível desfazer.';

  @override
  String get adminServicesCategoryNotEmpty =>
      'Esta categoria tem serviços ou adicionais. Exclua-os ou mova-os para outra categoria antes de excluí-la.';

  @override
  String get adminServicesUnderstood => 'Entendi';

  @override
  String get adminServicesItemGone => 'Este item não existe mais.';

  @override
  String get adminServicesEdit => 'Editar';

  @override
  String get adminServicesAddCategory => 'Adicionar categoria';

  @override
  String get adminServicesNewCategory => 'Nova categoria';

  @override
  String get adminServicesEditCategory => 'Editar categoria';

  @override
  String get adminFieldNameEs => 'Nome em espanhol';

  @override
  String get adminFieldNamePt => 'Nome em português';

  @override
  String get adminFieldSubtitleEs => 'Subtítulo em espanhol';

  @override
  String get adminFieldSubtitlePt => 'Subtítulo em português';

  @override
  String get adminFieldNoteEs => 'Nota em espanhol';

  @override
  String get adminFieldNotePt => 'Nota em português';

  @override
  String get adminFieldRequired => 'Obrigatório';

  @override
  String get adminFieldMissingTranslation => 'Escreva também neste idioma';

  @override
  String get adminFieldInvalidPrice => 'Preço inválido (até 2 casas decimais)';

  @override
  String get adminFieldInvalidDuration => 'Entre 5 e 480 minutos';

  @override
  String adminFieldTooLong(int max) {
    return 'Máximo $max caracteres';
  }

  @override
  String get adminSave => 'Salvar';

  @override
  String get adminServicesAddService => 'Adicionar serviço';

  @override
  String get adminServicesAddAddon => 'Adicionar adicional';

  @override
  String get adminServicesNewService => 'Novo serviço';

  @override
  String get adminServicesEditService => 'Editar serviço';

  @override
  String get adminServicesNewAddon => 'Novo adicional';

  @override
  String get adminServicesEditAddon => 'Editar adicional';

  @override
  String get adminFieldDescriptionEs => 'Descrição em espanhol';

  @override
  String get adminFieldDescriptionPt => 'Descrição em português';

  @override
  String get adminFieldGroupEs => 'Grupo em espanhol';

  @override
  String get adminFieldGroupPt => 'Grupo em português';

  @override
  String get adminFieldPrice => 'Preço (R\$)';

  @override
  String get adminFieldPriceFrom => 'Preço «a partir de»';

  @override
  String get adminFieldDuration => 'Duração (minutos)';

  @override
  String get adminFieldCategory => 'Categoria';

  @override
  String get adminServicesAddCombo => 'Adicionar combo';

  @override
  String get adminServicesNewCombo => 'Novo combo';

  @override
  String get adminServicesEditCombo => 'Editar combo';
}
