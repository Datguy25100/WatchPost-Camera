import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/speaker.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        prefs,
        api: kApiUrl.isEmpty ? null : ApiService(kApiUrl),
        speaker: Speaker(),
      ),
      child: const WatchPostApp(),
    ),
  );
}

class WatchPostApp extends StatelessWidget {
  const WatchPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WatchPost',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppRoot(),
    );
  }
}

/// Decides which top-level flow to show: splash -> onboarding -> login -> home.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final Widget child;
    if (!_splashDone) {
      child = SplashScreen(
        key: const ValueKey('splash'),
        onDone: () => setState(() => _splashDone = true),
      );
    } else if (!state.onboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (!state.isSignedIn) {
      child = const LoginScreen(key: ValueKey('login'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}
