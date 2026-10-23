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
import 'admin_services_widgets.dart';

/// El precio en céntimos como se escribe en el campo: "30" o "30,50".
String priceCentsToInput(int cents) {
  final units = cents ~/ 100;
  final rest = cents % 100;
  return rest == 0 ? '$units' : '$units,${rest.toString().padLeft(2, '0')}';
}

/// Formulario de un servicio o de un adicional (spec 004, RF-21 a RF-25,
/// RF-32 a RF-34). Con [itemId] `new` crea uno de tipo [kind] en
/// [categoryId]; si no, edita el elemento, sea del tipo que sea.
class AdminPriceItemFormView extends ConsumerStatefulWidget {
  const AdminPriceItemFormView({
    super.key,
    required this.categoryId,
    required this.itemId,
    this.kind = PriceItemKind.service,
  });

  final String categoryId;
  final String itemId;
  final PriceItemKind kind;

  @override
  ConsumerState<AdminPriceItemFormView> createState() =>
      _AdminPriceItemFormViewState();
}

class _AdminPriceItemFormViewState
    extends ConsumerState<AdminPriceItemFormView> {
  final _nameEs = TextEditingController();
  final _namePt = TextEditingController();
  final _descriptionEs = TextEditingController();
  final _descriptionPt = TextEditingController();
  final _groupEs = TextEditingController();
  final _groupPt = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();

  /// Se rellena una sola vez, con la primera versión que llega (como en el
  /// formulario de categoría).
  var _filled = false;
  var _busy = false;
  late PriceItemKind _kind = widget.kind;
  late String _categoryId = widget.categoryId;
  var _priceFrom = false;
  PriceFormErrors _errors = const {};

  bool get _isNew => widget.itemId == newElementId;
  bool get _isService => _kind == PriceItemKind.service;

  @override
  void dispose() {
    for (final controller in [
      _nameEs,
      _namePt,
      _descriptionEs,
      _descriptionPt,
      _groupEs,
      _groupPt,
      _price,
      _duration,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(PriceCategoryModel category, PriceItemModel item) {
    _kind = item.kind;
    _categoryId = category.id;
    _nameEs.text = item.name.es;
    _namePt.text = item.name.pt;
    _descriptionEs.text = item.description.es;
    _descriptionPt.text = item.description.pt;
    _groupEs.text = item.group.es;
    _groupPt.text = item.group.pt;
    _price.text = priceCentsToInput(item.priceCents);
    _duration.text = '${item.durationMinutes}';
    _priceFrom = item.priceFrom;
  }

  BilingualText _text(TextEditingController es, TextEditingController pt) =>
      BilingualText(es: es.text.trim(), pt: pt.text.trim());

  Future<void> _save() async {
    final form = PriceForm(
      nameEs: _nameEs.text,
      namePt: _namePt.text,
      descriptionEs: _descriptionEs.text,
      descriptionPt: _descriptionPt.text,
      groupEs: _groupEs.text,
      groupPt: _groupPt.text,
      price: _price.text,
      duration: _duration.text,
    );
    final errors = _isService ? validateService(form) : validateAddon(form);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final id = _isNew ? null : widget.itemId;
    final categoryId = _categoryId;
    final kind = _kind;
    final name = _text(_nameEs, _namePt);
    final description = _text(_descriptionEs, _descriptionPt);
    final group = _text(_groupEs, _groupPt);
    final priceCents = parsePriceCents(_price.text)!;
    final priceFrom = _priceFrom;
    final duration = _isService
        ? parseDuration(_duration.text)!
        : defaultDurationMinutes;
    final controller = ref.read(adminServicesControllerProvider);

    setState(() => _busy = true);
    await runAdminServicesAction(
      context,
      () => controller.saveItem(
        id,
        categoryId: categoryId,
        kind: kind,
        name: name,
        description: description,
        group: group,
        priceCents: priceCents,
        priceFrom: priceFrom,
        durationMinutes: duration,
      ),
      onSaved: () => closeAdminServicesForm(context),
    );
    if (mounted) setState(() => _busy = false);
  }

  /// El aviso que sustituye al formulario mientras no hay datos, o `null`.
  /// Al llegar los datos la primera vez, rellena los campos.
  Widget? _notice(AppLocalizations l10n, PriceListState state) {
    final gone = Text(
      l10n.adminServicesItemGone,
      style: AppText.sans(size: 15, color: context.brand.ink),
    );
    switch (state) {
      case PriceListLoading():
        return const PriceListLoadingIndicator();
      case PriceListUnavailable():
        return const PriceListUnavailableNotice();
      case PriceListReady(:final list):
        if (_isNew) {
          final exists = list.categories.any((c) => c.id == _categoryId);
          if (!exists) return gone;
        } else {
          for (final category in list.categories) {
            for (final item in category.items) {
              if (item.id == widget.itemId) {
                _fill(category, item);
                _filled = true;
                return null;
              }
            }
          }
          return gone;
        }
        _filled = true;
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final state = ref.watch(currentPriceListProvider);
    final notice = _filled ? null : _notice(l10n, state);
    final categories = switch (state) {
      PriceListReady(:final list) => list.categories,
      _ => const <PriceCategoryModel>[],
    };

    String? error(PriceFormField field, [int? maxLength]) =>
        adminFieldErrorText(l10n, _errors[field], maxLength: maxLength);

    final title = switch ((_isNew, _isService)) {
      (true, true) => l10n.adminServicesNewService,
      (false, true) => l10n.adminServicesEditService,
      (true, false) => l10n.adminServicesNewAddon,
      (false, false) => l10n.adminServicesEditAddon,
    };

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            notice ??
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // La categoría a la que pertenece; al cambiarla, va al
                // final de la nueva (RF-32).
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.adminFieldCategory,
                    ),
                    style: AppText.sans(size: 16, color: brand.inkStrong),
                    dropdownColor: brand.surface,
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.name.of(l10n.localeName),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) setState(() => _categoryId = id);
                    },
                  ),
                ),
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
                if (_isService) ...[
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
                    controller: _groupEs,
                    label: l10n.adminFieldGroupEs,
                    errorText: error(PriceFormField.groupEs, maxGroupLength),
                  ),
                  AdminTextField(
                    controller: _groupPt,
                    label: l10n.adminFieldGroupPt,
                    errorText: error(PriceFormField.groupPt, maxGroupLength),
                  ),
                ],
                AdminTextField(
                  controller: _price,
                  label: l10n.adminFieldPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: error(PriceFormField.price),
                ),
                if (_isService) ...[
                  CheckboxListTile(
                    value: _priceFrom,
                    onChanged: (value) =>
                        setState(() => _priceFrom = value ?? false),
                    title: Text(
                      l10n.adminFieldPriceFrom,
                      style: AppText.sans(size: 15, color: brand.ink),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  AdminTextField(
                    controller: _duration,
                    label: l10n.adminFieldDuration,
                    keyboardType: TextInputType.number,
                    errorText: error(PriceFormField.duration),
                  ),
                ],
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
