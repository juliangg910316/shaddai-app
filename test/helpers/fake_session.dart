import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
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

/// Overrides de sesión sin Firebase: sin sesión si [user] es `null`.
List<Override> sessionOverrides({UserModel? user}) => [
  currentUserProvider.overrideWith((ref) async => user),
  clientAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
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
