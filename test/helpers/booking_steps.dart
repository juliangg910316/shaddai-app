import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/presentation/book_button.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import 'pump_app.dart';

/// Elige la hora [time] y el primer servicio de la lista de precios, y toca
/// "Agendar turno": abre el diálogo de confirmación (spec 005, RF-25).
/// [settle] deja llegar los cambios (`pumpAndSettle` o el de cada test).
Future<void> openBookingConfirmation(
  WidgetTester tester, {
  String time = '10:00',
  Future<void> Function()? settle,
}) async {
  final wait = settle ?? () => tester.pumpAndSettle();
  await tester.tap(find.text(time));
  await wait();

  final container = appContainer(tester);
  final catalog = container.read(
    bookableCatalogProvider,
  ) as PriceViewReady<BookableCatalog>;
  final service = catalog.value.categories.first.services.first;
  container
      .read(bookingSelectionProvider.notifier)
      .selectItem(BookableRef(BookedKind.service, service.id));
  await wait();

  // "Agendar turno" va al final de la lista: se baja hasta él.
  final scroll = container.read(tabScrollControllerProvider(MobileTab.booking));
  final button = find.descendant(
    of: find.byType(BookButton),
    matching: find.byType(ElevatedButton),
  );
  for (var i = 0; i < 10 && button.evaluate().isEmpty; i++) {
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
  }
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await wait();
}
