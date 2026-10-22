import '../../../l10n/app_localizations.dart';
import '../providers/auth_failure.dart';

/// Texto de la app para un error de inicio de sesión, nunca el mensaje
/// técnico (spec 001, RF-22). Al cancelar no se muestra nada.
String? authErrorMessage(Object? error, AppLocalizations l10n) {
  return switch (error) {
    null || AuthFailure.cancelled => null,
    AuthFailure.blocked => l10n.authBlockedError,
    _ => l10n.authGenericError,
  };
}
