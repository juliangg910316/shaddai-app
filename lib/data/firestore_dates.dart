import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversión de fechas entre Firestore y los modelos: los modelos usan
/// `DateTime` y no importan Firebase (spec 005, plan D-6). Solo convierte los
/// campos de primer nivel.

/// [data] con cada `Timestamp` como `DateTime` en hora local, como
/// `Timestamp.toDate`.
Map<String, dynamic> decodeDates(Map<String, dynamic> data) => {
  for (final entry in data.entries)
    entry.key: entry.value is Timestamp
        ? (entry.value as Timestamp).toDate()
        : entry.value,
};

/// [data] con cada `DateTime` como `Timestamp`.
Map<String, dynamic> encodeDates(Map<String, dynamic> data) => {
  for (final entry in data.entries)
    entry.key: entry.value is DateTime
        ? Timestamp.fromDate(entry.value as DateTime)
        : entry.value,
};
