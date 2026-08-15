import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String? clientPhotoUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'waiting_confirmation', 'confirmed', 'cancelled'
  final DateTime createdAt;

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
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> data, String id) {
    return AppointmentModel(
      id: id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientPhotoUrl: data['clientPhotoUrl'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'waiting_confirmation',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientPhotoUrl': clientPhotoUrl,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
