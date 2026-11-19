import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  /// Cuánto se espera a que un guardado termine antes de darlo por fallido.
  final Duration saveTimeout;

  UserRepository({
    FirebaseFirestore? firestore,
    this.saveTimeout = const Duration(seconds: 15),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  /// La ficha de [uid] y cada cambio, o `null` si no existe (spec 005,
  /// RF-38).
  Stream<UserModel?> watchUser(String uid) =>
      _firestore.collection('users').doc(uid).snapshots().map((doc) {
        final data = doc.data();
        return doc.exists && data != null ? UserModel.fromMap(data, uid) : null;
      });

  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updatePhoneNumber(String uid, String phoneNumber) async {
    await _firestore.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
    });
  }

  /// Cambia el WhatsApp de [uid] y, si tiene turno activo
  /// ([activeAppointmentId]), el de ese turno, en un solo lote: o cambian
  /// los dos o ninguno (spec 009, RF-28, RF-30, plan D-6). Las reglas exigen
  /// que el número del turno sea el de la ficha tras el lote.
  Future<void> updateWhatsApp({
    required String uid,
    required String phone,
    String? activeAppointmentId,
  }) {
    final batch = _firestore.batch()
      ..update(_firestore.collection('users').doc(uid), {'phoneNumber': phone});
    if (activeAppointmentId != null) {
      batch.update(
        _firestore.collection('appointments').doc(activeAppointmentId),
        {'clientPhone': phone},
      );
    }
    return batch.commit().timeout(saveTimeout);
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  // ADMIN METHODS

  /// Lee **del servidor** la ficha de [uid], o `null` si no existe. La usa
  /// la admin justo antes de agendar, para no fiarse de una copia vieja
  /// (spec 007, RF-15, RF-18). Sin conexión falla.
  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    return doc.exists && data != null ? UserModel.fromMap(data, uid) : null;
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> toggleBlockUser(String uid, bool isBlocked) async {
    await _firestore.collection('users').doc(uid).update({
      'isBlocked': isBlocked,
    });
  }
}
