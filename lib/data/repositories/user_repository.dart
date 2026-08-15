import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(
      user.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> updatePhoneNumber(String uid, String phoneNumber) async {
    await _firestore.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  // ADMIN METHODS
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
