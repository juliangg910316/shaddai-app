import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';

/// Si la landing muestra el botón flotante. Siempre `true` en la app; los
/// tests de contraste lo apagan, porque el botón, opaco, tapa el texto que
/// pasa por debajo y la guía de contraste lo mediría como texto ilegible.
final showLandingFloatButtonProvider = Provider<bool>((ref) => true);

/// Botón flotante de WhatsApp, siempre visible sobre la landing (RF-11, RF-12).
///
/// Va con los colores de la marca (dorado sobre verde, ≥ 4,5:1) y no con el
/// verde de WhatsApp: el icono blanco sobre ese verde no llega a 3:1 (RNF-1).
class WhatsappFloatButton extends ConsumerWidget {
  const WhatsappFloatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return FloatingActionButton(
      tooltip: l10n.landingWhatsappFloatTitle,
      onPressed: () => ref.read(externalLinkLauncherProvider)(
        Uri.parse(LandingContent.whatsappUrl),
      ),
      backgroundColor: brand.brand,
      foregroundColor: brand.onBrand,
      shape: const CircleBorder(),
      child: WhatsAppIcon(size: 28, color: brand.onBrand),
    );
  }
}
