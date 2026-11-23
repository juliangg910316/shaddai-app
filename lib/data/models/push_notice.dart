/// Los avisos push, como los ve la app (spec 011, plan D-8, D-11): sin
/// Firebase, para que las vistas y los providers no dependan de
/// `firebase_messaging`.
library;

/// El permiso de notificaciones de este dispositivo (plan D-8). Junta el
/// estado del sistema con la marca, guardada en el dispositivo, de que ya se
/// preguntó: en Android el sistema no distingue "nunca preguntado" de
/// "denegado".
enum PushPermission {
  /// Aún no se le ha pedido en este dispositivo (RF-15).
  notAsked,

  /// Concedido: el dispositivo se puede registrar (RF-18).
  granted,

  /// Denegado: no se vuelve a pedir (RF-17).
  denied,
}

/// Un aviso recibido: su título, su texto y sus datos (`kind`,
/// `appointmentId`, `day`; spec 011, RF-12, RF-14).
class PushNotice {
  const PushNotice({
    required this.title,
    required this.body,
    required this.data,
  });

  /// Desde las partes de un mensaje de FCM: sin título o texto, vacíos; los
  /// datos, como texto, sin los nulos.
  factory PushNotice.fromParts({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) => PushNotice(
    title: title ?? '',
    body: body ?? '',
    data: {
      for (final MapEntry(:key, :value) in data.entries)
        if (value != null) key: value.toString(),
    },
  );

  final String title;
  final String body;
  final Map<String, String> data;
}
