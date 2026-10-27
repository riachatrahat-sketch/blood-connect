import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/supa.dart';
import 'screens/home_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/my_requests_screen.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ProviderScope(child: BloodConnectApp()));
}

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kRed, brightness: brightness);
  final light = brightness == Brightness.light;
  final radius = BorderRadius.circular(12);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFFAF5F5) : null,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : scheme.surfaceContainer,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : null,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}

class BloodConnectApp extends StatelessWidget {
  const BloodConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BloodConnect',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Chooses the first screen from the current session:
///  - no session         => Landing (login / sign up / need blood)
///  - anonymous session  => account-less requester
///  - normal session     => donor Home
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const LandingScreen();
        if (session.user.isAnonymous) return const RequesterHome();
        return const HomeScreen();
      },
    );
  }
}
