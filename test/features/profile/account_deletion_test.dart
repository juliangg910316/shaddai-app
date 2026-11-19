import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/profile/logic/account_deletion.dart';

/// Quién puede borrar la cuenta y la palabra de confirmación (spec 009,
/// RF-31, RF-32, RF-40; plan D-11).
void main() {
  group('accountDeletionAccess', () {
    test('la admin no lo ve (RF-31)', () {
      expect(
        accountDeletionAccess(role: 'admin', isBlocked: false),
        AccountDeletionAccess.hidden,
      );
      expect(
        accountDeletionAccess(role: 'admin', isBlocked: true),
        AccountDeletionAccess.hidden,
      );
    });

    test('una clienta bloqueada ve el aviso (RF-40)', () {
      expect(
        accountDeletionAccess(role: 'cliente', isBlocked: true),
        AccountDeletionAccess.blocked,
      );
    });

    test('una clienta puede borrarla', () {
      expect(
        accountDeletionAccess(role: 'cliente', isBlocked: false),
        AccountDeletionAccess.allowed,
      );
    });
  });

  group('deletionWordMatches', () {
    test('la palabra exacta', () {
      expect(deletionWordMatches('ELIMINAR', 'ELIMINAR'), isTrue);
    });

    test('sin distinguir mayúsculas ni espacios a los lados', () {
      expect(deletionWordMatches('  eliminar ', 'ELIMINAR'), isTrue);
      expect(deletionWordMatches('Excluir', 'EXCLUIR'), isTrue);
    });

    test('otra palabra, vacía, a medias o con espacios dentro, no', () {
      expect(deletionWordMatches('', 'ELIMINAR'), isFalse);
      expect(deletionWordMatches('ELIMINA', 'ELIMINAR'), isFalse);
      expect(deletionWordMatches('ELIMI NAR', 'ELIMINAR'), isFalse);
      expect(deletionWordMatches('BORRAR', 'ELIMINAR'), isFalse);
    });

    test('la palabra del otro idioma no vale', () {
      expect(deletionWordMatches('EXCLUIR', 'ELIMINAR'), isFalse);
      expect(deletionWordMatches('ELIMINAR', 'EXCLUIR'), isFalse);
    });
  });
}
