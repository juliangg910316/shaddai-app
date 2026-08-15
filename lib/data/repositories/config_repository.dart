import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_settings_model.dart';

class ConfigRepository {
  final FirebaseFirestore _firestore;

  ConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<CalendarSettingsModel> getCalendarSettings() {
    return _firestore
        .collection('settings')
        .doc('calendar')
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return CalendarSettingsModel.fromMap(doc.data()!);
      }
      // If document doesn't exist, return default settings
      return CalendarSettingsModel.defaultSettings();
    });
  }

  Future<void> updateSettings(CalendarSettingsModel settings) async {
    await _firestore
        .collection('settings')
        .doc('calendar')
        .set(settings.toMap(), SetOptions(merge: true));
  }
}
