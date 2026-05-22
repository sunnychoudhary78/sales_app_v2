// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sales_tracking_v2/main.dart';
import 'package:sales_tracking_v2/core/providers/shared_preferences_provider.dart';
import 'package:sales_tracking_v2/features/auth/presentation/screens/login_screen.dart';
import 'package:sales_tracking_v2/features/auth/presentation/providers/auth_provider.dart';
import 'package:sales_tracking_v2/features/auth/presentation/providers/auth_state.dart';

void main() {
  testWidgets('App shows login when logged out', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: const MyApp(),
      ),
    );

    // LoginScreen runs an infinite background animation; pumpAndSettle never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isInitializing: false,
        isAuthenticating: false,
        profile: null,
        rawUser: null,
      );

  @override
  Future<void> tryAutoLogin() async {
    // Prevent real storage reads during widget tests
  }
}
