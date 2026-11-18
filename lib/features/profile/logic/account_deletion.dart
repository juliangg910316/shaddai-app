/// Quién puede borrar su cuenta y la palabra de confirmación (spec 009,
/// RF-31, RF-32, RF-40; plan D-11). Sin Flutter ni Firebase.
library;

/// Qué ve la persona en "Tu cuenta".
enum AccountDeletionAccess {
  /// La admin: nada (RF-31).
  hidden,

  /// Bloqueada: el aviso de hablar con el salón (RF-40).
  blocked,

  /// "Eliminar mi cuenta".
  allowed,
}

AccountDeletionAccess accountDeletionAccess({
  required String role,
  required bool isBlocked,
}) {
  if (role == 'admin') return AccountDeletionAccess.hidden;
  if (isBlocked) return AccountDeletionAccess.blocked;
  return AccountDeletionAccess.allowed;
}

/// Si [typed] es la palabra de confirmación [word] del idioma activo, sin
/// distinguir mayúsculas ni espacios a los lados (RF-32, D-11).
bool deletionWordMatches(String typed, String word) =>
    typed.trim().toUpperCase() == word.trim().toUpperCase();
