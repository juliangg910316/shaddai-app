import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_web_app.dart';

/// Una entrada del historial del navegador: la dirección y el estado que la
/// app le dio al escribirla.
typedef HistoryEntry = ({String location, Object? state});

/// El historial del navegador en los tests de Web: guarda lo que la app
/// escribe en él y simula "atrás" o "adelante".
class BrowserHistory {
  /// Lo que la app escribe en el historial del navegador, en orden.
  final entries = <HistoryEntry>[];

  /// Empieza a guardar lo que la app escribe en el historial, como el
  /// navegador. Se llama antes de montar la app.
  void record(WidgetTester tester) {
    entries.clear();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
      if (call.method == 'routeInformationUpdated') {
        final args = call.arguments as Map;
        entries.add((
          location: (args['uri'] ?? args['location']) as String,
          state: args['state'],
        ));
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.navigation, null),
    );
  }

  /// "Atrás" o "adelante" del navegador hasta la última entrada de [path]:
  /// la devuelve con su estado, como hace el navegador.
  Future<void> goTo(WidgetTester tester, String path) async {
    final entry = entries.lastWhere((e) => Uri.parse(e.location).path == path);
    final message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {
        'location': entry.location,
        'state': entry.state,
      }),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      message,
      (_) {},
    );
    await settleWeb(tester);
  }
}
