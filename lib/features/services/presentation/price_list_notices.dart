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

    return _Notice(
      message: l10n.pricesLoadError,
      actions: [
        _NoticeButton(
          label: l10n.pricesRetry,
          onPressed: () => ref.invalidate(priceListStateProvider),
        ),
        const _WhatsappButton(),
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
    return _Notice(
      message: AppLocalizations.of(context)!.pricesEmpty,
      actions: const [_WhatsappButton()],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.actions});

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

class _NoticeButton extends StatelessWidget {
  const _NoticeButton({required this.label, required this.onPressed});

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
class _WhatsappButton extends ConsumerWidget {
  const _WhatsappButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NoticeButton(
      label: AppLocalizations.of(context)!.landingContactCtaWhatsapp,
      onPressed: () => ref.read(externalLinkLauncherProvider)(
        Uri.parse(LandingContent.whatsappUrl),
      ),
    );
  }
}
