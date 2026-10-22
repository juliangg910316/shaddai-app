import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../landing/presentation/sections/catalog_section.dart';
import '../../landing/presentation/sections/combos_section.dart';
import '../../landing/presentation/sections/info_section.dart';
import '../../landing/presentation/sections/prices_section.dart';
import '../../navigation/providers/tab_scroll_provider.dart';

/// Pestaña Servicios de Android/iOS: "Reservar cita", la lista de precios, los
/// combos, el catálogo y cómo funciona la atención, con el mismo contenido
/// que la landing de Web (spec 003, RF-12, RF-15, RF-21).
class ServicesView extends ConsumerWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: ref.watch(
            tabScrollControllerProvider(MobileTab.services),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReserveBar(),
              PricesSection(),
              CombosSection(),
              CatalogSection(),
              InfoSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Reservar cita", arriba de la lista de precios: abre la pestaña Reservas
/// (RF-15).
class _ReserveBar extends StatelessWidget {
  const _ReserveBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return ColoredBox(
      color: brand.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
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
          ),
        ),
      ),
    );
  }
}
