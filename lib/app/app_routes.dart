import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/claims/presentation/screens/claim_requests_screen.dart';
import '../features/claims/presentation/screens/my_claim_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/products/presentation/screens/products_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/tracking/presentation/screens/tracking_screen.dart';
import '../features/visits/presentation/screens/add_visit_screen.dart';
import '../features/visits/presentation/screens/visits_list_screen.dart';

class AppRoutes {
  static const loginOtp = '/login-otp';
  static const forgotPassword = '/forgot-password';

  static Map<String, WidgetBuilder> routes = {
    '/login': (_) => const LoginScreen(),
    loginOtp: (_) => const LoginScreen(initialPage: LoginAuthPage.otp),
    forgotPassword: (_) => const LoginScreen(initialPage: LoginAuthPage.forgot),
    '/home': (_) => const HomeScreen(),
    '/tracking': (_) => const TrackingScreen(),
    '/products': (_) => const ProductsScreen(),
    '/claims/my': (_) => const MyClaimScreen(),
    '/claims/requests': (_) => const ClaimRequestsScreen(),
    '/notifications': (_) => const NotificationsScreen(),
    '/profile': (_) => const ProfileScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/visits': (_) => const VisitsListScreen(),
    '/visits/add': (_) => const AddVisitScreen(),
  };
}

