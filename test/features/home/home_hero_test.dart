import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/home/presentation/google_map_container.dart';

void main() {
  test('por defecto, la app muestra el mapa de Google', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(salonMapProvider), isA<GoogleMapContainer>());
  });
}
