/// Para quién es el turno que agenda la admin y la búsqueda de clientas, sin
/// Flutter ni Firebase (spec 007, RF-2 a RF-5, RF-7 a RF-11, RF-15; plan
/// § 4.2).
library;

import '../../../data/models/user_model.dart';
import 'whatsapp.dart';

/// Caracteres que puede tener como mucho el nombre de una persona sin cuenta
/// (RF-7).
const guestNameMaxLength = 80;

/// Caracteres a partir de los que se busca (RF-3).
const recipientSearchMinLength = 2;

/// Resultados que se ofrecen como mucho (RF-3).
const recipientSearchLimit = 20;

/// La persona a cuyo nombre queda el turno (spec 007, "Para quién").
sealed class Recipient {
  const Recipient();

  String get name;
  String get phone;
}

/// Una clienta con cuenta, con sus datos al elegirla.
class AccountRecipient extends Recipient {
  const AccountRecipient({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoUrl,
  });

  AccountRecipient.of(UserModel user)
    : this(
        uid: user.uid,
        name: user.displayName,
        phone: user.phoneNumber ?? '',
        photoUrl: user.photoUrl,
      );

  final String uid;
  @override
  final String name;
  @override
  final String phone;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      other is AccountRecipient &&
      other.uid == uid &&
      other.name == name &&
      other.phone == phone &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, name, phone, photoUrl);
}

/// Una persona sin cuenta: lo que escribe la admin (RF-7, RF-8).
class GuestRecipient extends Recipient {
  const GuestRecipient({
    required this.name,
    required this.phone,
    required this.consent,
  });

  static const empty = GuestRecipient(name: '', phone: '', consent: false);

  @override
  final String name;
  @override
  final String phone;

  /// La casilla de que acepta dar su nombre y su WhatsApp (RF-8).
  final bool consent;

  GuestRecipient copyWith({String? name, String? phone, bool? consent}) =>
      GuestRecipient(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        consent: consent ?? this.consent,
      );

  @override
  bool operator ==(Object other) =>
      other is GuestRecipient &&
      other.name == name &&
      other.phone == phone &&
      other.consent == consent;

  @override
  int get hashCode => Object.hash(name, phone, consent);
}

const _folded = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

/// [text] en minúsculas y sin acentos, para comparar nombres (RF-3).
String foldText(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}

bool _isClient(UserModel user) => user.role == 'cliente';

/// Si se le puede agendar un turno: clienta, sin bloquear y con WhatsApp
/// (RF-2, RF-4).
bool isBookableClient(UserModel user) =>
    _isClient(user) &&
    !user.isBlocked &&
    normalizeWhatsApp(user.phoneNumber ?? '').isNotEmpty;

/// Un texto que solo puede ser un número de teléfono.
final _phoneLike = RegExp(r'^[\d\s()+\-.]+$');

/// Las clientas a las que se puede agendar cuyo nombre contiene [query] sin
/// distinguir mayúsculas ni acentos, o, si [query] es un número, cuyo
/// WhatsApp normalizado contiene sus dígitos. En orden alfabético y como
/// mucho [limit]. Con menos de [recipientSearchMinLength] caracteres, ninguna
/// (RF-3, RF-4).
List<UserModel> searchClients(
  Iterable<UserModel> users,
  String query, {
  int limit = recipientSearchLimit,
}) {
  final q = query.trim();
  if (q.length < recipientSearchMinLength) return const [];
  final folded = foldText(q);
  final digits = _phoneLike.hasMatch(q) ? normalizeWhatsApp(q) : '';
  final found = [
    for (final user in users)
      if (isBookableClient(user) &&
          (foldText(user.displayName).contains(folded) ||
              (digits.isNotEmpty &&
                  normalizeWhatsApp(user.phoneNumber!).contains(digits))))
        user,
  ];
  found.sort((a, b) {
    final byFolded = foldText(a.displayName).compareTo(foldText(b.displayName));
    return byFolded != 0 ? byFolded : a.displayName.compareTo(b.displayName);
  });
  return found.take(limit).toList();
}

/// La clienta con cuenta cuyo WhatsApp es [phone], también si está
/// bloqueada (RF-10, RF-11). Si hay varias, manda una bloqueada: con ella no
/// se agenda. `null` si ninguna.
UserModel? accountWithPhone(Iterable<UserModel> users, String phone) {
  UserModel? found;
  for (final user in users) {
    if (!_isClient(user) || !sameWhatsApp(user.phoneNumber ?? '', phone)) {
      continue;
    }
    if (user.isBlocked) return user;
    found ??= user;
  }
  return found;
}

/// Los campos de la persona sin cuenta.
enum GuestField { name, phone, consent }

/// Los campos que impiden agendar a [guest] (RF-7 a RF-9).
Set<GuestField> guestErrors(GuestRecipient guest) {
  final name = guest.name.trim();
  return {
    if (name.isEmpty || name.runes.length > guestNameMaxLength) GuestField.name,
    if (!isValidWhatsApp(guest.phone)) GuestField.phone,
    if (!guest.consent) GuestField.consent,
  };
}

/// Para quién tras un cambio en las fichas ([users], `null` mientras no se
/// conocen): una clienta que ya no existe, ya no es clienta o está bloqueada
/// se quita, y [blocked] pide avisar (RF-15).
({Recipient? recipient, bool blocked}) reconcileRecipient(
  Recipient? recipient,
  Iterable<UserModel>? users,
) {
  if (recipient is! AccountRecipient || users == null) {
    return (recipient: recipient, blocked: false);
  }
  for (final user in users) {
    if (user.uid == recipient.uid) {
      return _isClient(user) && !user.isBlocked
          ? (recipient: recipient, blocked: false)
          : (recipient: null, blocked: true);
    }
  }
  return (recipient: null, blocked: true);
}
