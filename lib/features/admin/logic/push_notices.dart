/// Los avisos push de la admin en la app, sin Flutter ni Firebase (spec 011,
/// plan § 4).
///
/// Solo la admin, y solo en Android/iOS, recibe avisos: en Web y para
/// clientas y visitantes, todas devuelven `false` (RF-16, Plataformas).
library;

import '../../../data/models/push_notice.dart';
import '../../../data/models/user_model.dart';
import 'admin_agenda.dart';

bool _isAdminOnMobile(bool isWeb, UserModel? user) =>
    !isWeb && user?.role == 'admin';

/// Si hay que explicarle a la admin los avisos y pedirle el permiso: aún no
/// se le ha pedido en este dispositivo (RF-15).
bool shouldExplainPush({
  required bool isWeb,
  required UserModel? user,
  required PushPermission? permission,
}) => _isAdminOnMobile(isWeb, user) && permission == PushPermission.notAsked;

/// Si este dispositivo se registra para recibir avisos: la admin concedió el
/// permiso (RF-18).
bool shouldRegisterDevice({
  required bool isWeb,
  required UserModel? user,
  required PushPermission? permission,
}) => _isAdminOnMobile(isWeb, user) && permission == PushPermission.granted;

/// Si el panel avisa de que los avisos están desactivados: la admin denegó
/// el permiso (RF-17).
bool showPushDisabled({
  required bool isWeb,
  required UserModel? user,
  required PushPermission? permission,
}) => _isAdminOnMobile(isWeb, user) && permission == PushPermission.denied;

/// Si hay que anular el token que no se pudo anular al cerrar sesión: queda
/// la marca y la sesión ya no es de admin (RF-20, plan D-7). Con la admin
/// otra vez dentro no se anula: se vuelve a registrar.
bool shouldRevokeToken({
  required bool pendingRevoke,
  required UserModel? user,
}) => pendingRevoke && user?.role != 'admin';

final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// El día del salón del turno de un aviso, de su dato `day` (`YYYY-MM-DD`),
/// o `null` si falta, tiene otro formato o no existe (RF-12).
DateTime? noticeDay(Map<String, String> data) {
  final match = _dayPattern.firstMatch(data['day'] ?? '');
  if (match == null) return null;
  final [year, month, day] = [
    for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
  ];
  final date = agendaDay(DateTime.utc(year, month, day));
  // `DateTime` acepta el 30 de febrero (lo pasa a marzo): no es un día real.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
