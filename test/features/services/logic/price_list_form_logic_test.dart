import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/services/logic/price_list_form_logic.dart';

/// Un formulario con nombre en los dos idiomas, precio y duración válidos.
PriceForm validForm({
  String nameEs = 'Gel',
  String namePt = 'Gel',
  String subtitleEs = '',
  String subtitlePt = '',
  String noteEs = '',
  String notePt = '',
  String descriptionEs = '',
  String descriptionPt = '',
  String groupEs = '',
  String groupPt = '',
  String price = '30',
  String duration = '45',
}) => PriceForm(
  nameEs: nameEs,
  namePt: namePt,
  subtitleEs: subtitleEs,
  subtitlePt: subtitlePt,
  noteEs: noteEs,
  notePt: notePt,
  descriptionEs: descriptionEs,
  descriptionPt: descriptionPt,
  groupEs: groupEs,
  groupPt: groupPt,
  price: price,
  duration: duration,
);

void main() {
  group('parsePriceCents (RF-24)', () {
    test('acepta enteros y hasta dos decimales con coma o punto', () {
      expect(parsePriceCents('30'), 3000);
      expect(parsePriceCents('30,5'), 3050);
      expect(parsePriceCents('30,50'), 3050);
      expect(parsePriceCents('30.50'), 3050);
      expect(parsePriceCents(' 30 '), 3000);
      expect(parsePriceCents('0'), 0);
      expect(parsePriceCents('99999,99'), 9999999);
    });

    test('rechaza vacío, negativo, más de dos decimales, texto y más de '
        'R\$ 99.999,99', () {
      expect(parsePriceCents(''), isNull);
      expect(parsePriceCents('   '), isNull);
      expect(parsePriceCents('-1'), isNull);
      expect(parsePriceCents('30,505'), isNull);
      expect(parsePriceCents('abc'), isNull);
      expect(parsePriceCents('100000'), isNull);
    });
  });

  group('parseDuration (RF-25)', () {
    test('acepta minutos enteros de 5 a 480', () {
      expect(parseDuration('5'), 5);
      expect(parseDuration('480'), 480);
      expect(parseDuration(' 45 '), 45);
    });

    test('rechaza fuera de rango, decimales y vacío', () {
      expect(parseDuration('4'), isNull);
      expect(parseDuration('481'), isNull);
      expect(parseDuration('45,5'), isNull);
      expect(parseDuration(''), isNull);
    });
  });

  group('validadores', () {
    test('un formulario completo no tiene errores', () {
      expect(validateCategory(validForm()), isEmpty);
      expect(validateService(validForm()), isEmpty);
      expect(validateAddon(validForm()), isEmpty);
      expect(validateCombo(validForm()), isEmpty);
    });

    test('falta el nombre en un idioma (RF-22)', () {
      for (final validate in [
        validateCategory,
        validateService,
        validateAddon,
        validateCombo,
      ]) {
        expect(validate(validForm(namePt: '')), {
          PriceFormField.namePt: PriceFormError.required,
        });
        expect(validate(validForm(nameEs: '')), {
          PriceFormField.nameEs: PriceFormError.required,
        });
      }
    });

    test('un nombre con solo espacios cuenta como vacío', () {
      expect(validateService(validForm(nameEs: '   ')), {
        PriceFormField.nameEs: PriceFormError.required,
      });
    });

    test('un texto opcional en un solo idioma marca el vacío (RF-23)', () {
      expect(validateCategory(validForm(subtitleEs: 'Sub')), {
        PriceFormField.subtitlePt: PriceFormError.missingTranslation,
      });
      expect(validateCategory(validForm(notePt: 'Nota')), {
        PriceFormField.noteEs: PriceFormError.missingTranslation,
      });
      expect(validateService(validForm(descriptionEs: 'Desc')), {
        PriceFormField.descriptionPt: PriceFormError.missingTranslation,
      });
      expect(validateService(validForm(groupPt: '  Grupo ')), {
        PriceFormField.groupEs: PriceFormError.missingTranslation,
      });
      expect(validateCombo(validForm(descriptionPt: 'Desc')), {
        PriceFormField.descriptionEs: PriceFormError.missingTranslation,
      });
    });

    test('los textos opcionales vacíos en los dos idiomas son válidos', () {
      expect(validateService(validForm(groupEs: ' ', groupPt: '')), isEmpty);
    });

    test('longitudes máximas (nombre y subtítulo 80, grupo 40, descripción '
        'y nota 600)', () {
      String chars(int n) => 'a' * n;

      expect(
        validateCategory(
          validForm(
            nameEs: chars(80),
            namePt: chars(80),
            subtitleEs: chars(80),
            subtitlePt: chars(80),
            noteEs: chars(600),
            notePt: chars(600),
          ),
        ),
        isEmpty,
      );
      expect(
        validateCategory(
          validForm(
            nameEs: chars(81),
            subtitleEs: chars(81),
            subtitlePt: chars(80),
            notePt: chars(601),
            noteEs: chars(600),
          ),
        ),
        {
          PriceFormField.nameEs: PriceFormError.tooLong,
          PriceFormField.subtitleEs: PriceFormError.tooLong,
          PriceFormField.notePt: PriceFormError.tooLong,
        },
      );
      expect(
        validateService(
          validForm(
            groupEs: chars(41),
            groupPt: chars(40),
            descriptionEs: chars(600),
            descriptionPt: chars(601),
          ),
        ),
        {
          PriceFormField.groupEs: PriceFormError.tooLong,
          PriceFormField.descriptionPt: PriceFormError.tooLong,
        },
      );
    });

    test('precio no válido (RF-24) y precio 0 válido', () {
      for (final validate in [validateService, validateAddon, validateCombo]) {
        expect(validate(validForm(price: '')), {
          PriceFormField.price: PriceFormError.invalidPrice,
        });
        expect(validate(validForm(price: '0')), isEmpty);
      }
    });

    test('duración no válida en servicios y combos (RF-25)', () {
      for (final validate in [validateService, validateCombo]) {
        expect(validate(validForm(duration: '481')), {
          PriceFormField.duration: PriceFormError.invalidDuration,
        });
        expect(validate(validForm(duration: '')), {
          PriceFormField.duration: PriceFormError.invalidDuration,
        });
      }
    });

    test('un adicional no tiene duración ni descripción ni grupo', () {
      expect(
        validateAddon(
          validForm(duration: '', descriptionEs: 'Desc', groupEs: 'Grupo'),
        ),
        isEmpty,
      );
    });

    test('una categoría no tiene precio ni duración', () {
      expect(validateCategory(validForm(price: '', duration: '')), isEmpty);
    });
  });
}
