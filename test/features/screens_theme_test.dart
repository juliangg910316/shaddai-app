import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/features/auth/presentation/login_view.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/auth/providers/auth_failure.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_settings_view.dart';
import 'package:shaddai/features/admin/presentation/admin_users_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/home/presentation/home_view.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/profile/providers/profile_provider.dart';
import 'package:shaddai/features/services/presentation/services_view.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_session.dart';
import '../helpers/pump_app.dart';

/// Una pantalla existente en uno de sus estados, con los providers que
/// necesita sin Firebase. Cada tarea de migración de la spec 001 añade las
/// suyas (RF-15, RF-16).
class _Screen {
  const _Screen(this.name, this.build, {this.overrides = const []});

  final String name;
  final Widget Function() build;
  final List<Override> overrides;
}

class _StubAuthController extends AuthController {
  _StubAuthController(AsyncValue<void> initial)
    : super(FakeAuthRepository(), FakeUserRepository()) {
    state = initial;
  }
}

final _screens = <_Screen>[
  _Screen(
    'Login',
    () => const LoginView(),
    overrides: [
      authControllerProvider.overrideWith(
        (ref) => _StubAuthController(const AsyncData(null)),
      ),
    ],
  ),
  _Screen(
    'Login con error',
    () => const LoginView(),
    overrides: [
      authControllerProvider.overrideWith(
        (ref) => _StubAuthController(
          AsyncError(AuthFailure.blocked, StackTrace.empty),
        ),
      ),
    ],
  ),
  _Screen(
    'Login cargando',
    () => const LoginView(),
    overrides: [
      authControllerProvider.overrideWith(
        (ref) => _StubAuthController(const AsyncLoading()),
      ),
    ],
  ),
  _Screen(
    'Captura de WhatsApp',
    () => const PhoneCaptureView(),
    overrides: sessionOverrides(user: testClient),
  ),
  // El mapa es una vista nativa que no se pinta en los tests: se sustituye.
  _Screen(
    'Inicio sin sesión',
    () => const HomeView(map: SizedBox(height: 120)),
    overrides: sessionOverrides(),
  ),
  _Screen(
    'Inicio con sesión',
    () => const HomeView(map: SizedBox(height: 120)),
    overrides: sessionOverrides(user: testClient),
  ),
  _Screen('Servicios', () => const ServicesView()),
  _Screen(
    'Reservas con huecos',
    () => const BookingView(),
    overrides: bookingOverrides(
      day: tomorrow(),
      slots: AsyncData([tomorrow().add(const Duration(hours: 10))]),
    ),
  ),
  _Screen(
    'Reservas sin huecos',
    () => const BookingView(),
    overrides: bookingOverrides(day: tomorrow(), slots: const AsyncData([])),
  ),
  _Screen(
    'Reservas cargando',
    () => const BookingView(),
    overrides: bookingOverrides(day: tomorrow(), slots: const AsyncLoading()),
  ),
  _Screen(
    'Reservas con error',
    () => const BookingView(),
    overrides: bookingOverrides(
      day: tomorrow(),
      slots: AsyncError(Exception('permission-denied'), StackTrace.empty),
    ),
  ),
  _Screen(
    'Perfil sin sesión',
    () => const ProfileView(),
    overrides: sessionOverrides(),
  ),
  _Screen(
    'Perfil con turnos en los tres estados',
    () => const ProfileView(),
    overrides: sessionOverrides(
      user: testClient,
      appointments: [
        testAppointment(DateTime(2026, 11, 3, 10), status: 'confirmed'),
        testAppointment(
          DateTime(2026, 11, 4, 11),
          status: 'waiting_confirmation',
          id: 'a2',
        ),
        testAppointment(
          DateTime(2026, 11, 5, 12),
          status: 'cancelled',
          id: 'a3',
        ),
      ],
    ),
  ),
  _Screen(
    'Perfil de admin',
    () => const ProfileView(),
    overrides: sessionOverrides(
      user: UserModel(
        uid: 'admin',
        email: 'beidis@example.com',
        displayName: 'Beidis Viera',
        phoneNumber: '+55 41 98888-0000',
        role: 'admin',
      ),
    ),
  ),
  _Screen(
    'Perfil con error al cargar los turnos',
    () => const ProfileView(),
    overrides: [
      currentUserProvider.overrideWith((ref) async => testClient),
      clientAppointmentsProvider.overrideWith(
        (ref) => Stream.error(Exception('permission-denied')),
      ),
    ],
  ),
  _Screen(
    'Admin: agenda con turnos en los tres estados',
    () => const AdminDashboardView(),
    overrides: [
      adminAppointmentsProvider.overrideWith(
        (ref) => Stream.value([
          testAppointment(DateTime(2026, 11, 3, 10), status: 'confirmed'),
          testAppointment(
            DateTime(2026, 11, 3, 11),
            status: 'waiting_confirmation',
            id: 'a2',
          ),
          testAppointment(
            DateTime(2026, 11, 3, 12),
            status: 'cancelled',
            id: 'a3',
          ),
        ]),
      ),
    ],
  ),
  _Screen(
    'Admin: agenda vacía',
    () => const AdminDashboardView(),
    overrides: [
      adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  ),
  _Screen(
    'Admin: agenda con error',
    () => const AdminDashboardView(),
    overrides: [
      adminAppointmentsProvider.overrideWith(
        (ref) => Stream.error(Exception('permission-denied')),
      ),
    ],
  ),
  _Screen(
    'Admin: clientas activas y bloqueadas',
    () => const AdminUsersView(),
    overrides: [
      adminUsersProvider.overrideWith(
        (ref) => Stream.value([
          testClient,
          UserModel(
            uid: 'u2',
            email: 'bea@example.com',
            displayName: 'Bea Souza',
            isBlocked: true,
          ),
        ]),
      ),
    ],
  ),
  _Screen(
    'Admin: sin clientas',
    () => const AdminUsersView(),
    overrides: [
      adminUsersProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  ),
  // En la app, la configuración ya está cargada por Reservas: aquí se escucha
  // con un Consumer para que lo esté también.
  _Screen(
    'Admin: ajustes del calendario',
    () => Consumer(
      builder: (context, ref, _) => ref.watch(calendarSettingsProvider).hasValue
          ? const AdminSettingsView()
          : const Scaffold(body: SizedBox.shrink()),
    ),
    overrides: [
      calendarSettingsProvider.overrideWith(
        (ref) => Stream.value(CalendarSettingsModel.defaultSettings()),
      ),
    ],
  ),
];

void main() {
  for (final screen in _screens) {
    for (final (theme, brand) in [
      ('light', BrandColors.light),
      ('dark', BrandColors.dark),
    ]) {
      testWidgets('${screen.name} en tema $theme usa el tema y se lee bien '
          '(RF-15, RF-16)', (tester) async {
        await pumpApp(
          tester,
          stored: {'theme': theme, 'language': 'es'},
          home: screen.build(),
          overrides: screen.overrides,
        );
        // Dos fotogramas: el segundo recibe los datos de los streams falsos.
        // (Sin pumpAndSettle: los indicadores de carga giran sin fin.)
        await tester.pump();
        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final context = tester.element(find.byType(Scaffold).first);
        expect(
          scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          brand.background,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  }
}
