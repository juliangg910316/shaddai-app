/// Qué hace tocar una pestaña de la barra inferior, sin Flutter (spec 003,
/// RF-4; spec 004, RF-45).
library;

enum TabTapAction {
  /// Cambia a otra pestaña, que conserva su estado (spec 003, RF-3).
  switchTab,

  /// La pestaña activa tiene una página abierta encima (un detalle): se
  /// cierra y la página principal sigue en su posición.
  popToRoot,

  /// La pestaña activa está en su página principal: vuelve al comienzo.
  scrollToTop,
}

TabTapAction tabTapAction({
  required bool isActive,
  required bool isAtBranchRoot,
}) {
  if (!isActive) return TabTapAction.switchTab;
  return isAtBranchRoot ? TabTapAction.scrollToTop : TabTapAction.popToRoot;
}
