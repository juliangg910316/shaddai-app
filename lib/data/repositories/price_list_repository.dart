import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/price_list_model.dart';

/// El documento de la lista de precios no existe todavía.
class PriceListMissing implements Exception {
  const PriceListMissing();
}

/// La carga inicial se pidió con la lista ya creada (RF-38).
class PriceListAlreadySeeded implements Exception {
  const PriceListAlreadySeeded();
}

/// Lista de precios del salón: el documento único `settings/priceList`
/// (spec 004, plan § 2, D-1).
class PriceListRepository {
  final FirebaseFirestore _firestore;

  PriceListRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection('settings').doc('priceList');

  /// El documento y cada cambio, indicando si viene de la caché del
  /// dispositivo. Con los cambios de metadatos llega también la confirmación
  /// del servidor de un documento que no existe (RF-10, RF-40).
  Stream<PriceListSnapshot> watch() => _document
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => PriceListSnapshot(
          list: snapshot.exists && snapshot.data() != null
              ? PriceListModel.fromMap(snapshot.data()!, onInvalid: debugPrint)
              : null,
          fromCache: snapshot.metadata.isFromCache,
        ),
      );

  /// Aplica [transform] a la lista guardada en una transacción, para no
  /// pisar los cambios de otra admin en otros elementos (D-3). Lanza
  /// [PriceListMissing] si el documento no existe; los errores de
  /// [transform] (p. ej. un elemento que ya no existe) se propagan.
  Future<void> update(
    PriceListModel Function(PriceListModel current) transform,
  ) => _firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(_document);
    final data = snapshot.data();
    if (!snapshot.exists || data == null) throw const PriceListMissing();
    final next = transform(PriceListModel.fromMap(data, onInvalid: debugPrint));
    transaction.set(_document, _withTimestamp(next));
  });

  /// Crea la lista con [initial] si no hay ningún elemento guardado (el
  /// documento no existe o se borró todo). En una transacción: o se crea
  /// entera o no se crea (RF-39), y una segunda petición encuentra los
  /// elementos y lanza [PriceListAlreadySeeded] (RF-38).
  Future<void> seed(PriceListModel initial) =>
      _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(_document);
        final data = snapshot.data();
        if (snapshot.exists &&
            data != null &&
            PriceListModel.fromMap(data).hasContent) {
          throw const PriceListAlreadySeeded();
        }
        transaction.set(_document, _withTimestamp(initial));
      });

  Map<String, dynamic> _withTimestamp(PriceListModel list) => {
    ...list.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
