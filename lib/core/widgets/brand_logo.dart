import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../theme/brand_colors.dart';

/// Sello de Studio Shaddai, el mismo de shaddai-web, teñido con el dorado
/// legible del tema activo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size});

  static const asset = 'assets/images/logo_monogram.svg';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(context.brand.accentIcon, BlendMode.srcIn),
      semanticsLabel: AppLocalizations.of(context)!.brandLogoLabel,
    );
  }
}
