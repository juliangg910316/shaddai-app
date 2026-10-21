import '../../l10n/app_localizations.dart';

/// Datos fijos de la landing que no se traducen: enlaces, contacto, cifras e
/// imágenes (spec 002, contenido de referencia de shaddai-web; RNF-6). Los
/// textos van en los `.arb` con el prefijo `landing`.
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

  /// Lista de precios de shaddai-web (RF-3). Los importes no se traducen; la
  /// spec 004 los sustituye por los de Firestore sin cambiar cómo se ven.
  static final priceCards = <PriceCard>[
    PriceCard(
      number: '01',
      title: (l) => l.landingServices1Title,
      subtitle: (l) => l.landingServices1Subtitle,
      note: (l) => l.landingServices1Note,
      lines: [
        PriceItem((l) => l.landingServices1Row1, 'R\$ 30'),
        PriceItem((l) => l.landingServices1Row2, 'R\$ 55'),
        PriceItem((l) => l.landingServices1Row3, 'R\$ 60'),
        PriceItem((l) => l.landingServices1Row4, 'R\$ 100'),
        PriceItem((l) => l.landingServices1Row5, 'R\$ 120'),
      ],
    ),
    PriceCard(
      number: '02',
      title: (l) => l.landingServices2Title,
      subtitle: (l) => l.landingServices2Subtitle,
      note: (l) => l.landingServices2Note,
      lines: [
        PriceItem((l) => l.landingServices2Row1, 'R\$ 40'),
        PriceItem((l) => l.landingServices2Row2, 'R\$ 60'),
        PriceItem((l) => l.landingServices2Row3, 'R\$ 110'),
        PriceItem((l) => l.landingServices2Row4, 'R\$ 130'),
        PriceItem((l) => l.landingServices2Row5, 'R\$ 70'),
      ],
    ),
    PriceCard(
      number: '03',
      title: (l) => l.landingServices3Title,
      subtitle: (l) => l.landingServices3Subtitle,
      note: (l) => l.landingServices3Note,
      lines: [
        PriceGroup((l) => l.landingServices3GroupNew),
        PriceItem((l) => l.landingServices3RowShort, 'R\$ 150'),
        PriceItem((l) => l.landingServices3RowMedium, 'R\$ 165'),
        PriceItem((l) => l.landingServices3RowLong, 'R\$ 185'),
        PriceItem((l) => l.landingServices3RowExtraLong, 'R\$ 220'),
        PriceGroup((l) => l.landingServices3GroupMaintenance),
        PriceItem((l) => l.landingServices3RowShort, 'R\$ 120'),
        PriceItem((l) => l.landingServices3RowMedium, 'R\$ 130'),
        PriceItem((l) => l.landingServices3RowLong, 'R\$ 145'),
        PriceItem((l) => l.landingServices3RowExtraLong, 'R\$ 165'),
      ],
    ),
    PriceCard(
      number: '04',
      title: (l) => l.landingSoftGelTitle,
      subtitle: (l) => l.landingServices4Subtitle,
      note: (l) => l.landingServices4Note,
      lines: [
        PriceItem((l) => l.landingServices4Row1, 'R\$ 130'),
        PriceItem((l) => l.landingServices4Row2, 'R\$ 145'),
        PriceItem((l) => l.landingServices4Row3, 'R\$ 110'),
      ],
    ),
    PriceCard(
      number: '05',
      title: (l) => l.landingServices5Title,
      subtitle: (l) => l.landingServices5Subtitle,
      note: (l) => l.landingServices5Note,
      lines: [
        PriceItem((l) => l.landingServices5Row1, 'R\$ 20'),
        PriceItem((l) => l.landingServices5Row2, 'R\$ 30'),
        PriceItem((l) => l.landingSoftGelTitle, 'R\$ 30'),
        PriceItem((l) => l.landingServices5Row3, 'R\$ 40'),
      ],
    ),
    PriceCard(
      number: '06',
      title: (l) => l.landingServices6Title,
      subtitle: (l) => l.landingServices6Subtitle,
      note: (l) => l.landingServices6Note,
      lines: [
        PriceItem((l) => l.landingServices6Row1, '+R\$ 10'),
        PriceItem((l) => l.landingServices6RowBabyBoomer, '+R\$ 15'),
        PriceItem((l) => l.landingServices6Row2, '+R\$ 15'),
        PriceItem((l) => l.landingServices6Row3, '+R\$ 20'),
        PriceItem((l) => l.landingServices6Row4, '+R\$ 5'),
        PriceItem((l) => l.landingServices6Row5, '+R\$ 10'),
        PriceItem((l) => l.landingServices6Row6, '+R\$ 15'),
        PriceItem((l) => l.landingServices6Row7, '+R\$ 6'),
        PriceItem((l) => l.landingServices6RowReversa, '+R\$ 20'),
      ],
    ),
  ];

  /// Combos de shaddai-web (RF-3). También los sustituye la spec 004.
  static final combos = <Combo>[
    Combo('R\$ 60', (l) => l.landingCombo1Name, (l) => l.landingCombo1Desc),
    Combo('R\$ 120', (l) => l.landingCombo2Name, (l) => l.landingCombo2Desc),
    Combo('R\$ 165', (l) => l.landingCombo3Name, (l) => l.landingCombo3Desc),
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

/// Un combo: precio fijo, nombre y descripción traducidos.
class Combo {
  const Combo(this.price, this.name, this.description);

  final String price;
  final LandingText name;
  final LandingText description;
}

/// Texto de la landing en el idioma activo.
typedef LandingText = String Function(AppLocalizations l10n);

/// Un bloque de la lista de precios.
class PriceCard {
  const PriceCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.lines,
  });

  final String number;
  final LandingText title;
  final LandingText subtitle;
  final LandingText note;
  final List<PriceLine> lines;
}

/// Una línea de un bloque de precios: un servicio con su precio o el título de
/// un grupo.
sealed class PriceLine {
  const PriceLine();
}

class PriceItem extends PriceLine {
  const PriceItem(this.label, this.price);

  final LandingText label;
  final String price;
}

class PriceGroup extends PriceLine {
  const PriceGroup(this.label);

  final LandingText label;
}
