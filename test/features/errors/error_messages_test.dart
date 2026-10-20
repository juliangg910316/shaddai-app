import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_users_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/presentation/login_view.dart';
import 'package:shaddai/features/auth/providers/auth_failure.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/profile/providers/profile_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// Texto técnico de los errores falsos: nunca debe verse.
const _technical = 'permission-denied';

ProviderContainer _authContainer(
  FakeAuthRepository auth,
  FakeUserRepository users,
) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final _blockedClient = UserModel(
  uid: 'u1',
  email: 'ana@example.com',
  displayName: 'Ana Herrera',
  isBlocked: true,
);

/// Pantalla de inicio de sesión con el controlador en [state].
Future<void> _pumpLogin(
  WidgetTester tester,
  AsyncValue<void> state, {
  String language = 'es',
}) async {
  await pumpApp(
    tester,
    stored: {'language': language},
    home: const LoginView(),
    overrides: [
      authControllerProvider.overrideWith((ref) => _StubAuthController(state)),
    ],
  );
  await tester.pump();
}

class _StubAuthController extends AuthController {
  _StubAuthController(AsyncValue<void> initial)
    : super(FakeAuthRepository(), FakeUserRepository()) {
    state = initial;
  }
}

void main() {
  group('AuthController (RF-22)', () {
    test(
      'una clienta bloqueada sale con AuthFailure.blocked y sin sesión',
      () async {
        final auth = FakeAuthRepository(
          credential: FakeUserCredential(FakeFirebaseUser('u1')),
        );
        final container = _authContainer(
          auth,
          FakeUserRepository(stored: _blockedClient),
        );

        await container
            .read(authControllerProvider.notifier)
            .signInWithGoogle();

        final state = container.read(authControllerProvider);
        expect(state.error, AuthFailure.blocked);
        expect(auth.signOutCalls, 1);
      },
    );

    test('un error técnico del servicio pasa a AuthFailure.unknown', () async {
      final container = _authContainer(
        FakeAuthRepository(
          credential: FakeUserCredential(FakeFirebaseUser('u1')),
        ),
        FakeUserRepository(error: Exception(_technical)),
      );

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(authControllerProvider).error, AuthFailure.unknown);
    });

    test('cancelar el inicio de sesión es AuthFailure.cancelled', () async {
      final container = _authContainer(
        FakeAuthRepository(),
        FakeUserRepository(),
      );

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(
        container.read(authControllerProvider).error,
        AuthFailure.cancelled,
      );
    });

    test('una usuaria nueva se guarda y no hay error', () async {
      final users = FakeUserRepository();
      final container = _authContainer(
        FakeAuthRepository(
          credential: FakeUserCredential(FakeFirebaseUser('u2')),
        ),
        users,
      );

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(users.saved.single.uid, 'u2');
    });
  });

  group('pantalla de inicio de sesión (RF-22)', () {
    testWidgets('clienta bloqueada: aviso en español, sin texto técnico', (
      tester,
    ) async {
      await _pumpLogin(
        tester,
        AsyncError(AuthFailure.blocked, StackTrace.empty),
      );

      expect(
        find.text(
          'Tu cuenta está bloqueada. Escríbenos por WhatsApp si crees que es '
          'un error.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('AuthFailure'), findsNothing);
      expect(find.textContaining('administrador'), findsNothing);
    });

    testWidgets('clienta bloqueada: aviso en portugués', (tester) async {
      await _pumpLogin(
        tester,
        AsyncError(AuthFailure.blocked, StackTrace.empty),
        language: 'pt',
      );

      expect(
        find.text(
          'Sua conta está bloqueada. Fale conosco pelo WhatsApp se achar que '
          'é um erro.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('error desconocido: texto genérico de la app', (tester) async {
      await _pumpLogin(
        tester,
        AsyncError(AuthFailure.unknown, StackTrace.empty),
      );

      expect(
        find.text('No pudimos iniciar sesión. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('un error que no es AuthFailure tampoco se muestra en crudo', (
      tester,
    ) async {
      await _pumpLogin(
        tester,
        AsyncError(Exception(_technical), StackTrace.empty),
      );

      expect(find.textContaining(_technical), findsNothing);
      expect(
        find.text('No pudimos iniciar sesión. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar no muestra ningún mensaje', (tester) async {
      await _pumpLogin(
        tester,
        AsyncError(AuthFailure.cancelled, StackTrace.empty),
      );

      expect(find.textContaining('Inténtalo de nuevo'), findsNothing);
      expect(find.textContaining('bloqueada'), findsNothing);
    });
  });

  group('errores de carga y de reserva (RF-22)', () {
    final technical = Exception(_technical);

    testWidgets('Perfil: mis reservas', (tester) async {
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const ProfileView(),
        overrides: [
          currentUserProvider.overrideWith((ref) async => testClient),
          clientAppointmentsProvider.overrideWith(
            (ref) => Stream.error(technical),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar tus reservas. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining(_technical), findsNothing);
    });

    testWidgets('Reservas: horarios', (tester) async {
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const BookingView(),
        overrides: [
          currentUserProvider.overrideWith((ref) async => testClient),
          availableSlotsProvider.overrideWithValue(
            AsyncError(technical, StackTrace.empty),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar los horarios. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining(_technical), findsNothing);
    });

    testWidgets('Reservas: crear la reserva', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      final slot = DateTime(2026, 10, 21, 10);
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const BookingView(),
        overrides: [
          currentUserProvider.overrideWith((ref) async => testClient),
          calendarSettingsProvider.overrideWith(
            (ref) => Stream.value(CalendarSettingsModel.defaultSettings()),
          ),
          availableSlotsProvider.overrideWithValue(AsyncData([slot])),
          bookingRepositoryProvider.overrideWithValue(
            FailingBookingRepository(),
          ),
        ],
      );
      // En la app, el router escucha siempre a la usuaria actual; aquí no
      // hay router, así que se escucha a mano para que esté cargada.
      appContainer(tester).listen(currentUserProvider, (_, _) {});
      await tester.pumpAndSettle();

      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR 10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos crear la reserva. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining(_technical), findsNothing);
    });

    testWidgets('Admin: agenda', (tester) async {
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const AdminDashboardView(),
        overrides: [
          adminAppointmentsProvider.overrideWith(
            (ref) => Stream.error(technical),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar la agenda. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining(_technical), findsNothing);
    });

    testWidgets('Admin: clientes', (tester) async {
      await pumpApp(
        tester,
        stored: {'language': 'pt'},
        home: const AdminUsersView(),
        overrides: [
          adminUsersProvider.overrideWith((ref) => Stream.error(technical)),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível carregar os clientes. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.textContaining(_technical), findsNothing);
    });
  });
}
