import 'booked_service_model.dart';

/// Un turno (`appointments/{uuid}`). Las fechas son `DateTime`: el
/// repositorio las convierte desde y hacia `Timestamp`, para que el modelo no
/// importe Firebase (spec 005, plan D-6).
class AppointmentModel {
  final String id;

  /// La cuenta de la clienta, o `null` si es una persona sin cuenta que
  /// agendó la admin (spec 007, RF-19).
  final String? clientId;
  final String clientName;
  final String clientPhone;
  final String? clientPhotoUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'waiting_confirmation', 'confirmed', 'cancelled'
  final DateTime createdAt;

  /// Lo reservado (spec 005, RF-27). `null` en los turnos guardados antes de
  /// la spec 005 (RF-51).
  final BookedServiceModel? booked;

  /// Si lo agendó la admin (spec 007, RF-19, RF-23).
  final bool createdByAdmin;

  AppointmentModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.clientPhotoUrl,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.booked,
    this.createdByAdmin = false,
  });

  /// Si el turno es de una clienta con cuenta (spec 007).
  bool get hasAccount => clientId != null;

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime _readDate(Object? value) =>
      value is DateTime ? value : _epoch;

  factory AppointmentModel.fromMap(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      clientId: switch (data['clientId']) {
        final String id when id.isNotEmpty => id,
        _ => null,
      },
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientPhotoUrl: data['clientPhotoUrl'],
      startTime: _readDate(data['startTime']),
      endTime: _readDate(data['endTime']),
      status: data['status'] ?? 'waiting_confirmation',
      createdAt: _readDate(data['createdAt']),
      booked: BookedServiceModel.fromMap(data['booked']),
      createdByAdmin: data['createdByAdmin'] == true,
    );
  }

  /// Escribe `clientId` siempre, también `null`: las reglas comprueban
  /// `== null` en la persona sin cuenta (spec 007, plan D-3).
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientPhotoUrl': clientPhotoUrl,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdAt': createdAt,
      'createdByAdmin': createdByAdmin,
      if (booked != null) 'booked': booked!.toMap(),
    };
  }
}
