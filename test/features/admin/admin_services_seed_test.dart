import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_services_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// Calendario con una duración global del turno de [minutes].
class _FakeConfigRepository implements ConfigRepository {
  _FakeConfigRepository(this.minutes);

  final int minutes;

  @override
  Stream<CalendarSettingsModel> getCalendarSettings() => Stream.value(
    CalendarSettingsModel(
      openingHours: CalendarSettingsModel.defaultSettings().openingHours,
      globalSlotDurationMinutes: minutes,
      blockedDates: const [],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Overrides del panel sin Firebase: agenda vacía y turnos de 45 minutos.
List<Override> _adminOverrides() => [
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
  configRepositoryProvider.overrideWithValue(_FakeConfigRepository(45)),
];

/// Gestión de servicios en Android/iOS, con la admin y [repository].
Future<void> _pumpServices(
  WidgetTester tester,
  FakePriceListRepository repository,
) => pumpMobileApp(
  tester,
  location: '/admin/services',
  user: testAdmin,
  priceListRepository: repository,
  overrides: _adminOverrides(),
);

const _seedButton = 'CARGAR LA LISTA DE PRECIOS ACTUAL';

Finder _inServices(Finder finder) =>
    find.descendant(of: find.byType(AdminServicesView), matching: finder);

Future<void> _confirmSeed(WidgetTester tester) async {
  await tester.tap(_inServices(find.text(_seedButton)));
  await settleWeb(tester);
  await tester.tap(find.text('CARGAR'));
  await settleWeb(tester);
}

void main() {
  group('entrada desde el panel (RF-19)', () {
    testWidgets('en Android/iOS, el icono "Servicios" de la cabecera abre la '
        'gestión', (tester) async {
      await pumpMobileApp(
        tester,
        location: '/admin',
        user: testAdmin,
        overrides: _adminOverrides(),
      );

      // Como Usuarias y Ajustes, se abre encima del panel (`push`).
      await tester.tap(find.byTooltip('Servicios'));
      await settleWeb(tester);

      expect(find.byType(AdminServicesView), findsOneWidget);
    });

    testWidgets('en Web, igual', (tester) async {
      await pumpWebApp(
        tester,
        location: '/admin',
        user: testAdmin,
        overrides: _adminOverrides(),
      );

      // Como Usuarias y Ajustes, se abre encima del panel (`push`).
      await tester.tap(find.byTooltip('Servicios'));
      await settleWeb(tester);

      expect(find.byType(AdminServicesView), findsOneWidget);
    });

    testWidgets('en Web, una clienta que abre la dirección vuelve a la '
        'landing', (tester) async {
      await pumpWebApp(
        tester,
        location: '/admin/services',
        user: testClient,
        overrides: _adminOverrides(),
      );

      expect(webLocation(tester).path, '/');
      expect(find.byType(AdminServicesView), findsNothing);
    });
  });

  group('carga inicial (RF-35 a RF-39)', () {
    testWidgets('sin lista, el botón de carga pide confirmación; al cancelar '
        'no se carga nada', (tester) async {
      final repository = FakePriceListRepository();
      await _pumpServices(tester, repository);

      expect(_inServices(find.text('Todavía no hay servicios.')), findsOne);
      await tester.tap(_inServices(find.text(_seedButton)));
      await settleWeb(tester);

      expect(find.text('¿Cargar la lista de precios actual?'), findsOneWidget);
      await tester.tap(find.text('CANCELAR'));
      await settleWeb(tester);

      expect(repository.seedCalls, 0);
      expect(repository.stored, isNull);
    });

    testWidgets('al confirmar, se carga con la duración global del turno y '
        'se ve la lista', (tester) async {
      final repository = FakePriceListRepository();
      await _pumpServices(tester, repository);

      await _confirmSeed(tester);

      expect(repository.seedCalls, 1);
      final stored = repository.stored!;
      expect(stored.categories, hasLength(6));
      expect(stored.combos, hasLength(3));
      final services = stored.categories
          .expand((c) => c.items)
          .where((item) => item.isService);
      expect(services.every((item) => item.durationMinutes == 45), isTrue);

      expect(_inServices(find.text(_seedButton)), findsNothing);
      expect(_inServices(find.text('Manos')), findsOneWidget);
      expect(find.text('Cambios guardados'), findsOneWidget);
    });

    testWidgets('con la lista ya cargada, no hay botón de carga (RF-38)', (
      tester,
    ) async {
      await _pumpServices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      expect(_inServices(find.text(_seedButton)), findsNothing);
      expect(_inServices(find.text('Spa de manos')), findsOneWidget);
      expect(_inServices(find.text('Gel Completo')), findsOneWidget);
    });

    testWidgets('un documento vacío (todo borrado) vuelve a ofrecer la carga', (
      tester,
    ) async {
      final repository = FakePriceListRepository(
        stored: const PriceListModel(),
      );
      await _pumpServices(tester, repository);

      await _confirmSeed(tester);

      expect(repository.stored!.categories, hasLength(6));
    });

    testWidgets('si otra admin cargó la lista entre medias, no se duplica ni '
        'se muestra un error (RF-38)', (tester) async {
      final repository = FakePriceListRepository();
      await _pumpServices(tester, repository);

      // Otra admin la carga sin que esta pantalla se haya enterado aún.
      final other = testPriceList();
      repository.stored = other;
      await _confirmSeed(tester);

      expect(repository.seedCalls, 1);
      expect(repository.stored, same(other));
      expect(find.text('No se pudieron guardar los cambios.'), findsNothing);
    });

    testWidgets('si falla, no queda nada creado y se puede reintentar '
        '(RF-39, RNF-6)', (tester) async {
      final repository = FakePriceListRepository()
        ..failNext = Exception('unavailable: detalle técnico');
      await _pumpServices(tester, repository);

      await _confirmSeed(tester);

      expect(repository.stored, isNull);
      expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
      expect(find.textContaining('detalle técnico'), findsNothing);

      await tester.tap(find.text('REINTENTAR'));
      await settleWeb(tester);

      expect(repository.seedCalls, 2);
      expect(repository.stored!.categories, hasLength(6));
    });
  });

  testWidgets('sin poder cargar la lista, aviso con "Reintentar"', (
    tester,
  ) async {
    final repository = FakePriceListRepository(autoEmit: false);
    await _pumpServices(tester, repository);

    repository.emitError(Exception('permission-denied'));
    await tester.pump();
    await tester.pump();

    expect(_inServices(find.text('REINTENTAR')), findsOneWidget);
    expect(_inServices(find.text(_seedButton)), findsNothing);
  });
}
