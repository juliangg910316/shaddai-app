import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/providers/admin_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/recipient.dart';
import '../logic/salon_time.dart';
import '../providers/admin_booking_provider.dart';
import 'booking_section_title.dart';

/// "Para quién" de la reserva de la admin (spec 007, RF-1 a RF-11): la
/// búsqueda de clientas con cuenta, la clienta elegida o la persona sin
/// cuenta.
///
/// Con [showErrors] (tras tocar "Agendar turno"), marca los campos de la
/// persona sin cuenta que impiden agendar (RF-9).
class RecipientPicker extends ConsumerStatefulWidget {
  const RecipientPicker({super.key, this.showErrors = false});

  final bool showErrors;

  @override
  ConsumerState<RecipientPicker> createState() => _RecipientPickerState();
}

class _RecipientPickerState extends ConsumerState<RecipientPicker> {
  /// Empieza con la búsqueda guardada: se conserva al volver a la reserva
  /// (RF-27). Se crea en [initState], no al usarla: si "Para quién" se monta
  /// con la persona sin cuenta, la primera vez sería en [dispose], donde ya
  /// no se puede leer `ref`.
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: ref.read(bookingRecipientProvider).query,
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  RecipientController get _controller =>
      ref.read(bookingRecipientProvider.notifier);

  void _choose(UserModel user) {
    _query.clear();
    _controller.chooseAccount(user);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recipient = ref.watch(
      bookingRecipientProvider.select((s) => s.recipient),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingSectionTitle(l10n.bookingStepRecipient),
        const SizedBox(height: 12),
        ...switch (recipient) {
          null => _search(context),
          AccountRecipient() => [_ChosenClient(recipient: recipient)],
          GuestRecipient() => [
            _GuestForm(guest: recipient, showErrors: widget.showErrors),
            const SizedBox(height: 12),
            OutlinePillButton(
              label: l10n.bookingRecipientSearchAction.toUpperCase(),
              onPressed: _controller.clear,
            ),
          ],
        },
        if (recipient != null) const _ActiveAppointmentWarning(),
      ],
    );
  }

  /// La búsqueda, sus resultados y "Persona sin cuenta" (RF-3 a RF-6).
  List<Widget> _search(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final query = ref.watch(bookingRecipientProvider.select((s) => s.query));
    final results = ref.watch(recipientSearchProvider);
    final searching = query.trim().length >= recipientSearchMinLength;

    final Widget body;
    if (results.hasError) {
      // Sin las fichas, se puede seguir con una persona sin cuenta (RF-6).
      body = AppNotice(
        message: l10n.bookingRecipientLoadError,
        actions: [
          AppNoticeButton(
            label: l10n.bookingRetry,
            onPressed: () => ref.invalidate(adminUsersProvider),
          ),
        ],
      );
    } else if (!searching) {
      body = Text(
        l10n.bookingRecipientSearchHint,
        style: AppText.sans(size: 13, color: brand.inkMuted),
      );
    } else if (results.value case final found?) {
      body = found.isEmpty
          ? Text(
              l10n.bookingRecipientNoResults,
              style: AppText.sans(size: 15, color: brand.ink, height: 1.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final user in found)
                  _ClientRow(user: user, onTap: () => _choose(user)),
              ],
            );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return [
      TextField(
        controller: _query,
        cursorColor: brand.accentIcon,
        style: AppText.sans(size: 16, color: brand.inkStrong),
        decoration: InputDecoration(
          labelText: l10n.bookingRecipientSearchLabel,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: _controller.setQuery,
      ),
      const SizedBox(height: 8),
      body,
      const SizedBox(height: 12),
      OutlinePillButton(
        label: l10n.bookingRecipientGuestAction.toUpperCase(),
        onPressed: _controller.startGuest,
      ),
    ];
  }
}

/// Una clienta de los resultados: avatar, nombre y WhatsApp, de al menos
/// 48 px (RF-3; RNF-2).
class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = user.phoneNumber ?? '';
    // El nombre y el WhatsApp, en una sola frase para el lector de pantalla.
    final spoken = [user.displayName, phone].join(', ');

    return Semantics(
      container: true,
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                InitialsAvatar(
                  photoUrl: user.photoUrl,
                  name: user.displayName,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NameAndPhone(name: user.displayName, phone: phone),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameAndPhone extends StatelessWidget {
  const _NameAndPhone({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: AppText.sans(
            size: 15,
            weight: FontWeight.w500,
            color: brand.inkStrong,
          ),
        ),
        const SizedBox(height: 2),
        Text(phone, style: AppText.sans(size: 13, color: brand.inkMuted)),
      ],
    );
  }
}

/// La clienta elegida, con "Cambiar" para volver a buscar.
class _ChosenClient extends ConsumerWidget {
  const _ChosenClient({required this.recipient});

  final AccountRecipient recipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return FlatCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InitialsAvatar(
                photoUrl: recipient.photoUrl,
                name: recipient.name,
                size: 36,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _NameAndPhone(
                  name: recipient.name,
                  phone: recipient.phone,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: ref.read(bookingRecipientProvider.notifier).clear,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              l10n.bookingRecipientChange.toUpperCase(),
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w600,
                spacing: 1.2,
                color: brand.inkStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La persona elegida ya tiene un turno activo: su fecha, su hora y lo
/// reservado (RF-14).
class _ActiveAppointmentWarning extends ConsumerWidget {
  const _ActiveAppointmentWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(recipientActiveAppointmentProvider);
    if (active == null) return const SizedBox.shrink();
    final brand = context.brand;

    // Se anuncia al aparecer, en su propio nodo (RNF-2).
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: brand.danger, width: 1.5),
          ),
          child: Text(
            activeAppointmentMessage(AppLocalizations.of(context)!, active),
            style: AppText.sans(
              size: 14,
              weight: FontWeight.w500,
              color: brand.danger,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// El aviso del turno activo de la persona (RF-14), en el idioma activo.
String activeAppointmentMessage(
  AppLocalizations l10n,
  AppointmentModel appointment,
) {
  final locale = l10n.localeName;
  final start = toSalon(appointment.startTime);
  final booked = appointment.booked;
  return l10n.bookingRecipientActive(
    DateFormat.yMMMMEEEEd(locale).format(start),
    DateFormat.Hm(locale).format(start),
    [
      if (booked != null) booked.name.of(locale),
      for (final addon in booked?.addons ?? const []) addon.name.of(locale),
    ].join(', '),
  );
}

/// Los datos de la persona sin cuenta: nombre, WhatsApp y la casilla de
/// consentimiento (RF-7 a RF-9). Al salir del WhatsApp, avisa si es el de
/// una clienta con cuenta (RF-10) o el de una bloqueada (RF-11).
class _GuestForm extends ConsumerStatefulWidget {
  const _GuestForm({required this.guest, required this.showErrors});

  final GuestRecipient guest;
  final bool showErrors;

  @override
  ConsumerState<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends ConsumerState<_GuestForm> {
  // Empiezan con lo guardado: se conserva al volver a la reserva (RF-27).
  late final _name = TextEditingController(text: widget.guest.name);
  late final _phone = TextEditingController(text: widget.guest.phone);
  final _phoneFocus = FocusNode();

  /// El WhatsApp con el que se salió del campo, o `null` si se cambió
  /// después: solo entonces se busca su cuenta (RF-10).
  String? _checkedPhone;

  /// La admin eligió "Seguir sin cuenta" para [_checkedPhone].
  bool _keepGuest = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_onPhoneFocus);
    // Al volver a montarse (la lista lo quitó al desplazarse), el WhatsApp
    // guardado ya se escribió y se dejó: se vuelve a comprobar (RF-10).
    if (widget.guest.phone.trim().isNotEmpty) {
      _checkedPhone = widget.guest.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  RecipientController get _controller =>
      ref.read(bookingRecipientProvider.notifier);

  void _onPhoneFocus() {
    if (_phoneFocus.hasFocus || _phone.text.trim().isEmpty) return;
    setState(() {
      _checkedPhone = _phone.text;
      _keepGuest = false;
    });
    final match = _match();
    if (match == null) return;
    final l10n = AppLocalizations.of(context)!;
    SemanticsService.sendAnnouncement(
      View.of(context),
      match.isBlocked
          ? l10n.bookingGuestPhoneBlocked
          : l10n.bookingGuestPhoneHasAccount(match.displayName),
      Directionality.of(context),
    );
  }

  /// La clienta con cuenta del WhatsApp comprobado, o `null`.
  UserModel? _match() {
    final phone = _checkedPhone;
    final users = ref.read(adminUsersProvider).value;
    if (phone == null || users == null) return null;
    return accountWithPhone(users, phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    // Vuelve a mirar las fichas si cambian (por ejemplo, la bloquean).
    ref.watch(adminUsersProvider);
    final match = _match();
    final errors = widget.showErrors
        ? guestErrors(widget.guest)
        : const <GuestField>{};
    final blocked = match != null && match.isBlocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          cursorColor: brand.accentIcon,
          style: AppText.sans(size: 16, color: brand.inkStrong),
          textCapitalization: TextCapitalization.words,
          maxLength: guestNameMaxLength,
          // Deja escribir de más para poder avisar (RF-9).
          maxLengthEnforcement: MaxLengthEnforcement.none,
          decoration: InputDecoration(
            labelText: l10n.bookingGuestNameLabel,
            errorStyle: _errorStyle(brand),
            errorText: errors.contains(GuestField.name)
                ? l10n.bookingGuestNameError
                : null,
          ),
          onChanged: (name) => _controller.updateGuest(name: name),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          cursorColor: brand.accentIcon,
          style: AppText.sans(size: 16, color: brand.inkStrong),
          decoration: InputDecoration(
            labelText: l10n.bookingGuestPhoneLabel,
            errorStyle: _errorStyle(brand),
            errorText: blocked
                ? l10n.bookingGuestPhoneBlocked
                : errors.contains(GuestField.phone)
                ? l10n.bookingGuestPhoneError
                : null,
            errorMaxLines: 3,
          ),
          onChanged: (phone) {
            if (_checkedPhone != null) setState(() => _checkedPhone = null);
            _controller.updateGuest(phone: phone);
          },
        ),
        if (match != null && !blocked && !_keepGuest)
          Semantics(
            container: true,
            liveRegion: true,
            child: AppNotice(
              message: l10n.bookingGuestPhoneHasAccount(match.displayName),
              actions: [
                AppNoticeButton(
                  label: l10n.bookingGuestChooseAccount(match.displayName),
                  onPressed: () => _controller.chooseAccount(match),
                ),
                AppNoticeButton(
                  label: l10n.bookingGuestKeepGuest,
                  onPressed: () => setState(() => _keepGuest = true),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: widget.guest.consent,
          onChanged: (value) => _controller.updateGuest(consent: value),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: brand.brand,
          checkColor: brand.onBrand,
          title: Text(
            l10n.bookingGuestConsent,
            style: AppText.sans(size: 14, color: brand.ink, height: 1.4),
          ),
        ),
        if (errors.contains(GuestField.consent))
          Text(
            l10n.bookingGuestConsentError,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w500,
              color: brand.danger,
            ),
          ),
      ],
    );
  }
}

/// Los errores de los campos, en el color de peligro de la marca: el rojo
/// por defecto no llega a AA sobre el fondo (RNF-2).
TextStyle _errorStyle(BrandColors brand) =>
    AppText.sans(size: 12, weight: FontWeight.w500, color: brand.danger);
