import '../../l10n/app_localizations.dart';

/// Datos fijos de la landing que no se traducen: enlaces, contacto, cifras e
/// imágenes (spec 002, contenido de referencia de shaddai-web; RNF-6). Los
/// textos van en los `.arb` con el prefijo `landing`. Los precios y combos
/// vienen de la base de datos (spec 004).
class LandingContent {
  const LandingContent._();

  // Enlaces externos (RF-8 a RF-12).
  static const whatsappUrl = 'https://wa.me/message/4UBMRDJL4VKIA1';
  static const mapsUrl = 'https://maps.app.goo.gl/2U6JarDq5qctkhiz8';
  static const instagramUrl = 'https://www.instagram.com/dshaddai.nails/';
  static const tiktokUrl =
      'https://www.tiktok.com/@dshaddai.nails?_r=1&_t=ZS-96vkhNE5Aov';
  static const facebookUrl =
      'https://www.facebook.com/share/1HFX19BEcu/?mibextid=wwXIfr';
  static const youtubeUrl = 'https://youtube.com/@dshaddai?si=kGYJeEVlqFTZ9Qt9';
  static const phoneUri = 'tel:+5541987716330';
  static const emailUri = 'mailto:beidisvierafdo@gmail.com';

  // Contacto tal como se muestra.
  static const phoneDisplay = '(41) 98771-6330';
  static const emailDisplay = 'beidisvierafdo@gmail.com';
  static const addressDisplay = 'R. Prof. Nivaldo Braga, 1108';
  static const addressFull = 'R. Prof. Nivaldo Braga, 1108 — Capão da Imbuia';
  static const instagramHandle = '@dshaddai.nails';

  /// Redes del pie, con su nombre propio (no se traduce).
  static const socialLinks = [
    ('Instagram', instagramUrl),
    ('TikTok', tiktokUrl),
    ('Facebook', facebookUrl),
    ('YouTube', youtubeUrl),
  ];

  // Nombres propios.
  static const founderName = 'Beidis';
  static const founderRole = 'Beidis · Nail Designer';
  static const copyright = '© 2026 · Beidis Viera · @dshaddai.nails';

  /// Cifras del hero, fijas (fuera de alcance que se actualicen solas).
  static const statServices = '30+';
  static const statFollowers = '1.1K';
  static const statNotice = '24h';

  // Imágenes (assets/images/landing/).
  static const heroPhoto = 'assets/images/landing/profile.jpeg';

  /// Páginas del catálogo, en el orden de shaddai-web. Sus descripciones
  /// están en [catalogDescriptions], en el mismo orden.
  static const catalogImages = [
    'assets/images/landing/catalogo/portada.png',
    'assets/images/landing/catalogo/alongamentos.jpeg',
    'assets/images/landing/catalogo/soft_gel.jpeg',
    'assets/images/landing/catalogo/manutencion.jpeg',
    'assets/images/landing/catalogo/decoraciones.jpeg',
    'assets/images/landing/catalogo/combos.jpeg',
    'assets/images/landing/catalogo/naturales.jpeg',
    'assets/images/landing/catalogo/pies.png',
    'assets/images/landing/catalogo/agendamiento.jpeg',
  ];

  /// Fotos de la galería (trabajos publicados en Instagram).
  static final galleryImages = [
    for (var n = 1; n <= 9; n++) 'assets/images/landing/galeria/image_$n.jpeg',
  ];

  /// Descripción de cada página del catálogo, en el orden de [catalogImages].
  static final catalogDescriptions = <LandingText>[
    (l) => l.landingCatalogAltPortada,
    (l) => l.landingCatalogAltAlongamentos,
    (l) => l.landingCatalogAltSoftGel,
    (l) => l.landingCatalogAltManutencion,
    (l) => l.landingCatalogAltDecoraciones,
    (l) => l.landingCatalogAltCombos,
    (l) => l.landingCatalogAltNaturales,
    (l) => l.landingCatalogAltPies,
    (l) => l.landingCatalogAltAgendamiento,
  ];
}

/// Texto de la landing en el idioma activo.
typedef LandingText = String Function(AppLocalizations l10n);
