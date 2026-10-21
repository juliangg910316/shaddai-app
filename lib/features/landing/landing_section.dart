/// Secciones de la landing, en el orden en que se muestran (spec 002, RF-1).
enum LandingSection {
  hero,
  marquee,
  prices,
  combos,
  catalog,
  info,
  gallery,
  about,
  contact,
  footer;

  /// Valor en la ruta: `/?section=prices` (D-5).
  String get queryValue => name;

  /// Sección de `?section=`, o `null` si no hay o no es válida.
  static LandingSection? fromQuery(String? value) {
    for (final section in values) {
      if (section.queryValue == value) return section;
    }
    return null;
  }
}
