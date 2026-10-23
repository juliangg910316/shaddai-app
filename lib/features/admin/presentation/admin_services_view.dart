import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/price_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_edit_logic.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../../services/providers/price_list_provider.dart';
import '../providers/admin_services_provider.dart';
import 'admin_services_widgets.dart';

/// Gestión de servicios y precios de la admin (spec 004, RF-19 a RF-39): la
/// carga inicial y la lista con sus acciones.
class AdminServicesView extends ConsumerWidget {
  const AdminServicesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final state = ref.watch(currentPriceListProvider);

    final Widget content = switch (state) {
      PriceListLoading() => const PriceListLoadingIndicator(),
      PriceListUnavailable() => const PriceListUnavailableNotice(),
      PriceListReady(:final list) when !list.hasContent => const _SeedPrompt(),
      PriceListReady(:final list) => _PriceListOverview(list: list),
    };

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(title: Text(l10n.adminServicesTitle)),
      body: SingleChildScrollView(
        // Margen inferior para que el último elemento pueda subir por encima
        // de un aviso (`SnackBar`) y sus botones se puedan pulsar.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        child: content,
      ),
    );
  }
}

/// Sin ningún elemento guardado: la carga inicial, con confirmación (RF-35,
/// RF-36).
class _SeedPrompt extends ConsumerStatefulWidget {
  const _SeedPrompt();

  @override
  ConsumerState<_SeedPrompt> createState() => _SeedPromptState();
}

class _SeedPromptState extends ConsumerState<_SeedPrompt> {
  var _busy = false;

  Future<void> _confirmAndSeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Textos leídos aquí dentro: el diálogo cambia de idioma si cambia
        // el de la app.
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.adminServicesSeedConfirmTitle),
          content: Text(l10n.adminServicesSeedConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.adminServicesSeedConfirmAction.toUpperCase()),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await _seed();
  }

  Future<void> _seed() async {
    setState(() => _busy = true);
    final result = await ref
        .read(adminServicesControllerProvider)
        .seedInitialList();
    if (!mounted) return;
    setState(() => _busy = false);

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      result == AdminServicesResult.ok
          ? SnackBar(content: Text(l10n.adminServicesSaved))
          : SnackBar(
              content: Text(l10n.adminServicesSaveError),
              action: SnackBarAction(
                label: l10n.pricesRetry.toUpperCase(),
                onPressed: _seed,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminServicesEmpty,
          style: AppText.sans(size: 15, color: brand.ink),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _confirmAndSeed,
          style: ElevatedButton.styleFrom(
            backgroundColor: brand.brand,
            foregroundColor: brand.onBrand,
            elevation: 0,
            minimumSize: const Size(48, 48),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Text(
            l10n.adminServicesSeed.toUpperCase(),
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w600,
              spacing: 1,
              color: brand.onBrand,
            ),
          ),
        ),
      ],
    );
  }
}

/// Categorías con sus servicios y adicionales, y los combos, en su orden,
/// también los ocultos (RF-20), con sus acciones: subir, bajar, ocultar o
/// mostrar y borrar (RF-26 a RF-31).
class _PriceListOverview extends ConsumerWidget {
  const _PriceListOverview({required this.list});

  final PriceListModel list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = l10n.localeName;
    final brand = context.brand;
    // Se lee al pulsar, no al construir: el controlador abre el calendario.
    AdminServicesController controller() =>
        ref.read(adminServicesControllerProvider);

    void run(Future<AdminServicesResult> Function() action) =>
        runAdminServicesAction(context, action);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: AppText.serif(size: 22, color: brand.ink)),
    );

    final categories = list.categories;
    final combos = list.combos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, category) in categories.indexed) ...[
          _AdminRow(
            id: category.id,
            title: Text(
              category.name.of(language),
              style: AppText.serif(size: 22, color: brand.ink),
            ),
            visible: category.visible,
            isFirst: index == 0,
            isLast: index == categories.length - 1,
            onEdit: () =>
                context.push('/admin/services/category/${category.id}'),
            onMove: (offset) =>
                run(() => controller().moveCategory(category.id, offset)),
            onToggleVisible: () => run(
              () => controller().setCategoryVisible(
                category.id,
                !category.visible,
              ),
            ),
            onDelete: () async {
              if (canDeleteCategory(list, category.id) ==
                  CategoryDeleteCheck.hasItems) {
                await _showCategoryNotEmpty(context);
                return;
              }
              if (await _confirmDelete(context, category.name) &&
                  context.mounted) {
                run(() => controller().deleteCategory(category.id));
              }
            },
          ),
          for (final (itemIndex, item) in category.items.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _AdminRow(
                id: item.id,
                title: Text(
                  item.name.of(language),
                  style: AppText.sans(size: 14, color: brand.ink),
                ),
                price: formatPrice(
                  item.priceCents,
                  addon: !item.isService,
                  from: item.isService && item.priceFrom
                      ? l10n.priceFrom
                      : null,
                ),
                visible: item.visible,
                isFirst: itemIndex == 0,
                isLast: itemIndex == category.items.length - 1,
                onEdit: () => context.push(
                  '/admin/services/category/${category.id}/item/${item.id}',
                ),
                onMove: (offset) =>
                    run(() => controller().moveItem(item.id, offset)),
                onToggleVisible: () => run(
                  () => controller().setItemVisible(item.id, !item.visible),
                ),
                onDelete: () async {
                  if (await _confirmDelete(context, item.name) &&
                      context.mounted) {
                    run(() => controller().deleteItem(item.id));
                  }
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              children: [
                for (final kind in PriceItemKind.values)
                  _AddButton(
                    key: ValueKey(
                      'admin-services-add-${kind.name}-${category.id}',
                    ),
                    label: kind == PriceItemKind.service
                        ? l10n.adminServicesAddService
                        : l10n.adminServicesAddAddon,
                    onPressed: () => context.push(
                      '/admin/services/category/${category.id}/item/'
                      '$newElementId?kind=${kind.name}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _AddButton(
            label: l10n.adminServicesAddCategory,
            onPressed: () =>
                context.push('/admin/services/category/$newElementId'),
          ),
        ),
        // Siempre visible, también sin combos, para poder añadir el primero.
        heading(l10n.adminServicesCombos),
        for (final (index, combo) in combos.indexed)
          _AdminRow(
            id: combo.id,
            title: Text(
              combo.name.of(language),
              style: AppText.sans(size: 14, color: brand.ink),
            ),
            price: formatPrice(combo.priceCents),
            visible: combo.visible,
            isFirst: index == 0,
            isLast: index == combos.length - 1,
            onEdit: () => context.push('/admin/services/combo/${combo.id}'),
            onMove: (offset) =>
                run(() => controller().moveCombo(combo.id, offset)),
            onToggleVisible: () => run(
              () => controller().setComboVisible(combo.id, !combo.visible),
            ),
            onDelete: () async {
              if (await _confirmDelete(context, combo.name) &&
                  context.mounted) {
                run(() => controller().deleteCombo(combo.id));
              }
            },
          ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _AddButton(
            label: l10n.adminServicesAddCombo,
            onPressed: () =>
                context.push('/admin/services/combo/$newElementId'),
          ),
        ),
      ],
    );
  }
}

/// Confirmación de borrado con el nombre en el idioma activo (RF-29, RF-31).
Future<bool> _confirmDelete(BuildContext context, BilingualText name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      // Textos leídos aquí dentro: el diálogo cambia de idioma si cambia el
      // de la app.
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.adminServicesDeleteTitle(name.of(l10n.localeName))),
        content: Text(l10n.adminServicesDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adminServicesDelete.toUpperCase()),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Una categoría con elementos no se borra: solo se informa (RF-30).
Future<void> _showCategoryNotEmpty(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Text(l10n.adminServicesCategoryNotEmpty),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminServicesUnderstood.toUpperCase()),
        ),
      ],
    );
  },
);

/// Una categoría, servicio, adicional o combo de la gestión: su nombre, su
/// precio, la etiqueta "Oculto" si lo está (RF-20) y sus acciones, debajo
/// para que quepan también con el texto grande (RNF-4).
class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.id,
    required this.title,
    this.price,
    required this.visible,
    required this.isFirst,
    required this.isLast,
    this.onEdit,
    required this.onMove,
    required this.onToggleVisible,
    required this.onDelete,
  });

  final String id;
  final Widget title;
  final String? price;
  final bool visible;
  final bool isFirst;
  final bool isLast;

  /// Abre su formulario.
  final VoidCallback? onEdit;
  final void Function(int offset) onMove;
  final VoidCallback onToggleVisible;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    Widget action(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          color: brand.ink,
          onPressed: onPressed,
        );

    return Padding(
      key: ValueKey('admin-services-row-$id'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              title,
              if (price != null)
                Text(price!, style: AppText.sans(size: 14, color: brand.ink)),
              if (!visible)
                Text(
                  l10n.adminServicesHidden,
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    spacing: 1,
                    color: brand.inkMuted,
                  ),
                ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (onEdit != null)
                action(Icons.edit_outlined, l10n.adminServicesEdit, onEdit),
              action(
                Icons.arrow_upward,
                l10n.adminServicesMoveUp,
                isFirst ? null : () => onMove(-1),
              ),
              action(
                Icons.arrow_downward,
                l10n.adminServicesMoveDown,
                isLast ? null : () => onMove(1),
              ),
              action(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                visible ? l10n.adminServicesHide : l10n.adminServicesShow,
                onToggleVisible,
              ),
              action(Icons.delete_outline, l10n.adminServicesDelete, onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Añadir …" de la gestión (RF-21).
class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(
        label.toUpperCase(),
        style: AppText.sans(
          size: 12,
          weight: FontWeight.w600,
          spacing: 1,
          color: brand.ink,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: brand.ink,
        minimumSize: const Size(48, 48),
      ),
    );
  }
}
