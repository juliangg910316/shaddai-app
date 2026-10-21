import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/utils/capitalize.dart';

void main() {
  test('pone en mayúscula solo la primera letra', () {
    expect(capitalizeFirst('octubre de 2026'), 'Octubre de 2026');
    expect(capitalizeFirst('ter.'), 'Ter.');
    expect(capitalizeFirst('ñu'), 'Ñu');
  });

  test('un texto vacío se queda vacío', () {
    expect(capitalizeFirst(''), '');
  });
}
