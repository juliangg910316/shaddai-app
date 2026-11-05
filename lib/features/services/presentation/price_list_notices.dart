import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/external_links.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../landing/landing_content.dart';
import '../providers/price_list_provider.dart';

/// Indicador de carga de la lista de precios, con su etiqueta para el lector
/// de pantalla (spec 004, RF-7).
class PriceListLoadingIndicator extends StatelessWidget {
  const PriceListLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.brand.accentIcon,
          semanticsLabel: AppLocalizations.of(context)!.pricesLoading,
        ),
      ),
    );
  }
}

/// Aviso de que la lista no se pudo cargar, con "Reintentar", que vuelve a
/// escucharla, y "Agenda por WhatsApp" (RF-8, RF-9). Nunca muestra el error
/// técnico (RNF-6).
class PriceListUnavailableNotice extends ConsumerWidget {
  const PriceListUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppNotice(
      message: l10n.pricesLoadError,
      actions: [
        AppNoticeButton(
          label: l10n.pricesRetry,
          onPressed: () => ref.invalidate(priceListStateProvider),
        ),
        const WhatsappNoticeButton(),
      ],
    );
  }
}

/// Aviso de que los precios se consultan por WhatsApp, cuando no hay
/// ninguna categoría que mostrar (RF-10).
class PriceListEmptyNotice extends StatelessWidget {
  const PriceListEmptyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      message: AppLocalizations.of(context)!.pricesEmpty,
      actions: const [WhatsappNoticeButton()],
    );
  }
}

/// Aviso con un texto y sus botones, debajo o al lado según el ancho. Lo
/// comparten la lista de precios y la reserva (spec 005).
class AppNotice extends StatelessWidget {
  const AppNotice({super.key, required this.message, required this.actions});

  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: AppText.sans(size: 15, color: brand.ink, height: 1.6),
          ),
          const SizedBox(height: 16),
          // Con poco ancho o texto grande, uno debajo del otro.
          Wrap(spacing: 16, runSpacing: 12, children: actions),
        ],
      ),
    );
  }
}

/// Botón de un [AppNotice], de al menos 48 px.
class AppNoticeButton extends StatelessWidget {
  const AppNoticeButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: brand.ink,
        side: BorderSide(color: brand.inkMuted),
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 26),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.sans(size: 12, spacing: 1, color: brand.ink),
      ),
    );
  }
}

/// "Agenda por WhatsApp", como en la sección de contacto.
class WhatsappNoticeButton extends ConsumerWidget {
  const WhatsappNoticeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppNoticeButton(
      label: AppLocalizations.of(context)!.landingContactCtaWhatsapp,
      onPressed: () => ref.read(externalLinkLauncherProvider)(
        Uri.parse(LandingContent.whatsappUrl),
      ),
    );
  }
}
