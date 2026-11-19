import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/account_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// El repositorio del borrado de la cuenta (spec 009). Solo lo usa el
/// perfil.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(),
);

/// Borra la cuenta de la clienta (spec 009, RF-36, RF-39, RF-40; plan D-14).
class AccountDeleter {
  AccountDeleter(this._ref);

  final Ref _ref;

  /// Pide el borrado al servidor. Si va bien, llama a [onDeleted] (para
  /// navegar antes de que la vista se quede sin sesión) y cierra la sesión.
  /// Devuelve `null` si se borró, o por qué no.
  Future<AccountDeletionFailure?> delete({
    required void Function() onDeleted,
  }) async {
    final failure = await _ref.read(accountRepositoryProvider).deleteAccount();
    if (failure != null) return failure;
    onDeleted();
    await _ref.read(authControllerProvider.notifier).signOut();
    return null;
  }
}

final accountDeletionProvider = Provider(AccountDeleter.new);
