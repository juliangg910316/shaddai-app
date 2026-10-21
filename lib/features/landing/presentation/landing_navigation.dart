import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../landing_section.dart';
import 'landing_page.dart';

/// Lleva a [section] de la landing: si ya se ve la landing, la desplaza sin
/// cambiar de página; si no, vuelve a ella en esa sección (RF-4, RF-16, RF-17).
void goToLandingSection(BuildContext context, LandingSection section) {
  final landing = landingPageKey.currentState;
  if (landing != null && landing.mounted) {
    landing.scrollToSection(section);
    return;
  }
  context.go(
    Uri(path: '/', queryParameters: {'section': section.queryValue}).toString(),
  );
}

/// Lleva al comienzo de la landing (RF-14).
void goToLandingTop(BuildContext context) {
  final landing = landingPageKey.currentState;
  if (landing != null && landing.mounted) {
    landing.scrollToTop();
    return;
  }
  context.go('/');
}
