import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/home/presentation/home_view.dart';
import '../../features/auth/presentation/login_view.dart';
import '../../features/auth/presentation/phone_capture_view.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/presentation/booking_view.dart';
import '../../features/admin/presentation/admin_dashboard_view.dart';
import '../../features/admin/presentation/admin_users_view.dart';
import '../../features/admin/presentation/admin_settings_view.dart';
import '../../features/services/presentation/services_view.dart';
import '../../features/profile/presentation/profile_view.dart';
import '../../features/landing/landing_section.dart';
import '../../features/landing/presentation/landing_page.dart';
import '../../features/navigation/presentation/web_shell.dart';
import '../platform/platform_provider.dart';
import 'redirect_logic.dart';

// Placeholder views for other tabs
class PlaceholderView extends StatelessWidget {
  final String title;
  const PlaceholderView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final sectionNavigatorKeyHome = GlobalKey<NavigatorState>();
final sectionNavigatorKeyServices = GlobalKey<NavigatorState>();
final sectionNavigatorKeyBooking = GlobalKey<NavigatorState>();
final sectionNavigatorKeyProfile = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  final isWeb = ref.watch(isWebProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: isWeb ? '/' : '/home',
    refreshListenable: notifier,
    // Las reglas viven en la función pura `resolveRedirect` (spec 002, D-3).
    redirect: (context, state) {
      final currentUser = ref.read(currentUserProvider);
      final user = currentUser.value;
      final phone = user?.phoneNumber;

      return resolveRedirect(
        RedirectInput(
          isWeb: isWeb,
          path: state.uri.path,
          query: state.uri.queryParameters,
          isLoggedIn: ref.read(authStateProvider).value != null,
          isUserLoading: currentUser.isLoading,
          needsPhone: user != null && (phone == null || phone.isEmpty),
          isAdmin: user?.role == 'admin',
        ),
      );
    },
    routes: isWeb ? _webRoutes() : _mobileRoutes(),
  );
});

/// Web: todas las páginas dentro de [WebShell], con la barra superior
/// (spec 002, RF-13). La landing es la entrada.
List<RouteBase> _webRoutes() => [
  ShellRoute(
    builder: (context, state, child) => WebShell(child: child),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => LandingPage(
          key: landingPageKey,
          section: LandingSection.fromQuery(
            state.uri.queryParameters['section'],
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const WebAccountPage(child: LoginView()),
      ),
      GoRoute(
        path: '/capture_phone',
        builder: (context, state) =>
            const WebAccountPage(child: PhoneCaptureView()),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => const WebAccountPage(child: BookingView()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const WebAccountPage(child: ProfileView()),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            const WebAccountPage(child: AdminDashboardView()),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) =>
            const WebAccountPage(child: AdminUsersView()),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) =>
            const WebAccountPage(child: AdminSettingsView()),
      ),
      // Direcciones de las pestañas móviles: `resolveRedirect` las lleva a
      // la landing antes de que se muestren (RF-29).
      GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
      GoRoute(path: '/services', builder: (context, state) => const SizedBox()),
    ],
  ),
];

/// Android/iOS: la barra inferior con sus cuatro pestañas, sin cambios.
List<RouteBase> _mobileRoutes() => [
  GoRoute(
    path: '/admin',
    builder: (context, state) => const AdminDashboardView(),
  ),
  GoRoute(
    path: '/admin/users',
    builder: (context, state) => const AdminUsersView(),
  ),
  GoRoute(
    path: '/admin/settings',
    builder: (context, state) => const AdminSettingsView(),
  ),
  GoRoute(path: '/login', builder: (context, state) => const LoginView()),
  GoRoute(
    path: '/capture_phone',
    builder: (context, state) => const PhoneCaptureView(),
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return MainScaffold(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        navigatorKey: sectionNavigatorKeyHome,
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeView()),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: sectionNavigatorKeyServices,
        routes: [
          GoRoute(
            path: '/services',
            builder: (context, state) => const ServicesView(),
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: sectionNavigatorKeyBooking,
        routes: [
          GoRoute(
            path: '/booking',
            builder: (context, state) => const BookingView(),
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: sectionNavigatorKeyProfile,
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileView(),
          ),
        ],
      ),
    ],
  ),
];
