import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../landing/landing_section.dart';
import '../../landing/presentation/landing_navigation.dart';
import '../../landing/presentation/landing_page.dart';
import '../../landing/presentation/widgets/whatsapp_float_button.dart';
import '../../navigation/presentation/web_shell.dart';
import '../logic/price_list_view_logic.dart';
import '../providers/price_list_provider.dart';
import 'price_list_notices.dart';

/// Página de Web del detalle: centrada como las páginas de cuenta, sin pedir
/// sesión y con el botón flotante de WhatsApp de la landing (spec 004,
/// RF-43).
class WebPriceDetailPage extends ConsumerWidget {
  const WebPriceDetailPage({super.key, required this.kind, required this.id});

  final DetailKind? kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        WebAccountPage(
          child: PriceDetailView(kind: kind, id: id),
        ),
        if (ref.watch(showLandingFloatButtonProvider))
          Positioned(
            right: 24,
            bottom: 24,
            // En su propio grupo de foco, como en la landing.
            child: FocusTraversalGroup(child: const WhatsappFloatButton()),
          ),
      ],
    );
  }
}

/// Detalle de un servicio o combo, en vivo (RF-14 a RF-17). [kind] es `null`
/// si la dirección no es de un tipo de detalle conocido.
class PriceDetailView extends ConsumerWidget {
  const PriceDetailView({super.key, required this.kind, required this.id});

  final DetailKind? kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final isWeb = ref.watch(isWebProvider);
    final detailKind = kind;
    final view = detailKind == null
        ? const PriceViewReady<DetailResult>(DetailNotAvailable())
        : ref.watch(priceDetailProvider((detailKind, id)));

    final Widget content = switch (view) {
      PriceViewLoading() => const PriceListLoadingIndicator(),
      PriceViewUnavailable() => const PriceListUnavailableNotice(),
      PriceViewReady(:final value) => _DetailBody(result: value, isWeb: isWeb),
    };

    return Scaffold(
      backgroundColor: brand.background,
      appBar: isWeb ? null : AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
          child: content,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.result, required this.isWeb});

  final DetailResult result;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = l10n.localeName;
    final brand = context.brand;

    final (
      category,
      name,
      price,
      duration,
      description,
      note,
    ) = switch (result) {
      ServiceDetail(:final item, :final category) => (
        category.name.of(language),
        item.name.of(language),
        formatPrice(
          item.priceCents,
          from: item.priceFrom ? l10n.priceFrom : null,
        ),
        item.durationMinutes,
        item.description.of(language),
        category.note.of(language),
      ),
      ComboDetail(:final combo) => (
        null,
        combo.name.of(language),
        formatPrice(combo.priceCents),
        combo.durationMinutes,
        combo.description.of(language),
        '',
      ),
      DetailNotAvailable() => (null, null, null, null, null, null),
    };

    if (name == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.priceDetailUnavailable,
            style: AppText.sans(size: 16, color: brand.ink, height: 1.6),
          ),
          const SizedBox(height: 24),
          _BackToPricesButton(isWeb: isWeb),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category != null) ...[
          Text(
            category.toUpperCase(),
            style: AppText.eyebrow(
              size: 12,
              spacing: 1.5,
              weight: FontWeight.w600,
              color: brand.accentText,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(name, style: AppText.serif(size: 36, color: brand.ink)),
        const SizedBox(height: 16),
        Text(price!, style: AppText.serif(size: 28, color: brand.ink)),
        const SizedBox(height: 16),
        Text(
          l10n.priceDetailDuration,
          style: AppText.eyebrow(size: 11, spacing: 1, color: brand.inkMuted),
        ),
        const SizedBox(height: 2),
        Text(
          formatDuration(duration!),
          style: AppText.sans(size: 15, color: brand.ink),
        ),
        if (description!.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            description,
            style: AppText.sans(size: 15, color: brand.ink, height: 1.7),
          ),
        ],
        if (note!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            note,
            style: AppText.sans(size: 13, color: brand.inkMuted, height: 1.6),
          ),
        ],
        const SizedBox(height: 32),
        // Con poco ancho o texto grande, uno debajo del otro.
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            const _ReserveButton(),
            if (isWeb) _BackToPricesButton(isWeb: isWeb),
          ],
        ),
      ],
    );
  }
}

/// "Reservar cita": abre la reserva como el resto de botones "Reservar
/// cita" de cada plataforma (RF-16).
class _ReserveButton extends StatelessWidget {
  const _ReserveButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return ElevatedButton(
      onPressed: () => context.go('/booking'),
      style: ElevatedButton.styleFrom(
        // Verde sobre dorado: el mismo par en los dos temas (5,1:1).
        backgroundColor: brand.accent,
        foregroundColor: brand.brand,
        elevation: 0,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 26),
      ),
      child: Text(
        l10n.landingHeroCtaReserve.toUpperCase(),
        style: AppText.sans(
          size: 12,
          weight: FontWeight.w600,
          spacing: 1,
          color: brand.brand,
        ),
      ),
    );
  }
}

/// "Volver a la lista de precios" (RF-17, RF-44). En Web, la landing está
/// debajo del detalle (ruta hija, D-7), también si se abrió por su
/// dirección: se cierra el detalle y se lleva la landing a la lista. En
/// Android/iOS, vuelve a la pestaña Servicios.
class _BackToPricesButton extends StatelessWidget {
  const _BackToPricesButton({required this.isWeb});

  final bool isWeb;

  void _back(BuildContext context) {
    if (!isWeb) {
      context.go('/services');
      return;
    }
    if (!context.canPop()) {
      goToLandingSection(context, LandingSection.prices);
      return;
    }
    // La landing de debajo no se dibuja mientras el detalle la tapa: se
    // desplaza en el fotograma siguiente, cuando ya vuelve a verse.
    final router = GoRouter.of(context);
    context.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final landing = landingPageKey.currentState;
      if (landing != null && landing.mounted) {
        landing.scrollToSection(LandingSection.prices);
      } else {
        router.go('/?section=${LandingSection.prices.queryValue}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return OutlinedButton(
      onPressed: () => _back(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: brand.ink,
        side: BorderSide(color: brand.inkMuted),
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 26),
      ),
      child: Text(
        l10n.priceDetailBackToPrices.toUpperCase(),
        style: AppText.sans(size: 12, spacing: 1, color: brand.ink),
      ),
    );
  }
}
