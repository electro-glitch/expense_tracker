import 'package:expense_tracker/screens/auth/login_screen.dart';
import 'package:expense_tracker/screens/auth/signup_screen.dart';
import 'package:expense_tracker/screens/home/add_expense_screen.dart';
import 'package:expense_tracker/screens/main_navigation_screen.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshListenable(authService),
    redirect: (context, state) {
      final user = authService.currentUser;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (user == null && !loggingIn) return '/login';
      if (user != null && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
    ],
  );
});

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(AuthService authService) {
    authService.authStateChanges.listen((user) {
      notifyListeners();
    });
  }
}
