import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Franja de servicios: palabras que pasan en bucle horizontal continuo, como
/// en shaddai-web.
///
/// Es decorativa (los servicios están en la lista de precios), así que el
/// lector de pantalla no la lee. Si el sistema pide reducir las animaciones,
/// se queda quieta y deja de pedir fotogramas.
class MarqueeStrip extends StatefulWidget {
  const MarqueeStrip({super.key});

  @override
  State<MarqueeStrip> createState() => _MarqueeStripState();
}

class _MarqueeStripState extends State<MarqueeStrip>
    with SingleTickerProviderStateMixin {
  static const _pixelsPerSecond = 36.0;

  late final Ticker _ticker;
  final _scrollController = ScrollController();
  Duration? _lastElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = null;
    } else if (!reduceMotion && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final delta = _lastElapsed == null
        ? Duration.zero
        : elapsed - _lastElapsed!;
    _lastElapsed = elapsed;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) return;

    // Las palabras van dos veces seguidas: al recorrer la primera tanda se
    // vuelve atrás sin que se note.
    final singleSetExtent = maxExtent / 2;
    var next =
        _scrollController.offset +
        _pixelsPerSecond *
            delta.inMicroseconds /
            Duration.microsecondsPerSecond;
    if (next >= singleSetExtent) next -= singleSetExtent;
    _scrollController.jumpTo(next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final words = [
      l10n.landingMarqueeGelPolish,
      l10n.landingMarqueeSpaMore,
      l10n.landingMarqueeManicure,
      l10n.landingMarqueePedicure,
      l10n.landingMarqueeExtensions,
      l10n.landingSoftGelTitle,
    ];

    Widget wordRow() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final word in words)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.toUpperCase(),
                  style: AppText.eyebrow(
                    size: 12,
                    spacing: 2.5,
                    color: brand.inkMuted,
                  ),
                ),
                const SizedBox(width: 24),
                Text('✦', style: AppText.sans(size: 12, color: brand.accent)),
              ],
            ),
          ),
      ],
    );

    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: brand.surface,
          border: Border.symmetric(
            horizontal: BorderSide(color: brand.goldHairlineSoft),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [wordRow(), wordRow()],
          ),
        ),
      ),
    );
  }
}
