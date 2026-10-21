import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/presentation/main_scaffold.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/profile/providers/profile_provider.dart';

/// Usuaria de prueba con sesión y WhatsApp registrado.
final testClient = UserModel(
  uid: 'u1',
  email: 'ana@example.com',
  displayName: 'Ana Herrera',
  phoneNumber: '+55 41 99999-0000',
);

/// Turno de prueba de [testClient] que empieza en [start].
AppointmentModel testAppointment(
  DateTime start, {
  String status = 'confirmed',
  String id = 'a1',
}) => AppointmentModel(
  id: id,
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber ?? '',
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  status: status,
  createdAt: DateTime(2026, 10, 1),
);

/// Overrides de sesión sin Firebase: sin sesión si [user] es `null`. Sus
/// turnos son [appointments] (ninguno por defecto).
List<Override> sessionOverrides({
  UserModel? user,
  List<AppointmentModel> appointments = const [],
}) => [
  currentUserProvider.overrideWith((ref) async => user),
  clientAppointmentsProvider.overrideWith((ref) => Stream.value(appointments)),
];

/// Mañana a las 0:00: un día que el calendario de Reservas siempre deja
/// elegir (no admite días pasados).
DateTime tomorrow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

/// Overrides de Reservas sin Firebase: sesión con [testClient], día elegido
/// [day] y los huecos libres [slots].
List<Override> bookingOverrides({
  required DateTime day,
  required AsyncValue<List<DateTime>> slots,
}) => [
  ...sessionOverrides(user: testClient),
  calendarSettingsProvider.overrideWith(
    (ref) => Stream.value(CalendarSettingsModel.defaultSettings()),
  ),
  selectedDateProvider.overrideWith((ref) => day),
  availableSlotsProvider.overrideWithValue(slots),
];

/// Router con la barra inferior real ([MainScaffold]) y Perfil real, que
/// arranca en [initialLocation]. Las demás pestañas y `/login` son páginas
/// con un botón y su nombre: como las reales, tienen algo enfocable, y así el
/// foco del teclado puede salir de la página hacia las barras.
GoRouter shellRouter({String initialLocation = '/profile'}) {
  GoRoute placeholder(String path) => GoRoute(
    path: path,
    builder: (context, state) => Scaffold(
      body: TextButton(onPressed: () {}, child: Text('page:$path')),
    ),
  );

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      placeholder('/login'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [placeholder('/home')]),
          StatefulShellBranch(routes: [placeholder('/services')]),
          StatefulShellBranch(routes: [placeholder('/booking')]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
