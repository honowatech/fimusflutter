import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
import 'providers/notification_provider.dart';
import 'providers/notification_preferences_provider.dart';
import 'services/notification_permission_service.dart';
import 'screens/lock_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/complete_profile_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/notification_service.dart';
import 'package:safe_device/safe_device.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initFirebaseSafe() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
}

void main() async {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  bool jailbroken = false;
  try {
    final results = await Future.wait<dynamic>([
      SafeDevice.isJailBroken
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false)
          .catchError((e) {
        debugPrint("Jailbreak detection failed: $e");
        return false;
      }),
      _initFirebaseSafe(),
    ]);
    jailbroken = results[0] as bool;
  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  if (jailbroken) {
    FlutterNativeSplash.remove();
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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationPermissionService()),
      ],
      child: const FimusApp(),
    ),
  );

  // Defer non-critical services initialization post-launch
  Future.microtask(() async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("NotificationService deferred init failed: $e");
    }
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {}
  });
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
      navigatorKey: navigatorKey,
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
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        });
      }
      
      if (mounted) {
        await context.read<AuthProvider>().checkAuthStatus(context);
      }
    } catch (e) {
      debugPrint("Error in _checkOnboardingAndAuth: $e");
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = false;
        });
      }
    } finally {
      FlutterNativeSplash.remove();
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
      
      // Refresh notifications when returning to foreground
      if (mounted) {
        context.read<NotificationProvider>().fetch();
      }
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
      return const WelcomeScreen();
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
        if (!context.watch<AuthProvider>().isProfileComplete) {
          return const CompleteProfileScreen();
        }
        if (securityProvider.isAppLockEnabled && !securityProvider.isAppUnlocked) {
          return const LockScreen();
        }
        return const MainScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
