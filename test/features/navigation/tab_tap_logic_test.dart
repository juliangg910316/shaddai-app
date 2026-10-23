import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/navigation/tab_tap_logic.dart';

void main() {
  group('tabTapAction (spec 003 RF-4; spec 004 RF-45)', () {
    final cases = <(bool, bool, TabTapAction)>[
      // Otra pestaña: se cambia a ella, esté donde esté.
      (false, true, TabTapAction.switchTab),
      (false, false, TabTapAction.switchTab),
      // La activa con un detalle abierto: se cierra el detalle y la lista
      // sigue donde estaba.
      (true, false, TabTapAction.popToRoot),
      // La activa en su página principal: al comienzo.
      (true, true, TabTapAction.scrollToTop),
    ];

    for (final (isActive, isAtBranchRoot, expected) in cases) {
      test('activa: $isActive, en su raíz: $isAtBranchRoot → '
          '${expected.name}', () {
        expect(
          tabTapAction(isActive: isActive, isAtBranchRoot: isAtBranchRoot),
          expected,
        );
      });
    }
  });
}
