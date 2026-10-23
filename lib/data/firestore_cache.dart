import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Activa en Web la caché de Firestore en el navegador, para ver la lista de
/// precios sin conexión con los datos de la última visita (spec 004, RF-40,
/// D-10). En Android/iOS ya viene activa.
///
/// Si el navegador no la permite (modo privado, otra pestaña), la app sigue
/// con la caché en memoria, que dura mientras la página está abierta.
void configureFirestoreCache({
  required bool isWeb,
  FirebaseFirestore? firestore,
}) {
  if (!isWeb) return;
  try {
    (firestore ?? FirebaseFirestore.instance).settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint('Caché de Firestore no disponible en este navegador: $e');
  }
}
