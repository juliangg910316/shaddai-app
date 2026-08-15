import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class BookingRepository {
  final FirebaseFirestore _firestore;

  BookingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createAppointment(AppointmentModel appointment) async {
    await _firestore.collection('appointments').doc(appointment.id).set(appointment.toMap());
  }

  Stream<List<AppointmentModel>> getAppointmentsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _firestore
        .collection('appointments')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Para el cliente: solo ver las ocupadas activas (no canceladas)
  Stream<List<AppointmentModel>> getActiveAppointmentsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _firestore
        .collection('appointments')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .where('status', whereIn: ['waiting_confirmation', 'confirmed'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<AppointmentModel>> getClientAppointments(String clientId) {
    return _firestore
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ADMIN METHODS
  Future<void> updateAppointmentStatus(String id, String status) async {
    await _firestore.collection('appointments').doc(id).update({
      'status': status,
    });
  }
}
