import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Por qué no se borró la cuenta (spec 009, RF-39, RF-40).
enum AccountDeletionFailure {
  /// La clienta está bloqueada: debe hablar con el salón (RF-40).
  blocked,

  /// La cuenta no se puede borrar desde la app (la admin; RF-31).
  notAllowed,

  /// Sin conexión u otro fallo: se puede reintentar (RF-39).
  failed,
}

/// Borra la cuenta con la sesión iniciada llamando a la función
/// `deleteAccount` (spec 009, plan D-8). La función toma el uid de la
/// sesión, así que no se le envía nada.
class AccountRepository {
  AccountRepository({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  /// Borra la cuenta. Devuelve `null` si se borró, o por qué no.
  Future<AccountDeletionFailure?> deleteAccount() async {
    try {
      await _functions
          .httpsCallable(
            'deleteAccount',
            // Con muchos turnos puede tardar: más margen que los 60 s por
            // defecto.
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Object?>();
      return null;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error al borrar la cuenta: ${error.code} ${error.message}');
      return switch (error.code) {
        'failed-precondition' when _reason(error.details) == 'blocked' =>
          AccountDeletionFailure.blocked,
        'permission-denied' => AccountDeletionFailure.notAllowed,
        _ => AccountDeletionFailure.failed,
      };
    } catch (error) {
      debugPrint('Error al borrar la cuenta: $error');
      return AccountDeletionFailure.failed;
    }
  }

  static Object? _reason(Object? details) =>
      details is Map ? details['reason'] : null;
}
