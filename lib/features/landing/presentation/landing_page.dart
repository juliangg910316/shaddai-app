import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_colors.dart';
import '../landing_section.dart';
import 'sections/about_section.dart';
import 'sections/catalog_section.dart';
import 'sections/combos_section.dart';
import 'sections/contact_section.dart';
import 'sections/footer_section.dart';
import 'sections/gallery_section.dart';
import 'sections/hero_section.dart';
import 'sections/info_section.dart';
import 'sections/marquee_strip.dart';
import 'sections/prices_section.dart';
import 'widgets/whatsapp_float_button.dart';

/// Clave de la landing montada: la barra superior la usa para desplazarla sin
/// cambiar de página (plan § 4).
final landingPageKey = GlobalKey<LandingPageState>();

/// Landing de Web: la página de entrada, con las diez secciones del salón en
/// un scroll vertical y en orden (spec 002, RF-1).
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key, this.section});

  /// Sección en la que se abre (`/?section=…`): llegada desde una página de
  /// cuenta o desde la dirección de una pestaña móvil (RF-17, RF-29).
  final LandingSection? section;

  @override
  ConsumerState<LandingPage> createState() => LandingPageState();
}

class LandingPageState extends ConsumerState<LandingPage> {
  static const _scrollDuration = Duration(milliseconds: 400);

  final _scrollController = ScrollController();

  /// Clave de cada sección, para desplazarse hasta ella.
  final _sectionKeys = {
    for (final section in LandingSection.values) section: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _openAt(widget.section);
  }

  @override
  void didUpdateWidget(LandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section) _openAt(widget.section);
  }

  /// Tras el primer fotograma, cuando ya se conoce dónde empieza cada sección,
  /// salta a [section] sin animación.
  void _openAt(LandingSection? section) {
    if (section == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _sectionKeys[section]?.currentContext;
      if (!mounted || sectionContext == null) return;
      Scrollable.ensureVisible(sectionContext);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Vuelve al comienzo de la landing (RF-14).
  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: _scrollDuration,
      curve: Curves.easeInOut,
    );
  }

  /// Desplaza la landing hasta el comienzo de [section] (RF-4, RF-16).
  void scrollToSection(LandingSection section) {
    final sectionContext = _sectionKeys[section]?.currentContext;
    if (sectionContext == null) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: _scrollDuration,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.brand.background,
      child: Stack(
        children: [
          // Dos grupos de foco: con Tab se recorre todo el contenido y después
          // el botón flotante. Sin ellos, el botón, fijo en pantalla, volvía a
          // quedar "a continuación" cada vez que la landing se desplazaba
          // (RNF-2).
          FocusTraversalGroup(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in LandingSection.values)
                    LandingSectionFrame(
                      key: _sectionKeys[section],
                      section: section,
                      child: _sectionBody(section),
                    ),
                ],
              ),
            ),
          ),
          // Siempre visible sobre la landing, también al final (RF-11).
          if (ref.watch(showLandingFloatButtonProvider))
            Positioned(
              right: 24,
              bottom: 24,
              child: FocusTraversalGroup(child: const WhatsappFloatButton()),
            ),
        ],
      ),
    );
  }

  Widget _sectionBody(LandingSection section) => switch (section) {
    LandingSection.hero => HeroSection(
      onPricesTap: () => scrollToSection(LandingSection.prices),
    ),
    LandingSection.marquee => const MarqueeStrip(),
    LandingSection.prices => const PricesSection(),
    LandingSection.combos => const CombosSection(),
    LandingSection.catalog => const CatalogSection(),
    LandingSection.info => const InfoSection(),
    LandingSection.gallery => const GallerySection(),
    LandingSection.about => const AboutSection(),
    LandingSection.contact => const ContactSection(),
    LandingSection.footer => const FooterSection(),
  };
}

/// Una sección de la landing. Marca dónde empieza [section] para desplazarse
/// hasta ella.
class LandingSectionFrame extends StatelessWidget {
  const LandingSectionFrame({
    super.key,
    required this.section,
    required this.child,
  });

  final LandingSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
