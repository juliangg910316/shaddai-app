import 'package:flutter/widgets.dart';

/// Si las secciones de la landing van en ancho (columnas lado a lado) o en
/// estrecho (una debajo de otra).
///
/// Lo decide quien muestra las secciones: la landing de Web según el ancho de
/// la ventana, y las pestañas de Android/iOS siempre en estrecho, también en
/// una tableta en horizontal (spec 003, D-4).
class LandingLayout extends InheritedWidget {
  const LandingLayout({super.key, required this.wide, required super.child});

  final bool wide;

  static LandingLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LandingLayout>();

  @override
  bool updateShouldNotify(LandingLayout oldWidget) => wide != oldWidget.wide;
}

/// Si las secciones van en ancho: lo que diga el [LandingLayout] más cercano
/// o, si no hay ninguno, en estrecho.
bool landingIsWide(BuildContext context) =>
    LandingLayout.maybeOf(context)?.wide ?? false;
