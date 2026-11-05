import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/presentation/main_scaffold.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import 'fake_booking.dart';

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
  currentUserProvider.overrideWith((ref) => Stream.value(user)),
  myAppointmentsProvider.overrideWith((ref) => Stream.value(appointments)),
];

/// Martes 10 de noviembre de 2026 a las 7:00 en Curitiba (10:00 UTC), antes
/// de abrir: el "ahora" fijo de los tests de la reserva (spec 005).
final bookingTestNow = DateTime.utc(2026, 11, 10, 10);

/// Overrides de la reserva de la spec 005 sin Firebase:
/// - turnos y turnos ocupados de [bookings];
/// - sesión con [user] (por defecto, [testClient]; `null` con [signedIn] a
///   `false`);
/// - calendario [settings] (por defecto, el de [CalendarSettingsModel]);
/// - "ahora" fijo [now] (por defecto, [bookingTestNow]), sin el temporizador
///   de `salonNowProvider`;
/// - dispositivo con la diferencia con UTC [deviceOffset] (por defecto, la
///   del salón).
///
/// Para cambiarlos durante el test, [userStream] sustituye a la sesión y
/// [nowStream] a "ahora" (horas de pared del salón); se vuelven a llamar al
/// invalidar su provider.
List<Override> bookingDataOverrides({
  required FakeBookingRepository bookings,
  UserModel? user,
  bool signedIn = true,
  CalendarSettingsModel? settings,
  DateTime? now,
  Duration deviceOffset = salonUtcOffset,
  Stream<UserModel?> Function()? userStream,
  Stream<DateTime> Function()? nowStream,
}) {
  final profile = signedIn ? (user ?? testClient) : null;
  return [
    currentUserProvider.overrideWith(
      (ref) => userStream?.call() ?? Stream.value(profile),
    ),
    ...bookingScheduleOverrides(
      bookings: bookings,
      settings: settings,
      now: now,
      deviceOffset: deviceOffset,
      nowStream: nowStream,
    ),
  ];
}

/// [bookingDataOverrides] sin la sesión, para los tests que la ponen ellos
/// (`pumpWebApp`, `pumpMobileApp`).
List<Override> bookingScheduleOverrides({
  required FakeBookingRepository bookings,
  CalendarSettingsModel? settings,
  DateTime? now,
  Duration deviceOffset = salonUtcOffset,
  Stream<DateTime> Function()? nowStream,
}) {
  final instant = now ?? bookingTestNow;
  return [
    bookingRepositoryProvider.overrideWithValue(bookings),
    calendarSettingsProvider.overrideWith(
      (ref) =>
          Stream.value(settings ?? CalendarSettingsModel.defaultSettings()),
    ),
    clockProvider.overrideWithValue(() => instant),
    salonNowProvider.overrideWith(
      (ref) => nowStream?.call() ?? Stream.value(toSalon(instant)),
    ),
    deviceUtcOffsetProvider.overrideWithValue(deviceOffset),
  ];
}

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
