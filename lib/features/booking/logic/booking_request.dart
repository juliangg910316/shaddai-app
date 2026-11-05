/// El servicio o combo pedido en la dirección de la reserva
/// (`/booking?service=<id>` o `/booking?combo=<id>`), sin Flutter ni
/// Firebase (spec 005, RF-40 a RF-44, D-9).
library;

import '../../../data/models/booked_service_model.dart';
import 'bookable_catalog.dart';

/// Lo pedido en [query], o `null` si no pide nada o pide dos cosas. Un id
/// que no existe se pide igual: al llegar la lista, se quita y se avisa
/// (RF-44).
BookableRef? bookingRequestOf(Map<String, String> query) {
  final service = query['service'];
  final combo = query['combo'];
  if (service != null && combo == null) {
    return BookableRef(BookedKind.service, service);
  }
  if (combo != null && service == null) {
    return BookableRef(BookedKind.combo, combo);
  }
  return null;
}

/// La dirección de la reserva que pide [ref] (RF-40).
String bookingLocationOf(BookableRef ref) => Uri(
  path: '/booking',
  queryParameters: {ref.kind == BookedKind.combo ? 'combo' : 'service': ref.id},
).toString();
