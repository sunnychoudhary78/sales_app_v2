import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/firebase/firebase_options.dart';
import 'features/notifications/data/push_notification_support.dart';

import 'app/app_root.dart';
import 'app/app_routes.dart';
import 'core/providers/global_loading_provider.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/theme/app_theme_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'shared/widgets/global_error.dart';
import 'shared/widgets/global_loader.dart';
import 'shared/widgets/global_message.dart';
import 'shared/widgets/global_success.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase startup init failed: $e');
    }
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();

  runApp(Root(key: Root.rootKey, sharedPreferences: prefs));
}

class Root extends StatefulWidget {
  const Root({super.key, required this.sharedPreferences});

  static final GlobalKey<RootState> rootKey = GlobalKey<RootState>();

  final SharedPreferences sharedPreferences;

  /// Recreates [ProviderScope] so no user-scoped Riverpod state survives logout.
  static void restartApp() {
    rootKey.currentState?.restart();
  }

  @override
  RootState createState() => RootState();
}

class RootState extends State<Root> {
  Key key = UniqueKey();

  void restart() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: key,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(widget.sharedPreferences),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      home: const AppRoot(),
      routes: AppRoutes.routes,
      builder: (context, child) {
        final overlay = ref.watch(globalLoadingProvider);

        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (overlay.isLoading) GlobalLoader(message: overlay.message),
            if (overlay.isSuccess) GlobalSuccess(message: overlay.message),
            if (overlay.isError) GlobalError(message: overlay.message),
            if (overlay.isMessage) GlobalMessage(message: overlay.message),
          ],
        );
      },
    );
  }
}
