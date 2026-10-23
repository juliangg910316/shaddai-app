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

/// Formulario de una categoría: nombre, subtítulo y nota en español y en
/// portugués (spec 004, RF-21 a RF-23, RF-33, RF-34). Con [categoryId]
/// [newElementId] crea una nueva.
class AdminCategoryFormView extends ConsumerStatefulWidget {
  const AdminCategoryFormView({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<AdminCategoryFormView> createState() =>
      _AdminCategoryFormViewState();
}

class _AdminCategoryFormViewState extends ConsumerState<AdminCategoryFormView> {
  final _nameEs = TextEditingController();
  final _namePt = TextEditingController();
  final _subtitleEs = TextEditingController();
  final _subtitlePt = TextEditingController();
  final _noteEs = TextEditingController();
  final _notePt = TextEditingController();

  /// Los campos se rellenan una sola vez, con la primera versión que llega:
  /// un cambio posterior en la base de datos no pisa lo que se está
  /// escribiendo.
  var _filled = false;
  var _busy = false;
  PriceFormErrors _errors = const {};

  bool get _isNew => widget.categoryId == newElementId;

  @override
  void dispose() {
    for (final controller in [
      _nameEs,
      _namePt,
      _subtitleEs,
      _subtitlePt,
      _noteEs,
      _notePt,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(PriceCategoryModel category) {
    _nameEs.text = category.name.es;
    _namePt.text = category.name.pt;
    _subtitleEs.text = category.subtitle.es;
    _subtitlePt.text = category.subtitle.pt;
    _noteEs.text = category.note.es;
    _notePt.text = category.note.pt;
    _filled = true;
  }

  BilingualText _text(TextEditingController es, TextEditingController pt) =>
      BilingualText(es: es.text.trim(), pt: pt.text.trim());

  Future<void> _save() async {
    final errors = validateCategory(
      PriceForm(
        nameEs: _nameEs.text,
        namePt: _namePt.text,
        subtitleEs: _subtitleEs.text,
        subtitlePt: _subtitlePt.text,
        noteEs: _noteEs.text,
        notePt: _notePt.text,
      ),
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final name = _text(_nameEs, _namePt);
    final subtitle = _text(_subtitleEs, _subtitlePt);
    final note = _text(_noteEs, _notePt);
    final id = _isNew ? null : widget.categoryId;
    final controller = ref.read(adminServicesControllerProvider);
    // Una categoría nueva lleva un id nuevo en cada intento: si el primero
    // falla, el reintento no la duplica, porque no se guardó nada.
    setState(() => _busy = true);
    await runAdminServicesAction(
      context,
      () => controller.saveCategory(
        id,
        name: name,
        subtitle: subtitle,
        note: note,
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
          final category = list.categories
              .where((c) => c.id == widget.categoryId)
              .firstOrNull;
          if (category == null) {
            return Text(
              l10n.adminServicesItemGone,
              style: AppText.sans(size: 15, color: brand.ink),
            );
          }
          _fill(category);
          return null;
        }(),
      };
    }

    String? error(PriceFormField field, int maxLength) =>
        adminFieldErrorText(l10n, _errors[field], maxLength: maxLength);

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(
        title: Text(
          _isNew
              ? l10n.adminServicesNewCategory
              : l10n.adminServicesEditCategory,
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
                  controller: _subtitleEs,
                  label: l10n.adminFieldSubtitleEs,
                  errorText: error(
                    PriceFormField.subtitleEs,
                    maxSubtitleLength,
                  ),
                ),
                AdminTextField(
                  controller: _subtitlePt,
                  label: l10n.adminFieldSubtitlePt,
                  errorText: error(
                    PriceFormField.subtitlePt,
                    maxSubtitleLength,
                  ),
                ),
                AdminTextField(
                  controller: _noteEs,
                  label: l10n.adminFieldNoteEs,
                  multiline: true,
                  errorText: error(PriceFormField.noteEs, maxLongTextLength),
                ),
                AdminTextField(
                  controller: _notePt,
                  label: l10n.adminFieldNotePt,
                  multiline: true,
                  errorText: error(PriceFormField.notePt, maxLongTextLength),
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
