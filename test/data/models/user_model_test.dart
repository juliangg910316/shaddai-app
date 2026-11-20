import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/user_model.dart';

/// `fcmToken` queda obsoleto: los dispositivos de la admin van en
/// `users/{uid}/pushDevices` (spec 011, plan D-13, T4).
void main() {
  test('toMap ya no escribe fcmToken', () {
    final user = UserModel(
      uid: 'beidis',
      email: 'beidis@example.com',
      displayName: 'Beidis',
      role: 'admin',
      fcmToken: 'token-antiguo',
    );
    expect(user.toMap().containsKey('fcmToken'), isFalse);
  });

  test('fromMap sigue leyendo las fichas antiguas que lo tienen', () {
    final user = UserModel.fromMap({
      'email': 'ana@example.com',
      'displayName': 'Ana',
      'role': 'cliente',
      'fcmToken': 'token-antiguo',
    }, 'ana');
    expect(user.fcmToken, 'token-antiguo');
    expect(user.displayName, 'Ana');
  });

  test('y las que no lo tienen', () {
    final user = UserModel.fromMap({'email': 'ana@example.com'}, 'ana');
    expect(user.fcmToken, isNull);
  });
}
