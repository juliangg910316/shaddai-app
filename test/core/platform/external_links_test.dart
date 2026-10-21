import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/external_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/recording_link_launcher.dart';

/// Llamada a `launchUrl` registrada por el lanzador falso.
typedef _Launch = ({Uri url, LaunchMode mode, String? windowName});

void main() {
  late List<_Launch> launches;

  ExternalLinkLauncher launcherReturning(Future<bool> Function() result) {
    return externalLinkLauncher(
      launch: (url, {mode = LaunchMode.platformDefault, webOnlyWindowName}) {
        launches.add((url: url, mode: mode, windowName: webOnlyWindowName));
        return result();
      },
    );
  }

  setUp(() => launches = []);

  group('pestaña en la que se abre (RF-8 a RF-10, RF-12)', () {
    for (final url in [
      'https://wa.me/message/4UBMRDJL4VKIA1',
      'https://maps.app.goo.gl/2U6JarDq5qctkhiz8',
      'https://www.instagram.com/dshaddai.nails/',
    ]) {
      test('$url se abre en una pestaña nueva', () async {
        await launcherReturning(() async => true)(Uri.parse(url));

        expect(launches.single.url, Uri.parse(url));
        expect(launches.single.mode, LaunchMode.externalApplication);
        expect(launches.single.windowName, '_blank');
      });
    }

    for (final url in ['tel:+5541987716330', 'mailto:salon@example.com']) {
      test('$url se abre en la misma pestaña', () async {
        await launcherReturning(() async => true)(Uri.parse(url));

        expect(launches.single.url, Uri.parse(url));
        expect(launches.single.mode, LaunchMode.platformDefault);
        expect(launches.single.windowName, '_self');
      });
    }
  });

  group('si no se puede abrir, no hay error (D-12)', () {
    test('launchUrl devuelve false', () async {
      final launcher = launcherReturning(() async => false);

      await expectLater(
        launcher(Uri.parse('https://www.instagram.com/dshaddai.nails/')),
        completes,
      );
    });

    test('launchUrl lanza una excepción', () async {
      final launcher = launcherReturning(
        () async => throw Exception('pestaña bloqueada'),
      );

      await expectLater(
        launcher(Uri.parse('https://www.instagram.com/dshaddai.nails/')),
        completes,
      );
    });
  });

  test('los tests sustituyen el lanzador por uno que registra', () async {
    final recorder = RecordingLinkLauncher();
    final container = ProviderContainer(overrides: [recorder.override]);
    addTearDown(container.dispose);

    await container.read(externalLinkLauncherProvider)(
      Uri.parse('https://wa.me/message/4UBMRDJL4VKIA1'),
    );

    expect(recorder.opened, [
      Uri.parse('https://wa.me/message/4UBMRDJL4VKIA1'),
    ]);
  });
}
