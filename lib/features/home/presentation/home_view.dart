import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_colors.dart';
import '../../landing/presentation/sections/about_section.dart';
import '../../landing/presentation/sections/contact_section.dart';
import '../../landing/presentation/sections/gallery_section.dart';
import '../../landing/presentation/sections/hero_section.dart';
import '../../navigation/providers/tab_scroll_provider.dart';
import 'google_map_container.dart';

/// Pestaña Inicio de Android/iOS: presentación, galería, sobre mí y contacto,
/// con el mismo contenido que la landing de Web (spec 003, RF-5, RF-21).
class HomeView extends ConsumerWidget {
  const HomeView({super.key, this.map});

  /// Mapa de la ubicación. Sin él, el de [salonMapProvider].
  final Widget? map;

  /// "Ver lista de precios": Servicios, desde su comienzo (RF-7).
  void _openPrices(BuildContext context, WidgetRef ref) {
    final services = ref.read(tabScrollControllerProvider(MobileTab.services));
    if (services.hasClients) services.jumpTo(0);
    context.go('/services');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget salonMap = map ?? ref.watch(salonMapProvider);

    return Scaffold(
      backgroundColor: context.brand.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: ref.watch(tabScrollControllerProvider(MobileTab.home)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroSection(onPricesTap: () => _openPrices(context, ref)),
              const GallerySection(),
              const AboutSection(),
              ContactSection(map: salonMap, showSocialLinks: true),
            ],
          ),
        ),
      ),
    );
  }
}
