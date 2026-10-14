import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screens.dart';
import '../../features/bookings/presentation/new_booking_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/customer_booking/presentation/booking_flow_screen.dart';
import '../../features/customer_booking/presentation/my_appointments_screens.dart';
import '../../features/customer_booking/presentation/profile_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/platform/platform_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/salon/presentation/discover_screen.dart';
import '../../features/salon/presentation/salon_page_screen.dart';
import '../../features/salon/presentation/salon_reviews_screen.dart';
import '../../features/seasonal/presentation/seasonal_admin_screen.dart';
import '../../features/seasonal/presentation/token_flow_screen.dart';
import '../../features/seasonal/presentation/token_screen.dart';
import '../../features/services/presentation/services_screens.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/staff/presentation/staff_screens.dart';
import '../../shared/animations/page_transitions.dart';
import '../../shared/models/models.dart';
import '../auth/auth_controller.dart';
import 'shells.dart';
import 'splash_screen.dart';

/// Where each role lands after signing in.
String homeFor(Session s) => switch (s.me.homeRole) {
      HomeRole.superAdmin => s.me.memberships.isNotEmpty ? '/admin' : '/platform',
      HomeRole.salonAdmin => '/admin',
      HomeRole.staff => '/staff',
      HomeRole.customer => '/discover',
    };

const _authPaths = ['/login', '/register', '/register-salon', '/forgot-password', '/phone-login'];
bool _isPublic(String p) =>
    p.startsWith('/salon/') || p.startsWith('/booking/') || p.startsWith('/token/') || p.startsWith('/reset-password') || p == '/discover';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth changes, without rebuilding the router.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      if (auth.isLoading) {
        if (path == '/splash' || _isPublic(path)) return null;
        // Keep the deep link (e.g. /admin/calendar) across the session restore.
        return path == '/' ? '/splash' : '/splash?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      final session = auth.valueOrNull;
      final from = state.uri.queryParameters['from'];

      if (session == null) {
        if (_isPublic(path) || _authPaths.contains(path)) return null;
        final back = path == '/splash' ? from : (path == '/' ? null : state.uri.toString());
        return back == null ? '/login' : '/login?from=${Uri.encodeComponent(back)}';
      }

      if (_authPaths.contains(path) || path == '/' || path == '/splash') {
        return from != null && from.startsWith('/') ? from : homeFor(session);
      }

      final m = session.membership;
      if (path.startsWith('/admin') && (m == null || m.role == 'STAFF')) return homeFor(session);
      if (path.startsWith('/staff') && m?.role != 'STAFF') return homeFor(session);
      if (path.startsWith('/platform') && !session.me.user.isSuperAdmin) return homeFor(session);
      return null;
    },
    errorBuilder: (context, state) => const SplashScreen(),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),

      // Auth
      GoRoute(path: '/login', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, LoginScreen(redirect: s.uri.queryParameters['from']))),
      GoRoute(path: '/register', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, const RegisterScreen())),
      GoRoute(path: '/register-salon', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, const RegisterSalonScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, const ForgotPasswordScreen())),
      GoRoute(path: '/phone-login', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, const PhoneLoginScreen())),
      GoRoute(path: '/reset-password', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, ResetPasswordScreen(token: s.uri.queryParameters['token'] ?? ''))),

      // Public booking page & guest manage link — no account needed.
      GoRoute(
        path: '/salon/:slug',
        pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, SalonPageScreen(slug: s.pathParameters['slug']!)),
        routes: [
          GoRoute(
            path: 'book',
            pageBuilder: (_, s) => AnimatedPageTransition.rise(s, BookingFlowScreen(slug: s.pathParameters['slug']!, serviceId: s.uri.queryParameters['service'])),
          ),
          GoRoute(
            path: 'tokens/:eventId',
            pageBuilder: (_, s) => AnimatedPageTransition.rise(s, TokenFlowScreen(slug: s.pathParameters['slug']!, eventId: s.pathParameters['eventId']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/token/:id',
        pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, TokenScreen(id: s.pathParameters['id']!, access: s.uri.queryParameters['token'])),
      ),
      GoRoute(
        path: '/booking/:id',
        pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, AppointmentDetailScreen(id: s.pathParameters['id']!, token: s.uri.queryParameters['token'])),
      ),

      // Customer
      ShellRoute(
        builder: (_, s, child) => CustomerShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(path: '/discover', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const DiscoverScreen())),
          GoRoute(path: '/appointments', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const MyAppointmentsScreen())),
          GoRoute(path: '/appointments/:id', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, AppointmentDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/inbox', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const NotificationsScreen())),
          GoRoute(path: '/profile', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const ProfileScreen())),
        ],
      ),

      // Salon admin / reception
      GoRoute(
        path: '/admin/bookings/new',
        pageBuilder: (_, s) {
          final q = s.uri.queryParameters;
          return AnimatedPageTransition.rise(
            s,
            NewBookingScreen(date: q['date'], staffId: q['staff'], minute: int.tryParse(q['minute'] ?? ''), customerId: q['customer']),
          );
        },
      ),
      GoRoute(path: '/admin/services/new', pageBuilder: (_, s) => AnimatedPageTransition.rise(s, const ServiceFormScreen())),
      GoRoute(path: '/admin/team/new', pageBuilder: (_, s) => AnimatedPageTransition.rise(s, const StaffFormScreen())),
      ShellRoute(
        builder: (_, s, child) => AdminShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const DashboardScreen())),
          GoRoute(path: '/admin/calendar', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const CalendarScreen())),
          GoRoute(
            path: '/admin/clients',
            pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, CustomersScreen(openNew: s.uri.queryParameters['new'] == '1')),
          ),
          GoRoute(path: '/admin/clients/:id', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, CustomerProfileScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/admin/services', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const ServicesScreen())),
          GoRoute(path: '/admin/services/:id', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, ServiceFormScreen(id: s.pathParameters['id']))),
          GoRoute(path: '/admin/team', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const StaffScreen())),
          GoRoute(path: '/admin/team/:id', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, StaffFormScreen(id: s.pathParameters['id']))),
          GoRoute(path: '/admin/payments', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const PaymentsScreen())),
          GoRoute(path: '/admin/seasonal', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const SeasonalAdminScreen())),
          GoRoute(path: '/admin/reports', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const ReportsScreen())),
          GoRoute(path: '/admin/reviews', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const SalonReviewsScreen())),
          GoRoute(path: '/admin/inbox', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const NotificationsScreen())),
          GoRoute(path: '/admin/settings', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const SettingsScreen())),
        ],
      ),

      // Artists
      ShellRoute(
        builder: (_, s, child) => StaffShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(path: '/staff', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const DashboardScreen(staffMode: true))),
          GoRoute(path: '/staff/calendar', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const CalendarScreen())),
          GoRoute(path: '/staff/clients', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const CustomersScreen())),
          GoRoute(path: '/staff/clients/:id', pageBuilder: (_, s) => AnimatedPageTransition.sharedAxis(s, CustomerProfileScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/staff/inbox', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const NotificationsScreen())),
          GoRoute(path: '/staff/profile', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const ProfileScreen(showFavorites: false))),
        ],
      ),

      // Super admin
      GoRoute(path: '/platform', pageBuilder: (_, s) => AnimatedPageTransition.fadeThrough(s, const PlatformScreen())),
    ],
  );
});
