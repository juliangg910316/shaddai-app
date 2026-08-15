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

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isPhoneCapture = state.matchedLocation == '/capture_phone';

      // If user is trying to access booking but isn't logged in
      if (!isLoggedIn && state.matchedLocation.startsWith('/booking')) {
        return '/login';
      }

      if (isLoggedIn) {
        // If logged in but data is loading, don't redirect yet
        if (currentUser.isLoading) return null;
        
        final user = currentUser.value;
        // If user logged in but has no phone number, force them to phone capture
        if (user != null && (user.phoneNumber == null || user.phoneNumber!.isEmpty)) {
          if (!isPhoneCapture) return '/capture_phone';
          return null; // Let them stay on capture phone
        }

        // If they are on login or capture phone and everything is fine, go home
        if (isLoggingIn || isPhoneCapture) {
          return '/home';
        }
      }

      return null; // No redirect
    },
    routes: [
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
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
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
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeView(),
              ),
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
    ],
  );
});
