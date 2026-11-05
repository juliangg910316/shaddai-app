import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/presentation/price_list_notices.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00; el calendario por defecto abre
// de 9:00 a 18:00, así que las 17:00 tienen 1 h libre.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

PriceItemModel service(
  String id,
  String name,
  int cents,
  int minutes, {
  bool from = false,
  bool visible = true,
}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.service,
  name: text(name),
  priceCents: cents,
  priceFrom: from,
  durationMinutes: minutes,
  visible: visible,
);

PriceItemModel addon(String id, String name, int cents) => PriceItemModel(
  id: id,
  kind: PriceItemKind.addon,
  name: text(name),
  priceCents: cents,
);

/// Manos (Manicura, Esmaltado "desde", Decoración), Pies (Pedicura), una
/// categoría solo con adicionales, una categoría oculta y dos combos, uno
/// oculto.
PriceListModel priceList({bool manicuraVisible = true}) => PriceListModel(
  categories: [
    PriceCategoryModel(
      id: 'manos',
      name: text('Manos'),
      items: [
        service('s1', 'Manicura', 3000, 45, visible: manicuraVisible),
        service('s2', 'Esmaltado', 2000, 30, from: true),
        addon('a1', 'Decoración', 1000),
        service('h1', 'Oculto', 1000, 30, visible: false),
      ],
    ),
    PriceCategoryModel(
      id: 'pies',
      name: text('Pies'),
      items: [service('p1', 'Pedicura', 4000, 60)],
    ),
    PriceCategoryModel(
      id: 'extras',
      name: text('Solo extras'),
      items: [addon('a2', 'Brillo', 500)],
    ),
    PriceCategoryModel(
      id: 'oculta',
      name: text('Categoría oculta'),
      visible: false,
      items: [service('o1', 'Escondido', 1000, 30)],
    ),
  ],
  combos: [
    ComboModel(
      id: 'c1',
      name: text('Pies y manos'),
      priceCents: 7000,
      durationMinutes: 90,
    ),
    ComboModel(
      id: 'c2',
      name: text('Combo oculto'),
      priceCents: 9000,
      durationMinutes: 60,
      visible: false,
    ),
  ],
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakePriceListRepository prices;

  setUp(() {
    bookings = FakeBookingRepository();
    prices = FakePriceListRepository(stored: priceList());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const BookingView(),
      priceListRepository: prices,
      overrides: bookingDataOverrides(bookings: bookings),
    );
    await settle(tester);
  }

  BookableRef? item(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection.item;

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> tapAction(WidgetTester tester) =>
      tap(tester, find.text('AGENDAR TURNO'));

  testWidgets('servicios por categoría y en orden, después los combos, con '
      'precio y duración (RF-10, RF-11)', (tester) async {
    await pump(tester);

    final order = [
      'Manos',
      'Manicura',
      'Esmaltado',
      'Pies',
      'Pedicura',
      'Pies y manos',
    ];
    final tops = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    expect(tops, orderedEquals([...tops]..sort()));

    expect(find.text('R\$ 30 · 45 min'), findsOneWidget);
    expect(find.text('desde R\$ 20 · 30 min'), findsOneWidget);
    expect(find.text('R\$ 70 · 1 h 30 min'), findsOneWidget);
    for (final hidden in [
      'Oculto',
      'Solo extras',
      'Categoría oculta',
      'Escondido',
      'Combo oculto',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
  });

  testWidgets('con una hora elegida, lo que no cabe se ve desactivado y '
      'avisa con su duración (RF-12, RF-13)', (tester) async {
    await pump(tester);
    await tap(tester, find.text('17:00'));

    expect(
      find.bySemanticsLabel(RegExp(r'^Pies y manos.*no disponible$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Pedicura.*disponible$')),
      findsNothing,
    );

    await tap(tester, find.text('Pies y manos'));
    expect(item(tester), isNull);
    expect(
      find.text(
        'Este servicio dura 1 h 30 min: elige una hora con más tiempo libre.',
      ),
      findsOneWidget,
    );

    await tap(tester, find.text('Pedicura'));
    expect(item(tester), const BookableRef(BookedKind.service, 'p1'));
  });

  testWidgets('sin hora, todos se pueden elegir (RF-14)', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('no disponible')), findsNothing);

    await tap(tester, find.text('Pies y manos'));
    expect(item(tester), const BookableRef(BookedKind.combo, 'c1'));
  });

  testWidgets('los adicionales del servicio aparecen sin marcar, y un combo '
      'no tiene (RF-18, RF-19)', (tester) async {
    await pump(tester);
    expect(find.text('Decoración'), findsNothing);

    await tap(tester, find.text('Manicura'));
    expect(find.text('Adicionales'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(find.text('Brillo'), findsNothing);

    await tap(tester, find.text('Pies y manos'));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Adicionales'), findsNothing);
  });

  testWidgets('tocar otra vez el servicio elegido lo quita, con sus '
      'adicionales (RF-59)', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Manicura'));
    await tap(tester, find.text('Decoración'));
    expect(find.text('Adicionales'), findsOneWidget);

    // El resumen también dice "Manicura": se toca la del selector.
    await tap(tester, find.text('Manicura').first);
    expect(item(tester), isNull);
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.addonIds,
      isEmpty,
    );
    expect(find.text('Adicionales'), findsNothing);
  });

  testWidgets('tocar otra vez la hora elegida la quita, y lo que no cabía '
      'vuelve a activarse (RF-59)', (tester) async {
    await pump(tester);
    await tap(tester, find.text('17:00'));
    expect(
      find.bySemanticsLabel(RegExp(r'^Pies y manos.*no disponible$')),
      findsOneWidget,
    );

    // El resumen también dice "17:00": se toca la de la rejilla.
    await tap(tester, find.text('17:00').first);
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.start,
      isNull,
    );
    expect(find.bySemanticsLabel(RegExp('no disponible')), findsNothing);
  });

  testWidgets('cambiar de servicio desmarca los adicionales (RF-20)', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.text('Manicura'));
    await tap(tester, find.text('Decoración'));
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.addonIds,
      {'a1'},
    );

    await tap(tester, find.text('Esmaltado'));
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.addonIds,
      isEmpty,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('un servicio que se oculta se quita y avisa (RF-17)', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.text('Manicura'));

    prices.change(priceList(manicuraVisible: false));
    await settle(tester);
    expect(item(tester), isNull);
    expect(find.text('Manicura'), findsNothing);
    expect(
      find.text('El servicio elegido ya no está disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('el resumen aparece con una hora o con un servicio, con el '
      'total y "desde" (RF-22)', (tester) async {
    await pump(tester);
    expect(find.text('Resumen'), findsNothing);

    await tap(tester, find.text('10:00'));
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Martes, 10 de noviembre de 2026'), findsOneWidget);

    await tap(tester, find.text('Esmaltado'));
    await tap(tester, find.text('Decoración'));
    final summary = find.byKey(const ValueKey('bookingSummary'));
    Finder inSummary(String t) =>
        find.descendant(of: summary, matching: find.text(t));
    expect(inSummary('10:00 – 10:30'), findsOneWidget);
    expect(inSummary('Esmaltado'), findsOneWidget);
    expect(inSummary('Decoración · +R\$ 10'), findsOneWidget);
    expect(inSummary('30 min'), findsOneWidget);
    expect(inSummary('desde R\$ 30'), findsOneWidget);
  });

  testWidgets('"Agendar turno" sin nada elegido marca lo que falta (RF-23, '
      'RF-24)', (tester) async {
    await pump(tester);
    await tapAction(tester);

    expect(find.text('Elige una hora'), findsOneWidget);
    expect(find.text('Elige un servicio'), findsOneWidget);
    expect(
      find.text('Elige una hora y un servicio para agendar.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);

    await tap(tester, find.text('10:00'));
    expect(find.text('Elige una hora'), findsNothing);
    expect(find.text('Elige un servicio'), findsOneWidget);
  });

  testWidgets('con todo elegido, abre el diálogo con el resumen y "esperando '
      'la confirmación de Beidis" (RF-25)', (tester) async {
    await pump(tester);
    await tap(tester, find.text('10:00'));
    await tap(tester, find.text('Manicura'));
    await tapAction(tester);

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    Finder inDialog(String t) =>
        find.descendant(of: dialog, matching: find.text(t));
    expect(inDialog('Confirmar turno'), findsOneWidget);
    expect(inDialog('Manicura'), findsOneWidget);
    expect(inDialog('10:00 – 10:45'), findsOneWidget);
    expect(
      inDialog('El turno quedará esperando la confirmación de Beidis.'),
      findsOneWidget,
    );
    expect(bookings.created, isEmpty);

    await tap(tester, find.text('CANCELAR'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.created, isEmpty);
  });

  testWidgets('con la lista de precios no disponible, su aviso y "Agendar '
      'turno" sigue activo (RF-47)', (tester) async {
    prices = FakePriceListRepository(autoEmit: false);
    await pump(tester);
    prices.emitError(Exception('unavailable'));
    await settle(tester);

    expect(find.byType(PriceListUnavailableNotice), findsOneWidget);
    await tap(tester, find.text('10:00'));
    await tapAction(tester);
    // La marca de la sección y el aviso, con el mismo texto.
    expect(find.text('Elige un servicio'), findsNWidgets(2));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
