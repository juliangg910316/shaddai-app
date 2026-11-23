import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La configuración de los avisos push en Android e iOS (spec 011, plan
/// D-12, D-14; T10). Que se vean bien se comprueba a mano en
/// `specs/011-push/rules-check.md`; aquí se fija que la configuración está.
String read(String path) => File(path).readAsStringSync();

void main() {
  group('Android (plan D-12)', () {
    const res = 'android/app/src/main/res';

    test('el manifiesto declara el icono y el color de los avisos', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        contains('com.google.firebase.messaging.default_notification_icon'),
      );
      expect(manifest, contains('@drawable/ic_notification'));
      expect(
        manifest,
        contains('com.google.firebase.messaging.default_notification_color'),
      );
      expect(manifest, contains('@color/notification_color'));
    });

    // Sin esta marca, `register()` falla con "API disabled" y el
    // dispositivo nunca se registra (plan D-15).
    test('el manifiesto activa el registro por FID', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        matches(
          RegExp(
            r'android:name="firebase_messaging_installation_id_enabled"\s*'
            r'android:value="true"',
          ),
        ),
      );
    });

    test('el icono es un vector monocromo', () {
      final icon = read('$res/drawable/ic_notification.xml');
      expect(icon, contains('<vector'));
      expect(icon, contains('android:width="24dp"'));
      expect(icon, contains('android:height="24dp"'));
      expect(icon, contains('android:fillColor="#FFFFFFFF"'));
      expect(icon, contains('android:fillType="evenOdd"'));
    });

    test('el color es el verde de la marca', () {
      expect(
        read('$res/values/colors.xml'),
        contains('<color name="notification_color">#2E3D28</color>'),
      );
    });

    test('el canal de los avisos tiene nombre en español y portugués', () {
      expect(
        read('$res/values/strings.xml'),
        contains(
          '<string name="fcm_fallback_notification_channel_label">'
          'Avisos de turnos</string>',
        ),
      );
      expect(
        read('$res/values-pt/strings.xml'),
        contains(
          '<string name="fcm_fallback_notification_channel_label">'
          'Avisos de horários</string>',
        ),
      );
    });
  });

  group('iOS (plan D-14)', () {
    test('Runner.entitlements pide los avisos de Apple', () {
      final entitlements = read('ios/Runner/Runner.entitlements');
      expect(entitlements, contains('<key>aps-environment</key>'));
      expect(entitlements, contains('<string>development</string>'));
    });

    test('Info.plist recibe avisos en segundo plano', () {
      final plist = read('ios/Runner/Info.plist');
      expect(plist, contains('<key>UIBackgroundModes</key>'));
      expect(plist, contains('<string>remote-notification</string>'));
    });

    test('Info.plist activa el registro por FID (plan D-15)', () {
      final plist = read('ios/Runner/Info.plist');
      expect(
        plist,
        matches(
          RegExp(
            r'<key>FirebaseMessagingInstallationIdEnabled</key>\s*<true/>',
          ),
        ),
      );
    });

    test('el proyecto usa Runner.entitlements en sus tres '
        'configuraciones', () {
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(
          project,
        ),
        hasLength(3),
      );
      expect(project, contains('path = Runner.entitlements;'));
    });
  });
}
