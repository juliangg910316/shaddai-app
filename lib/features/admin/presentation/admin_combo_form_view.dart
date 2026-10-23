import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/price_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_form_logic.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../../services/providers/price_list_provider.dart';
import '../providers/admin_services_provider.dart';
import 'admin_price_item_form_view.dart' show priceCentsToInput;
import 'admin_services_widgets.dart';

/// Formulario de un combo: nombre y descripción en español y en portugués,
/// precio y duración (spec 004, RF-21 a RF-25, RF-33, RF-34). Con [comboId]
/// [newElementId] crea uno nuevo.
class AdminComboFormView extends ConsumerStatefulWidget {
  const AdminComboFormView({super.key, required this.comboId});

  final String comboId;

  @override
  ConsumerState<AdminComboFormView> createState() => _AdminComboFormViewState();
}

class _AdminComboFormViewState extends ConsumerState<AdminComboFormView> {
  final _nameEs = TextEditingController();
  final _namePt = TextEditingController();
  final _descriptionEs = TextEditingController();
  final _descriptionPt = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();

  /// Se rellena una sola vez, con la primera versión que llega (como en el
  /// formulario de categoría).
  var _filled = false;
  var _busy = false;
  PriceFormErrors _errors = const {};

  bool get _isNew => widget.comboId == newElementId;

  @override
  void dispose() {
    for (final controller in [
      _nameEs,
      _namePt,
      _descriptionEs,
      _descriptionPt,
      _price,
      _duration,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(ComboModel combo) {
    _nameEs.text = combo.name.es;
    _namePt.text = combo.name.pt;
    _descriptionEs.text = combo.description.es;
    _descriptionPt.text = combo.description.pt;
    _price.text = priceCentsToInput(combo.priceCents);
    _duration.text = '${combo.durationMinutes}';
    _filled = true;
  }

  BilingualText _text(TextEditingController es, TextEditingController pt) =>
      BilingualText(es: es.text.trim(), pt: pt.text.trim());

  Future<void> _save() async {
    final errors = validateCombo(
      PriceForm(
        nameEs: _nameEs.text,
        namePt: _namePt.text,
        descriptionEs: _descriptionEs.text,
        descriptionPt: _descriptionPt.text,
        price: _price.text,
        duration: _duration.text,
      ),
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final id = _isNew ? null : widget.comboId;
    final name = _text(_nameEs, _namePt);
    final description = _text(_descriptionEs, _descriptionPt);
    final priceCents = parsePriceCents(_price.text)!;
    final duration = parseDuration(_duration.text)!;
    final controller = ref.read(adminServicesControllerProvider);

    setState(() => _busy = true);
    await runAdminServicesAction(
      context,
      () => controller.saveCombo(
        id,
        name: name,
        description: description,
        priceCents: priceCents,
        durationMinutes: duration,
      ),
      onSaved: () => closeAdminServicesForm(context),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    Widget? notice;
    if (!_isNew && !_filled) {
      notice = switch (ref.watch(currentPriceListProvider)) {
        PriceListLoading() => const PriceListLoadingIndicator(),
        PriceListUnavailable() => const PriceListUnavailableNotice(),
        PriceListReady(:final list) => () {
          final combo = list.combos
              .where((c) => c.id == widget.comboId)
              .firstOrNull;
          if (combo == null) {
            return Text(
              l10n.adminServicesItemGone,
              style: AppText.sans(size: 15, color: brand.ink),
            );
          }
          _fill(combo);
          return null;
        }(),
      };
    }

    String? error(PriceFormField field, [int? maxLength]) =>
        adminFieldErrorText(l10n, _errors[field], maxLength: maxLength);

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(
        title: Text(
          _isNew ? l10n.adminServicesNewCombo : l10n.adminServicesEditCombo,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            notice ??
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminTextField(
                  controller: _nameEs,
                  label: l10n.adminFieldNameEs,
                  errorText: error(PriceFormField.nameEs, maxNameLength),
                ),
                AdminTextField(
                  controller: _namePt,
                  label: l10n.adminFieldNamePt,
                  errorText: error(PriceFormField.namePt, maxNameLength),
                ),
                AdminTextField(
                  controller: _descriptionEs,
                  label: l10n.adminFieldDescriptionEs,
                  multiline: true,
                  errorText: error(
                    PriceFormField.descriptionEs,
                    maxLongTextLength,
                  ),
                ),
                AdminTextField(
                  controller: _descriptionPt,
                  label: l10n.adminFieldDescriptionPt,
                  multiline: true,
                  errorText: error(
                    PriceFormField.descriptionPt,
                    maxLongTextLength,
                  ),
                ),
                AdminTextField(
                  controller: _price,
                  label: l10n.adminFieldPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: error(PriceFormField.price),
                ),
                AdminTextField(
                  controller: _duration,
                  label: l10n.adminFieldDuration,
                  keyboardType: TextInputType.number,
                  errorText: error(PriceFormField.duration),
                ),
                const SizedBox(height: 8),
                AdminFormActions(
                  onCancel: () => closeAdminServicesForm(context),
                  onSave: _busy ? null : _save,
                ),
              ],
            ),
      ),
    );
  }
}
