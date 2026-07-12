import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'providers/ussd_provider.dart';
import 'providers/history_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/account_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/security_provider.dart';
import 'providers/contact_provider.dart';
import 'screens/lock_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool jailbroken = false;
  try {
    jailbroken = await FlutterJailbreakDetection.jailbroken;
  } on PlatformException {
    jailbroken = true;
  }

  if (jailbroken) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "Pour des raisons de sécurité, cette application financière ne peut pas s'exécuter sur un appareil compromis (Rooté / Jailbreaké).",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => UssdProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const FimusApp(),
    ),
  );
}

class FimusApp extends StatelessWidget {
  const FimusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme =
        ColorScheme.fromSeed(seedColor: themeProvider.primaryColor);

    return MaterialApp(
      title: 'FIMUS',
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.error, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: colorScheme.error, width: 2.0),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Decides which screen to show based on authentication status.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  DateTime? _backgroundTimestamp;
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check persisted auth token on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingAndAuth();
    });
  }

  Future<void> _checkOnboardingAndAuth() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    });
    
    if (mounted) {
      context.read<AuthProvider>().checkAuthStatus(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (!mounted) return;
    
    final securityProvider = context.read<SecurityProvider>();
    if (!securityProvider.isAppLockEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTimestamp != null) {
        final elapsed = DateTime.now().difference(_backgroundTimestamp!);
        if (elapsed.inSeconds >= 15) { // lock after 15s in background
          securityProvider.lockApp();
        }
      } else {
        securityProvider.lockApp();
      }
      _backgroundTimestamp = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasSeenOnboarding!) {
      return const OnboardingScreen();
    }

    final authStatus = context.watch<AuthProvider>().status;
    final securityProvider = context.watch<SecurityProvider>();

    switch (authStatus) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        if (securityProvider.isAppLockEnabled && !securityProvider.isAppUnlocked) {
          return const LockScreen();
        }
        return const MainScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
