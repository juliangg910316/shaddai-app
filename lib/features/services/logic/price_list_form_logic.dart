/// Validaciones de los formularios de la gestión de servicios, sin Flutter
/// ni Firebase (spec 004, plan § 4; RF-21 a RF-25).
library;

/// Precio máximo: R$ 99.999,99.
const maxPriceCents = 9999999;

/// Duración mínima y máxima de un servicio o combo, en minutos.
const minDurationMinutes = 5;
const maxDurationMinutes = 480;

/// Longitudes máximas de los textos.
const maxNameLength = 80;
const maxSubtitleLength = 80;
const maxGroupLength = 40;
const maxLongTextLength = 600;

final _pricePattern = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$');
final _durationPattern = RegExp(r'^\d+$');

/// El precio en céntimos, o `null` si está vacío, es negativo, no es un
/// número, tiene más de dos decimales o pasa de [maxPriceCents] (RF-24).
/// Acepta coma o punto decimal y quita los espacios.
int? parsePriceCents(String input) {
  final match = _pricePattern.firstMatch(input.replaceAll(RegExp(r'\s'), ''));
  if (match == null) return null;
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  final cents = int.parse(match.group(1)!) * 100 + int.parse(decimals);
  return cents > maxPriceCents ? null : cents;
}

/// La duración en minutos, o `null` si no es un entero entre
/// [minDurationMinutes] y [maxDurationMinutes] (RF-25).
int? parseDuration(String input) {
  final text = input.trim();
  if (!_durationPattern.hasMatch(text)) return null;
  final minutes = int.parse(text);
  return minutes < minDurationMinutes || minutes > maxDurationMinutes
      ? null
      : minutes;
}

/// Campo de un formulario que puede tener un error.
enum PriceFormField {
  nameEs,
  namePt,
  subtitleEs,
  subtitlePt,
  noteEs,
  notePt,
  descriptionEs,
  descriptionPt,
  groupEs,
  groupPt,
  price,
  duration,
}

/// Error de un campo.
enum PriceFormError {
  /// Falta el nombre en este idioma (RF-22).
  required,

  /// El texto está escrito en el otro idioma y vacío en este (RF-23).
  missingTranslation,

  /// RF-24.
  invalidPrice,

  /// RF-25.
  invalidDuration,

  /// Pasa de la longitud máxima.
  tooLong,
}

/// Lo que la admin escribió en un formulario, tal cual. Cada validador mira
/// solo los campos de su tipo.
class PriceForm {
  const PriceForm({
    this.nameEs = '',
    this.namePt = '',
    this.subtitleEs = '',
    this.subtitlePt = '',
    this.noteEs = '',
    this.notePt = '',
    this.descriptionEs = '',
    this.descriptionPt = '',
    this.groupEs = '',
    this.groupPt = '',
    this.price = '',
    this.duration = '',
  });

  final String nameEs;
  final String namePt;
  final String subtitleEs;
  final String subtitlePt;
  final String noteEs;
  final String notePt;
  final String descriptionEs;
  final String descriptionPt;
  final String groupEs;
  final String groupPt;
  final String price;
  final String duration;
}

typedef PriceFormErrors = Map<PriceFormField, PriceFormError>;

/// Un texto bilingüe. Con [required], cada idioma debe estar escrito; sin
/// él, los dos vacíos o los dos escritos. Los textos se recortan antes.
void _checkText(
  PriceFormErrors errors, {
  required String es,
  required String pt,
  required PriceFormField esField,
  required PriceFormField ptField,
  required int maxLength,
  bool required = false,
}) {
  final esText = es.trim();
  final ptText = pt.trim();
  final missing = required
      ? PriceFormError.required
      : PriceFormError.missingTranslation;
  final bothEmpty = esText.isEmpty && ptText.isEmpty;

  void check(String text, PriceFormField field) {
    if (text.isEmpty) {
      if (required || !bothEmpty) errors[field] = missing;
    } else if (text.length > maxLength) {
      errors[field] = PriceFormError.tooLong;
    }
  }

  check(esText, esField);
  check(ptText, ptField);
}

void _checkName(PriceFormErrors errors, PriceForm form) => _checkText(
  errors,
  es: form.nameEs,
  pt: form.namePt,
  esField: PriceFormField.nameEs,
  ptField: PriceFormField.namePt,
  maxLength: maxNameLength,
  required: true,
);

void _checkDescription(PriceFormErrors errors, PriceForm form) => _checkText(
  errors,
  es: form.descriptionEs,
  pt: form.descriptionPt,
  esField: PriceFormField.descriptionEs,
  ptField: PriceFormField.descriptionPt,
  maxLength: maxLongTextLength,
);

void _checkPrice(PriceFormErrors errors, PriceForm form) {
  if (parsePriceCents(form.price) == null) {
    errors[PriceFormField.price] = PriceFormError.invalidPrice;
  }
}

void _checkDuration(PriceFormErrors errors, PriceForm form) {
  if (parseDuration(form.duration) == null) {
    errors[PriceFormField.duration] = PriceFormError.invalidDuration;
  }
}

/// Nombre, subtítulo y nota.
PriceFormErrors validateCategory(PriceForm form) {
  final errors = <PriceFormField, PriceFormError>{};
  _checkName(errors, form);
  _checkText(
    errors,
    es: form.subtitleEs,
    pt: form.subtitlePt,
    esField: PriceFormField.subtitleEs,
    ptField: PriceFormField.subtitlePt,
    maxLength: maxSubtitleLength,
  );
  _checkText(
    errors,
    es: form.noteEs,
    pt: form.notePt,
    esField: PriceFormField.noteEs,
    ptField: PriceFormField.notePt,
    maxLength: maxLongTextLength,
  );
  return errors;
}

/// Nombre, descripción, grupo, precio y duración.
PriceFormErrors validateService(PriceForm form) {
  final errors = <PriceFormField, PriceFormError>{};
  _checkName(errors, form);
  _checkDescription(errors, form);
  _checkText(
    errors,
    es: form.groupEs,
    pt: form.groupPt,
    esField: PriceFormField.groupEs,
    ptField: PriceFormField.groupPt,
    maxLength: maxGroupLength,
  );
  _checkPrice(errors, form);
  _checkDuration(errors, form);
  return errors;
}

/// Nombre y precio.
PriceFormErrors validateAddon(PriceForm form) {
  final errors = <PriceFormField, PriceFormError>{};
  _checkName(errors, form);
  _checkPrice(errors, form);
  return errors;
}

/// Nombre, descripción, precio y duración.
PriceFormErrors validateCombo(PriceForm form) {
  final errors = <PriceFormField, PriceFormError>{};
  _checkName(errors, form);
  _checkDescription(errors, form);
  _checkPrice(errors, form);
  _checkDuration(errors, form);
  return errors;
}
