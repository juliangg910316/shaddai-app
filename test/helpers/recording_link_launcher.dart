import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shaddai/core/platform/external_links.dart';

/// Lanzador de enlaces externos falso: guarda las URLs en lugar de abrirlas.
class RecordingLinkLauncher {
  final List<Uri> opened = [];

  Future<void> call(Uri url) async => opened.add(url);

  Override get override => externalLinkLauncherProvider.overrideWithValue(call);
}
