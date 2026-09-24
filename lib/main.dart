import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'providers/alert_settings_provider.dart';
import 'providers/product_provider.dart';
import 'providers/staff_provider.dart';
import 'services/notification_permission_service.dart';
import 'screens/lock_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'providers/app_config_provider.dart';
import 'widgets/dev_mode_banner.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'package:safe_device/safe_device.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'config/environment_store.dart';
import 'utils/api_config.dart';
import 'utils/app_routes.dart';
import 'utils/app_theme.dart';
import 'services/database_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Style des barres système pour un thème donné.
///
/// En thème sombre, les icônes doivent être claires (et inversement) : les
/// figer sur [Brightness.dark] rendait la barre de statut illisible dès que
/// l'appareil ou l'utilisateur basculait en sombre.
SystemUiOverlayStyle systemUiOverlayStyleFor(bool isDark) {
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarIconBrightness: iconBrightness,
    // iOS lit `statusBarBrightness` (luminosité du *fond*), qui est l'inverse
    // de la luminosité des icônes.
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

bool _firebaseReady = false;

Future<void> _initFirebaseSafe() async {
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint("Firebase.initializeApp() timed out after 2s, continuing...");
        return Firebase.app();
      },
    );
    _firebaseReady = true;
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
}

void main() async {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Pas de splash natif sur web (flutter_native_splash: web=false dans pubspec.yaml) :
  // appeler remove() sur web sans splash généré lève une PlatformException
  // "removeSplashFromWeb()" non capturable (Future non attendu dans le package).
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // Edge-to-edge (Android 15+, SDK 35+) : la transparence des barres système
  // est gérée nativement par enableEdgeToEdge() dans MainActivity. Les couleurs
  // SystemChrome (statusBarColor, systemNavigationBarColor) sont dépréciées et
  // ignorées sur Android 15+ : on ne garde que la luminosité des icônes.
  //
  // Valeur initiale seulement (avant le premier frame) : elle est calée sur la
  // luminosité de l'appareil, car le mode d'affichage par défaut est
  // ThemeMode.system. Dès le premier frame, l'AnnotatedRegion posée par
  // [FimusApp] prend le relais avec le thème réellement appliqué.
  SystemChrome.setSystemUIOverlayStyle(
    systemUiOverlayStyleFor(
      widgetsBinding.platformDispatcher.platformBrightness == Brightness.dark,
    ),
  );

  // Filet de sécurité : s'assurer que le splashscreen natif est retiré après 3.5s max
  Future.delayed(const Duration(milliseconds: 3500), () {
    if (!kIsWeb) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    }
  });

  bool jailbroken = false;
  var environment = AppEnvironment.production;
  try {
    final results = await Future.wait<dynamic>([
      SafeDevice.isJailBroken
          .timeout(const Duration(milliseconds: 800), onTimeout: () => false)
          .catchError((e) {
        debugPrint("Jailbreak detection failed: $e");
        return false;
      }),
      _initFirebaseSafe(),
      SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      ).catchError((e) {
        debugPrint("SharedPreferences timeout/error in main: $e");
        return SharedPreferences.getInstance();
      }),
    ]);
    jailbroken = (results[0] as bool?) ?? false;

    environment = EnvironmentStore.load(results[2] as SharedPreferences?);
  } catch (e) {
    debugPrint("Initialization error: $e");
  }
  // Défense en profondeur : hors debug, l'environnement est TOUJOURS la
  // production (API HTTPS, base partagée `monitrack.db`), quel que soit le
  // contenu des préférences — un build release installé par-dessus un build
  // debug ne doit jamais repartir sur un serveur local. EnvironmentStore
  // l'impose déjà, on le reverrouille ici avant tout usage.
  if (kReleaseMode) {
    environment = AppEnvironment.production;
  }
  // Environnement (Dev/Prod) résolu une seule fois, avant tout accès API ou DB
  ApiConfig.configure(environment);
  DatabaseService.setDefaultDbName(environment);

  // Le handler background FCM doit être enregistré avant runApp(), une seule
  // fois, et seulement si Firebase est prêt (sinon l'appel lève).
  if (_firebaseReady && !kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint("Failed to register FCM background handler: $e");
    }
  }

  if (jailbroken) {
    if (!kIsWeb) FlutterNativeSplash.remove();
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
    ChangeNotifierProvider(
      create: (_) => AppConfigProvider(environment),
      child: EnvironmentScope(
        builder: (_) => MultiProvider(
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
        // Alertes locales (budget, solde bas, données non synchronisées) :
        // réglages stockés en SharedPreferences, chargés à l'ouverture de
        // l'écran « Notifications ».
        ChangeNotifierProvider(create: (_) => AlertSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
      ],
      child: const FimusApp(),
        ),
      ),
    ),
  );

  // Defer non-critical services initialization post-launch
  Future.microtask(() async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("NotificationService deferred init failed: $e");
    }
  });
}

/// Redémarre l'arbre applicatif quand l'environnement change (ou sur demande
/// via [AppConfigProvider.scopeKey]) : tous les providers sont recréés et
/// repartent de la nouvelle API et de la nouvelle base.
///
/// Un frame vide est intercalé pour démonter entièrement l'ancien arbre :
/// sans lui, les GlobalKey statiques (navigatorKey, écrans) seraient
/// re-parentées dans le nouvel arbre en conservant leur ancien état.
class EnvironmentScope extends StatefulWidget {
  const EnvironmentScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<EnvironmentScope> createState() => _EnvironmentScopeState();
}

class _EnvironmentScopeState extends State<EnvironmentScope> {
  String? _mountedKey;
  bool _tearingDown = false;

  @override
  Widget build(BuildContext context) {
    final scopeKey = context.select<AppConfigProvider, String>((c) => c.scopeKey);
    _mountedKey ??= scopeKey;

    if (scopeKey != _mountedKey && !_tearingDown) {
      _tearingDown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _tearingDown = false;
          _mountedKey = context.read<AppConfigProvider>().scopeKey;
        });
      });
    }

    if (_tearingDown) return const SizedBox.shrink();
    return widget.builder(context);
  }
}

class FimusApp extends StatelessWidget {
  const FimusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final seed = themeProvider.primaryColor;

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
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: themeProvider.themeMode,
      navigatorKey: navigatorKey,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        // Hors debug, EnvironmentStore impose la production : la bannière
        // DEV ne peut donc apparaître qu'en debug
        final showDevBanner = context.watch<AppConfigProvider>().isDevMode;
        // Ce `context` est situé sous le Theme du MaterialApp : sa luminosité
        // est donc celle du thème réellement appliqué (themeMode résolu, y
        // compris ThemeMode.system).
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemUiOverlayStyleFor(isDark),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                // En edge-to-edge, la banner DEV doit passer sous la barre de
                // statut ; le navigateur perd alors son padding top (déjà
                // consommé par la banner) pour éviter un double décalage.
                if (showDevBanner)
                  const SafeArea(
                    bottom: false,
                    child: DevModeBanner(),
                  ),
                Expanded(
                  child: showDevBanner
                      ? MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: child ?? const SizedBox.shrink(),
                        )
                      : child ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
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
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        });
      }
      
      if (mounted) {
        await context
            .read<AuthProvider>()
            .checkAuthStatus(context)
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint("Error in _checkOnboardingAndAuth: $e");
      if (mounted) {
        setState(() {
          _hasSeenOnboarding ??= false;
        });
      }
    } finally {
      if (!kIsWeb) {
        try {
          FlutterNativeSplash.remove();
        } catch (_) {}
      }
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
        return MainScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
