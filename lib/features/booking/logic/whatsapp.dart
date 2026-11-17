/// WhatsApp normalizado, válido y su enlace, sin Flutter ni Firebase (spec
/// 007, RF-7, RF-9, RF-10, RF-22; plan § 4.1).
library;

/// Código de Brasil.
const _brazil = '55';

/// Dígitos mínimos de un número con el código de Brasil delante: 55 + DDD
/// (2) + fijo de 8 dígitos. Con menos, un `55` inicial es el DDD de Rio
/// Grande do Sul (plan D-1).
const _minDigitsWithCountry = 12;

String _digitsOf(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Si [raw] lleva delante el código de Brasil: escrito como `+55`, o un `55`
/// en un número de 12 dígitos o más (D-1).
bool _hasBrazilPrefix(String raw, String digits) =>
    digits.startsWith(_brazil) &&
    (raw.trim().startsWith('+') || digits.length >= _minDigitsWithCountry);

/// Solo los dígitos de [raw], sin el código de Brasil (spec 007,
/// "WhatsApp normalizado").
String normalizeWhatsApp(String raw) {
  final digits = _digitsOf(raw);
  return _hasBrazilPrefix(raw, digits)
      ? digits.substring(_brazil.length)
      : digits;
}

/// De 8 a 15 dígitos, una vez normalizado (spec 007, "WhatsApp válido").
bool isValidWhatsApp(String raw) {
  final length = normalizeWhatsApp(raw).length;
  return length >= 8 && length <= 15;
}

/// Si [a] y [b] son el mismo WhatsApp: su versión normalizada coincide y no
/// está vacía.
bool sameWhatsApp(String a, String b) {
  final normalized = normalizeWhatsApp(a);
  return normalized.isNotEmpty && normalized == normalizeWhatsApp(b);
}

/// El enlace para escribir a [raw] por WhatsApp (D-6): con `+`, sus dígitos
/// tal cual; con el código de Brasil, también; si no, con `55` delante.
/// `null` si no tiene dígitos.
Uri? whatsAppLink(String raw) {
  final digits = _digitsOf(raw);
  if (digits.isEmpty) return null;
  final international =
      raw.trim().startsWith('+') || _hasBrazilPrefix(raw, digits);
  return Uri.https('wa.me', '/${international ? digits : '$_brazil$digits'}');
}
