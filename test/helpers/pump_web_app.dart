import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/router/app_router.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/auth_repository.dart';
import 'package:shaddai/data/repositories/preferences_repository.dart';
import 'package:shaddai/data/repositories/user_repository.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:shaddai/features/profile/providers/profile_provider.dart';
import 'package:shaddai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';
import 'fake_session.dart';
import 'pump_app.dart';

/// Clienta con sesión y sin WhatsApp.
final testClientWithoutPhone = UserModel(
  uid: 'u2',
  email: 'bia@example.com',
  displayName: 'Bia Souza',
);

/// Admin con sesión y WhatsApp.
final testAdmin = testClient.copyWith(role: 'admin');

/// Carga en el test las fuentes reales de la app (Inter y Cormorant). Sin
/// ellas, Flutter usa una fuente de prueba en la que cada letra mide lo mismo
/// que su tamaño, y los textos ocupan casi el doble que en la app.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  for (final (family, asset) in [
    ('Inter', 'assets/fonts/Inter-Variable.ttf'),
    ('Cormorant Garamond', 'assets/fonts/CormorantGaramond-Variable.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
  _fontsLoaded = true;
}

var _fontsLoaded = false;

/// Sesión falsa que puede cambiar durante el test: [signIn] simula que la
/// persona termina el inicio de sesión con Google y [signOut], que la cierra.
class FakeWebSession {
  FakeWebSession([this.user]);

  UserModel? user;
  final _changes = StreamController<User?>.broadcast();

  void signIn(UserModel user) {
    this.user = user;
    _changes.add(FakeFirebaseUser(user.uid));
  }

  void signOut() {
    user = null;
    _changes.add(null);
  }

  /// Estado de Firebase Auth: el actual y, después, cada cambio.
  Stream<User?> authState() async* {
    final current = user;
    yield current == null ? null : FakeFirebaseUser(current.uid);
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}

/// Repositorio de autenticación falso cuyo `signOut` cierra [session].
class _SessionAuthRepository extends FakeAuthRepository {
  _SessionAuthRepository(this.session);

  final FakeWebSession session;

  @override
  Future<void> signOut() async {
    await super.signOut();
    session.signOut();
  }
}

/// Repositorio de usuarias falso que guarda el WhatsApp en [session], como
/// hace Firestore con la ficha (captura de WhatsApp).
class _SessionUserRepository extends FakeUserRepository {
  _SessionUserRepository(this.session);

  final FakeWebSession session;

  @override
  Future<void> updatePhoneNumber(String uid, String phoneNumber) async {
    session.user = session.user?.copyWith(phoneNumber: phoneNumber);
  }
}

/// Monta la app real en Web: el router de verdad (rutas y redirecciones de
/// Web), sin Firebase. La sesión es [session] o, si no se pasa, una con
/// [user] (sin sesión si es `null`). La ventana mide [width] × [height] px, y
/// la app abre en [location]. [authRepository] y [userRepository] sustituyen
/// a los de la sesión falsa (p. ej., para una clienta bloqueada). Devuelve la
/// sesión, para cambiarla en el test.
///
/// Con [reduceMotion] (por defecto), el sistema pide reducir las animaciones:
/// la franja animada de la landing se para y `pumpAndSettle` puede terminar.
Future<FakeWebSession> pumpWebApp(
  WidgetTester tester, {
  String location = '/',
  UserModel? user,
  FakeWebSession? session,
  AuthRepository? authRepository,
  UserRepository? userRepository,
  Map<String, Object> stored = const {'language': 'es'},
  double width = 1280,
  double height = 900,
  bool reduceMotion = true,
  List<Override> overrides = const [],
}) async {
  await loadAppFonts();
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);

  final webSession = session ?? FakeWebSession(user);
  addTearDown(webSession.dispose);

  SharedPreferences.setMockInitialValues(stored);
  final store = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(store),
        ),
        isWebProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? _SessionAuthRepository(webSession),
        ),
        userRepositoryProvider.overrideWithValue(
          userRepository ?? _SessionUserRepository(webSession),
        ),
        authStateProvider.overrideWith((ref) => webSession.authState()),
        currentUserProvider.overrideWith((ref) async {
          ref.watch(authStateProvider);
          return webSession.user;
        }),
        clientAppointmentsProvider.overrideWith(
          (ref) => Stream.value(const <AppointmentModel>[]),
        ),
        ...overrides,
      ],
      child: const MyApp(),
    ),
  );
  await settleWeb(tester);

  if (location != '/') {
    webRouter(tester).go(location);
    await settleWeb(tester);
  }
  return webSession;
}

/// Deja terminar la carga de la sesión y las transiciones de página. No usa
/// `pumpAndSettle`, que no acaba con animaciones continuas.
Future<void> settleWeb(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Router de la app montada con [pumpWebApp].
GoRouter webRouter(WidgetTester tester) =>
    appContainer(tester).read(goRouterProvider);

/// Ruta actual (con su query) de la app montada con [pumpWebApp].
Uri webLocation(WidgetTester tester) =>
    webRouter(tester).routerDelegate.currentConfiguration.uri;
