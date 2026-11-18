import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../booking/logic/whatsapp.dart';
import 'profile_provider.dart';

/// El resultado de cambiar el WhatsApp (spec 009, RF-27, RF-28, RF-30).
enum WhatsAppChangeOutcome { ok, invalid, failed }

/// Cambia el WhatsApp de la clienta desde el perfil (spec 009, RF-26 a
/// RF-30): lo valida como en el registro (plan D-7) y lo guarda en su ficha
/// y, si tiene turno activo, también en ese turno (D-6).
class WhatsAppChanger {
  WhatsAppChanger(this._ref);

  final Ref _ref;

  Future<WhatsAppChangeOutcome> save(String raw) async {
    final phone = raw.trim();
    if (!isValidWhatsApp(phone)) return WhatsAppChangeOutcome.invalid;
    final user = _ref.read(currentUserProvider).value;
    if (user == null) return WhatsAppChangeOutcome.failed;
    final active = _ref.read(profileAppointmentsProvider).value?.active;
    try {
      await _ref
          .read(userRepositoryProvider)
          .updateWhatsApp(
            uid: user.uid,
            phone: phone,
            activeAppointmentId: active?.id,
          );
      return WhatsAppChangeOutcome.ok;
    } catch (error) {
      debugPrint('Error al cambiar el WhatsApp: $error');
      return WhatsAppChangeOutcome.failed;
    }
  }
}

final whatsAppChangeProvider = Provider(WhatsAppChanger.new);
